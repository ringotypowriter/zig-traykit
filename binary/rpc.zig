const std = @import("std");
const model = @import("tray_model.zig");
const runtime_mod = @import("tray_runtime.zig");

pub fn rpcLoop(runtime: *runtime_mod.TrayRuntime) !void {
    const allocator = std.heap.c_allocator;
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();
    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = stdin_file.reader(&stdin_buffer);
    const stdin_io = &stdin_reader.interface;
    var stdout_writer = stdout_file.writer(&[_]u8{});
    const stdout_io = &stdout_writer.interface;

    while (true) {
        const line = stdin_io.takeDelimiterExclusive('\n') catch |err| switch (err) {
            error.EndOfStream => break,
            error.StreamTooLong => return error.RpcLineTooLong,
            else => return err,
        };
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, line, .{}) catch {
            sendError(stdout_io, "parse_error", null);
            continue;
        };
        defer parsed.deinit();

        const root = parsed.value;
        const method_val = root.object.get("method") orelse {
            sendError(stdout_io, "missing_method", null);
            continue;
        };

        const id_val = root.object.get("id") orelse std.json.Value{ .null = {} };
        const method_slice = switch (method_val) {
            .string => |s| s,
            else => {
                sendErrorWithId(stdout_io, "invalid_method", id_val) catch {};
                continue;
            },
        };

        const method_tag = toMethod(method_slice);
        const params = root.object.get("params");

        switch (method_tag) {
            .removeItem => {
                if (params) |p| {
                    const idx_val = p.object.get("index") orelse {
                        sendErrorWithId(stdout_io, "missing_index", id_val) catch {};
                        continue;
                    };
                    const idx_int = switch (idx_val) {
                        .integer => |i| i,
                        else => {
                            sendErrorWithId(stdout_io, "invalid_index", id_val) catch {};
                            continue;
                        },
                    };
                    const ok = runtime.removeMenuItem(@as(usize, @intCast(idx_int)));
                    sendBoolResult(stdout_io, ok, id_val) catch {};
                } else sendErrorWithId(stdout_io, "missing_params", id_val) catch {};
            },
            .addTextItem => {
                if (params) |p| {
                    const title_val: std.json.Value = p.object.get("title") orelse std.json.Value{ .string = "" };
                    const is_sep_val = p.object.get("is_separator");
                    const idx_opt = p.object.get("index");
                    const title = switch (title_val) {
                        .string => |s| s,
                        else => "",
                    };
                    const is_sep = if (is_sep_val) |v| switch (v) {
                        .bool => |b| b,
                        else => false,
                    } else false;
                    const menu_item = model.MenuItem{ .text = .{ .title = try dupZ(allocator, title), .is_separator = is_sep } };
                    const idx_converted: ?usize = if (idx_opt) |v| blk: {
                        const vi = switch (v) {
                            .integer => |i| i,
                            else => break :blk null,
                        };
                        break :blk @as(usize, @intCast(vi));
                    } else null;
                    runtime.addMenuItem(menu_item, idx_converted);
                    sendBoolResult(stdout_io, true, id_val) catch {};
                } else sendErrorWithId(stdout_io, "missing_params", id_val) catch {};
            },
            .addActionItem => {
                if (params) |p| {
                    const title_val: std.json.Value = p.object.get("title") orelse std.json.Value{ .string = "Action" };
                    const key_val: std.json.Value = p.object.get("key_equivalent") orelse std.json.Value{ .string = "" };
                    const idx_opt = p.object.get("index");
                    const title = switch (title_val) {
                        .string => |s| s,
                        else => "Action",
                    };
                    const key_eq = switch (key_val) {
                        .string => |s| s,
                        else => "",
                    };
                    const menu_item = model.MenuItem{ .action = .{ .title = try dupZ(allocator, title), .key_equivalent = try dupZ(allocator, key_eq), .kind = .quit } };
                    const idx_converted: ?usize = if (idx_opt) |v| blk: {
                        const vi = switch (v) {
                            .integer => |i| i,
                            else => break :blk null,
                        };
                        break :blk @as(usize, @intCast(vi));
                    } else null;
                    runtime.addMenuItem(menu_item, idx_converted);
                    sendBoolResult(stdout_io, true, id_val) catch {};
                } else sendErrorWithId(stdout_io, "missing_params", id_val) catch {};
            },
            .setIcon => {
                if (params) |p| {
                    const type_val = p.object.get("type");
                    const icon_json = IconJson{
                        .type = if (type_val) |t| switch (t) {
                            .string => |s| s,
                            else => "text",
                        } else "text",
                        .title = if (p.object.get("title")) |t| switch (t) {
                            .string => |s| s,
                            else => null,
                        } else null,
                        .name = if (p.object.get("name")) |t| switch (t) {
                            .string => |s| s,
                            else => null,
                        } else null,
                        .accessibility_description = if (p.object.get("accessibility_description")) |t| switch (t) {
                            .string => |s| s,
                            else => null,
                        } else null,
                        .base64_data = if (p.object.get("base64_data")) |t| switch (t) {
                            .string => |s| s,
                            else => null,
                        } else null,
                    };
                    const icon = toIcon(allocator, icon_json) catch {
                        sendErrorWithId(stdout_io, "invalid_icon", id_val) catch {};
                        continue;
                    };
                    runtime.setIcon(icon);
                    sendBoolResult(stdout_io, true, id_val) catch {};
                } else sendErrorWithId(stdout_io, "missing_params", id_val) catch {};
            },
            .listItems => {
                const titles = runtime.listTitles(allocator) catch {
                    sendErrorWithId(stdout_io, "list_failed", id_val) catch {};
                    continue;
                };
                sendStringArrayResult(stdout_io, titles, id_val) catch {};
                for (titles) |t| allocator.free(t);
                allocator.free(titles);
            },
            .unsupported => sendErrorWithId(stdout_io, "method_not_found", id_val) catch {},
        }
    }
}

