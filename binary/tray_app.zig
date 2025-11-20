const std = @import("std");
const model = @import("tray_model.zig");
const objc_rt = @import("objc_runtime.zig");
const runtime_mod = @import("tray_runtime.zig");
const rpc = @import("rpc.zig");

fn dupZ(allocator: std.mem.Allocator, slice: []const u8) ![:0]u8 {
    var buf = try allocator.alloc(u8, slice.len + 1);
    std.mem.copyForwards(u8, buf[0..slice.len], slice);
    buf[slice.len] = 0;
    return buf[0..slice.len :0];
}

const IconJson = struct {
    type: []const u8,
    title: ?[]const u8 = null,
    name: ?[]const u8 = null,
    accessibility_description: ?[]const u8 = null,
    base64_data: ?[]const u8 = null,
};

const MenuItemJson = struct {
    type: []const u8,
    title: ?[]const u8 = null,
    is_separator: bool = false,
    key_equivalent: ?[]const u8 = null,
    kind: ?[]const u8 = null,
};

const ConfigJson = struct {
    icon: IconJson,
    items: []const MenuItemJson,
};

fn toIcon(allocator: std.mem.Allocator, icon_json: IconJson) !model.TrayIcon {
    const icon_type = icon_json.type;
    if (std.mem.eql(u8, icon_type, "text")) {
        const title = icon_json.title orelse "TrayKit";
        return .{ .text = .{ .title = try dupZ(allocator, title) } };
    } else if (std.mem.eql(u8, icon_type, "sf_symbol")) {
        const name = icon_json.name orelse "checkmark.circle";
        const acc = icon_json.accessibility_description orelse "TrayKit status icon";
        return .{ .sf_symbol = .{ .name = try dupZ(allocator, name), .accessibility_description = try dupZ(allocator, acc) } };
    } else if (std.mem.eql(u8, icon_type, "base64_image")) {
        const data = icon_json.base64_data orelse "";
        return .{ .base64_image = .{ .base64_data = try dupZ(allocator, data) } };
    }
    return error.InvalidIcon;
}

fn toMenuItem(allocator: std.mem.Allocator, item_json: MenuItemJson) !model.MenuItem {
    if (std.mem.eql(u8, item_json.type, "text")) {
        const title = item_json.title orelse "";
        return .{ .text = .{ .title = try dupZ(allocator, title), .is_separator = item_json.is_separator } };
    } else if (std.mem.eql(u8, item_json.type, "action")) {
        const title = item_json.title orelse "Action";
        const key_eq = item_json.key_equivalent orelse "";
        const kind_str = item_json.kind orelse "quit";
        _ = kind_str; // only quit supported today
        return .{ .action = .{ .title = try dupZ(allocator, title), .key_equivalent = try dupZ(allocator, key_eq), .kind = .quit } };
    }
    return error.InvalidItem;
}

fn defaultConfig(allocator: std.mem.Allocator) !model.TrayConfig {
    var items = try allocator.alloc(model.MenuItem, 3);
    items[0] = .{ .text = .{ .title = try dupZ(allocator, "TrayKit"), .is_separator = false } };
    items[1] = .{ .text = .{ .title = try dupZ(allocator, ""), .is_separator = true } };
    items[2] = .{ .action = .{ .title = try dupZ(allocator, "Quit"), .key_equivalent = try dupZ(allocator, "q"), .kind = .quit } };

    return .{
        .icon = .{ .sf_symbol = .{ .name = try dupZ(allocator, "checkmark.circle"), .accessibility_description = try dupZ(allocator, "TrayKit status icon") } },
        .items = items,
    };
}

fn parseConfigFromArgs(allocator: std.mem.Allocator) !model.TrayConfig {
    var args = std.process.argsWithAllocator(allocator) catch return defaultConfig(allocator);
    defer args.deinit();

    var config_json_str: ?[]const u8 = null;
    _ = args.next(); // skip binary name
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--config-json")) {
            if (args.next()) |val| {
                config_json_str = try allocator.dupe(u8, val);
            }
        }
    }

    if (config_json_str) |cfg_str| {
        var parsed = std.json.parseFromSlice(ConfigJson, allocator, cfg_str, .{ .ignore_unknown_fields = true }) catch {
            return defaultConfig(allocator);
        };
        defer parsed.deinit();

        const len = parsed.value.items.len;
        var items = try allocator.alloc(model.MenuItem, len);
        var count: usize = 0;
        for (parsed.value.items) |item_json| {
            const menu_item = toMenuItem(allocator, item_json) catch continue;
            items[count] = menu_item;
            count += 1;
        }

        return .{
            .icon = try toIcon(allocator, parsed.value.icon),
            .items = items[0..count],
        };
    }

    return defaultConfig(allocator);
}

pub const TrayApp = struct {
    config: model.TrayConfig,

    pub fn run(self: *const TrayApp) !void {
        std.debug.print("TrayKit starting\n", .{});

        const poolClass = objc_rt.getClass("NSAutoreleasePool");
        const poolAlloc = objc_rt.msgSend_id0(poolClass, objc_rt.getSel("alloc"));
        const pool = objc_rt.msgSend_id0(poolAlloc, objc_rt.getSel("init"));

        const appClass = objc_rt.getClass("NSApplication");
        const app = objc_rt.msgSend_id0(appClass, objc_rt.getSel("sharedApplication"));

        const statusBarClass = objc_rt.getClass("NSStatusBar");
        const statusBar = objc_rt.msgSend_id0(statusBarClass, objc_rt.getSel("systemStatusBar"));
        const statusItem = objc_rt.msgSend_id_f64(
            statusBar,
            objc_rt.getSel("statusItemWithLength:"),
            objc_rt.NSVariableStatusItemLength,
        );

        const nsStringClass = objc_rt.getClass("NSString");
        const button = objc_rt.msgSend_id0(statusItem, objc_rt.getSel("button"));

        var runtime = runtime_mod.TrayRuntime.init(app, statusItem, button, nsStringClass);
        runtime.setIcon(self.config.icon);
        runtime.initMenu("TrayKit");
        for (self.config.items) |item_cfg| runtime.addMenuItem(item_cfg, null);

        const rpc_thread = try std.Thread.spawn(.{}, rpc.rpcLoop, .{&runtime});
        rpc_thread.detach();

        objc_rt.msgSend_void0(app, objc_rt.getSel("run"));
        objc_rt.msgSend_void0(pool, objc_rt.getSel("drain"));
    }
};

pub fn runTray() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cfg = try parseConfigFromArgs(allocator);
    const app = TrayApp{ .config = cfg };
    try app.run();
}
