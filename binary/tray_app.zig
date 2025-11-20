const std = @import("std");
const objc_rt = @import("objc_runtime.zig");
const model = @import("tray_model.zig");

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

        switch (self.config.icon) {
            .text => |cfg| {
                const titleStr = objc_rt.makeStrFn(
                    nsStringClass,
                    objc_rt.getSel("stringWithUTF8String:"),
                    cfg.title,
                );
                objc_rt.msgSend_void_id(button, objc_rt.getSel("setTitle:"), titleStr);
                objc_rt.msgSend_void_id(button, objc_rt.getSel("setImage:"), null);
            },
            .sf_symbol => |cfg| {
                const symbolNameStr = objc_rt.makeStrFn(
                    nsStringClass,
                    objc_rt.getSel("stringWithUTF8String:"),
                    cfg.name,
                );
                const accDescStr = objc_rt.makeStrFn(
                    nsStringClass,
                    objc_rt.getSel("stringWithUTF8String:"),
                    cfg.accessibility_description,
                );
                const nsImageClass = objc_rt.getClass("NSImage");
                const image = objc_rt.msgSend_id_id_id(
                    nsImageClass,
                    objc_rt.getSel("imageWithSystemSymbolName:accessibilityDescription:"),
                    symbolNameStr,
                    accDescStr,
                );
                objc_rt.msgSend_void_id(button, objc_rt.getSel("setImage:"), image);
            },
            .base64_image => |cfg| {
                const nsDataClass = objc_rt.getClass("NSData");
                const base64Str = objc_rt.makeStrFn(
                    nsStringClass,
                    objc_rt.getSel("stringWithUTF8String:"),
                    cfg.base64_data,
                );
                const dataAlloc = objc_rt.msgSend_id0(nsDataClass, objc_rt.getSel("alloc"));
                const data = objc_rt.msgSend_id_id(
                    dataAlloc,
                    objc_rt.getSel("initWithBase64Encoding:"),
                    base64Str,
                );

                const nsImageClass = objc_rt.getClass("NSImage");
                const imageAlloc = objc_rt.msgSend_id0(nsImageClass, objc_rt.getSel("alloc"));
                const image = objc_rt.msgSend_id_id(imageAlloc, objc_rt.getSel("initWithData:"), data);
                objc_rt.msgSend_void_id(button, objc_rt.getSel("setImage:"), image);
            },
        }

        const menuTitleStr = objc_rt.makeStrFn(
            nsStringClass,
            objc_rt.getSel("stringWithUTF8String:"),
            "TrayKit",
        );

        const menuClass = objc_rt.getClass("NSMenu");
        const menuAlloc = objc_rt.msgSend_id0(menuClass, objc_rt.getSel("alloc"));
        const menu = objc_rt.msgSend_id_id(menuAlloc, objc_rt.getSel("initWithTitle:"), menuTitleStr);

        const menuItemClass = objc_rt.getClass("NSMenuItem");

        for (self.config.items) |item_cfg| {
            switch (item_cfg) {
                .action => |action_cfg| {
                    const titleStr = objc_rt.makeStrFn(
                        nsStringClass,
                        objc_rt.getSel("stringWithUTF8String:"),
                        action_cfg.title,
                    );
                    const keyEqStr = objc_rt.makeStrFn(
                        nsStringClass,
                        objc_rt.getSel("stringWithUTF8String:"),
                        action_cfg.key_equivalent,
                    );

                    const itemAlloc = objc_rt.msgSend_id0(menuItemClass, objc_rt.getSel("alloc"));

                    var menuItem: objc_rt.id = undefined;

                    switch (action_cfg.kind) {
                        .quit => {
                            menuItem = objc_rt.menuItemInitFn(
                                itemAlloc,
                                objc_rt.getSel("initWithTitle:action:keyEquivalent:"),
                                titleStr,
                                objc_rt.getSel("terminate:"),
                                keyEqStr,
                            );
                            objc_rt.msgSend_void_id(menuItem, objc_rt.getSel("setTarget:"), app);
                        },
                    }

                    objc_rt.msgSend_void_id(menu, objc_rt.getSel("addItem:"), menuItem);
                },
                .text => |text_cfg| {
                    if (text_cfg.is_separator) {
                        const sepItem = objc_rt.msgSend_id0(
                            menuItemClass,
                            objc_rt.getSel("separatorItem"),
                        );
                        objc_rt.msgSend_void_id(menu, objc_rt.getSel("addItem:"), sepItem);
                    } else {
                        const titleStr = objc_rt.makeStrFn(
                            nsStringClass,
                            objc_rt.getSel("stringWithUTF8String:"),
                            text_cfg.title,
                        );
                        const emptyEqStr = objc_rt.makeStrFn(
                            nsStringClass,
                            objc_rt.getSel("stringWithUTF8String:"),
                            "",
                        );

                        const itemAlloc = objc_rt.msgSend_id0(menuItemClass, objc_rt.getSel("alloc"));
                        const menuItem = objc_rt.menuItemInitFn(
                            itemAlloc,
                            objc_rt.getSel("initWithTitle:action:keyEquivalent:"),
                            titleStr,
                            null,
                            emptyEqStr,
                        );
                        objc_rt.msgSend_void_id(menu, objc_rt.getSel("addItem:"), menuItem);
                    }
                },
            }
        }

        objc_rt.msgSend_void_id(statusItem, objc_rt.getSel("setMenu:"), menu);

        objc_rt.msgSend_void0(app, objc_rt.getSel("run"));
        objc_rt.msgSend_void0(pool, objc_rt.getSel("drain"));
    }
};

pub fn runTray() !void {
    var items = [_]model.MenuItem{
        .{ .text = .{ .title = "TrayKit", .is_separator = false } },
        .{ .text = .{ .title = "", .is_separator = true } },
        .{ .action = .{
            .title = "Quit",
            .key_equivalent = "q",
            .kind = .quit,
        } },
    };

    const app = TrayApp{
        .config = .{
            .icon = .{
            .sf_symbol = .{
                .name = "checkmark.circle",
                .accessibility_description = "TrayKit status icon",
            },
        },
            .items = &items,
        },
    };

    try app.run();
}