const IconJson = struct {
    type: []const u8,
    title: ?[]const u8 = null,
    name: ?[]const u8 = null,
    accessibility_description: ?[]const u8 = null,
    base64_data: ?[]const u8 = null,
};

const RpcMethod = enum { setIcon, addTextItem, addActionItem, removeItem, listItems, unsupported };

fn toIcon(allocator: std.mem.Allocator, icon_json: IconJson) !model.TrayIcon {
    if (std.mem.eql(u8, icon_json.type, "text")) {
        const title = icon_json.title orelse "TrayKit";
        return .{ .text = .{ .title = try dupZ(allocator, title) } };
    } else if (std.mem.eql(u8, icon_json.type, "sf_symbol")) {
        const name = icon_json.name orelse "checkmark.circle";
        const acc = icon_json.accessibility_description orelse "TrayKit status icon";
        return .{ .sf_symbol = .{ .name = try dupZ(allocator, name), .accessibility_description = try dupZ(allocator, acc) } };
    } else if (std.mem.eql(u8, icon_json.type, "base64_image")) {
        const data = icon_json.base64_data orelse "";
        return .{ .base64_image = .{ .base64_data = try dupZ(allocator, data) } };
    }
    return error.InvalidIcon;
}

fn toMethod(name: []const u8) RpcMethod {
    if (std.mem.eql(u8, name, "setIcon")) return .setIcon;
    if (std.mem.eql(u8, name, "addText")) return .addTextItem;
    if (std.mem.eql(u8, name, "addAction")) return .addActionItem;
    if (std.mem.eql(u8, name, "removeItem")) return .removeItem;
    if (std.mem.eql(u8, name, "list")) return .listItems;
    return .unsupported;
}

fn dupZ(allocator: std.mem.Allocator, slice: []const u8) ![:0]u8 {
    var buf = try allocator.alloc(u8, slice.len + 1);
    std.mem.copyForwards(u8, buf[0..slice.len], slice);
    buf[slice.len] = 0;
    return buf[0..slice.len :0];
}

fn sendError(writer: anytype, code: []const u8, id: ?std.json.Value) void {
    const id_val = id orelse std.json.Value{ .null = {} };
    sendErrorWithId(writer, code, id_val) catch {};
}

fn sendErrorWithId(writer: anytype, code: []const u8, id: std.json.Value) !void {
    try writer.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try std.json.Stringify.value(id, .{}, writer);
    try writer.writeAll(",\"error\":{\"code\":-32000,\"message\":\"");
    try writer.writeAll(code);
    try writer.writeAll("\"}}\n");
}

fn sendBoolResult(writer: anytype, ok: bool, id: std.json.Value) !void {
    try writer.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try std.json.Stringify.value(id, .{}, writer);
    try writer.writeAll(",\"result\":");
    try writer.writeAll(if (ok) "true" else "false");
    try writer.writeAll("}\n");
}

fn sendStringArrayResult(writer: anytype, items: [][]u8, id: std.json.Value) !void {
    try writer.writeAll("{\"jsonrpc\":\"2.0\",\"id\":");
    try std.json.Stringify.value(id, .{}, writer);
    try writer.writeAll(",\"result\":[");
    var first = true;
    for (items) |item| {
        if (!first) try writer.writeAll(",");
        first = false;
        const val = std.json.Value{ .string = item };
        try std.json.Stringify.value(val, .{}, writer);
    }
    try writer.writeAll("]}\n");
}
