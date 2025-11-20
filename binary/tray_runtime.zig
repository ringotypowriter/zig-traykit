const std = @import("std");
const objc_rt = @import("objc_runtime.zig");
const model = @import("tray_model.zig");
const c = @cImport({
    @cInclude("dispatch/dispatch.h");
    @cInclude("pthread.h");
});

pub const TrayRuntime = struct {
    nsStringClass: objc_rt.id,
    menuItemClass: objc_rt.id,
    app: objc_rt.id,
    menu: objc_rt.id,
    button: objc_rt.id,
    statusItem: objc_rt.id,
    item_count: usize,

    pub fn init(app: objc_rt.id, statusItem: objc_rt.id, button: objc_rt.id, nsStringClass: objc_rt.id) TrayRuntime {
        return .{
            .nsStringClass = nsStringClass,
            .menuItemClass = objc_rt.getClass("NSMenuItem"),
            .app = app,
            .menu = null,
            .button = button,
            .statusItem = statusItem,
            .item_count = 0,
        };
    }

    fn onMain(ctx: ?*anyopaque, func: *const fn (?*anyopaque) callconv(.c) void) void {
        // Avoid deadlock if already on the main thread (dispatch_sync on main queue would trap).
        if (c.pthread_main_np() != 0) {
            func(ctx);
            return;
        }

        const queue = c.dispatch_get_main_queue();
        c.dispatch_sync_f(queue, ctx, func);
    }

    pub fn setIcon(self: *TrayRuntime, icon: model.TrayIcon) void {
        var payload = SetIconPayload{ .runtime = self, .icon = icon };
        onMain(&payload, SetIconPayload.run);
    }

    fn setIconSync(self: *TrayRuntime, icon: model.TrayIcon) void {
        switch (icon) {
            .text => |cfg| {
                const titleStr = objc_rt.makeStrFn(
                    self.nsStringClass,
                    objc_rt.getSel("stringWithUTF8String:"),
                    cfg.title,
                );
                objc_rt.msgSend_void_id(self.button, objc_rt.getSel("setTitle:"), titleStr);
                objc_rt.msgSend_void_id(self.button, objc_rt.getSel("setImage:"), null);
            },
            .sf_symbol => |cfg| {
                const symbolNameStr = objc_rt.makeStrFn(
                    self.nsStringClass,
                    objc_rt.getSel("stringWithUTF8String:"),
                    cfg.name,
                );
                const accDescStr = objc_rt.makeStrFn(
                    self.nsStringClass,
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
                objc_rt.msgSend_void_id(self.button, objc_rt.getSel("setImage:"), image);
            },
            .base64_image => |cfg| {
                const nsDataClass = objc_rt.getClass("NSData");
                const base64Str = objc_rt.makeStrFn(
                    self.nsStringClass,
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
                objc_rt.msgSend_void_id(self.button, objc_rt.getSel("setImage:"), image);
            },
        }
    }

    pub fn initMenu(self: *TrayRuntime, title: [*:0]const u8) void {
        var payload = InitMenuPayload{ .runtime = self, .title = title };
        onMain(&payload, InitMenuPayload.run);
    }

    pub fn addMenuItem(self: *TrayRuntime, item_cfg: model.MenuItem, index_opt: ?usize) void {
        var payload = AddPayload{ .runtime = self, .item_cfg = item_cfg, .index_opt = index_opt };
        onMain(&payload, AddPayload.run);
    }

    pub fn removeMenuItem(self: *TrayRuntime, index: usize) bool {
        var payload = RemovePayload{ .runtime = self, .index = index, .ok = false };
        onMain(&payload, RemovePayload.run);
        return payload.ok;
    }

    pub fn listTitles(self: *TrayRuntime, allocator: std.mem.Allocator) ![][]u8 {
        var payload = ListPayload{ .runtime = self, .allocator = allocator, .titles = undefined, .err = null };
        onMain(&payload, ListPayload.run);
        if (payload.err) |e| return e;
        return payload.titles;
    }

    const SetIconPayload = struct {
        runtime: *TrayRuntime,
        icon: model.TrayIcon,

        fn run(ctx: ?*anyopaque) callconv(.c) void {
            const self: *SetIconPayload = @ptrCast(@alignCast(ctx));
            self.runtime.setIconSync(self.icon);
        }
    };

    const InitMenuPayload = struct {
        runtime: *TrayRuntime,
        title: [*:0]const u8,

        fn run(ctx: ?*anyopaque) callconv(.c) void {
            const self: *InitMenuPayload = @ptrCast(@alignCast(ctx));
            const menuTitleStr = objc_rt.makeStrFn(
                self.runtime.nsStringClass,
                objc_rt.getSel("stringWithUTF8String:"),
                self.title,
            );

            const menuClass = objc_rt.getClass("NSMenu");
            const menuAlloc = objc_rt.msgSend_id0(menuClass, objc_rt.getSel("alloc"));
            self.runtime.menu = objc_rt.msgSend_id_id(menuAlloc, objc_rt.getSel("initWithTitle:"), menuTitleStr);
            objc_rt.msgSend_void_id(self.runtime.statusItem, objc_rt.getSel("setMenu:"), self.runtime.menu);
            self.runtime.item_count = 0;
        }
    };

    const AddPayload = struct {
        runtime: *TrayRuntime,
        item_cfg: model.MenuItem,
        index_opt: ?usize,

        fn run(ctx: ?*anyopaque) callconv(.c) void {
            const self: *AddPayload = @ptrCast(@alignCast(ctx));
            const insert_index: usize = self.index_opt orelse self.runtime.item_count;

            switch (self.item_cfg) {
                .action => |action_cfg| {
                    const titleStr = objc_rt.makeStrFn(
                        self.runtime.nsStringClass,
                        objc_rt.getSel("stringWithUTF8String:"),
                        action_cfg.title,
                    );
                    const keyEqStr = objc_rt.makeStrFn(
                        self.runtime.nsStringClass,
                        objc_rt.getSel("stringWithUTF8String:"),
                        action_cfg.key_equivalent,
                    );

                    const itemAlloc = objc_rt.msgSend_id0(self.runtime.menuItemClass, objc_rt.getSel("alloc"));

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
                            objc_rt.msgSend_void_id(menuItem, objc_rt.getSel("setTarget:"), self.runtime.app);
                        },
                    }

                    if (insert_index == self.runtime.item_count) {
                        objc_rt.msgSend_void_id(self.runtime.menu, objc_rt.getSel("addItem:"), menuItem);
                    } else {
                        objc_rt.msgSend_void_id_i64(
                            self.runtime.menu,
                            objc_rt.getSel("insertItem:atIndex:"),
                            menuItem,
                            @as(i64, @intCast(insert_index)),
                        );
                    }
                },
                .text => |text_cfg| {
                    if (text_cfg.is_separator) {
                        const sepItem = objc_rt.msgSend_id0(
                            self.runtime.menuItemClass,
                            objc_rt.getSel("separatorItem"),
                        );
                        if (insert_index == self.runtime.item_count) {
                            objc_rt.msgSend_void_id(self.runtime.menu, objc_rt.getSel("addItem:"), sepItem);
                        } else {
                            objc_rt.msgSend_void_id_i64(
                                self.runtime.menu,
                                objc_rt.getSel("insertItem:atIndex:"),
                                sepItem,
                                @as(i64, @intCast(insert_index)),
                            );
                        }
                    } else {
                        const titleStr = objc_rt.makeStrFn(
                            self.runtime.nsStringClass,
                            objc_rt.getSel("stringWithUTF8String:"),
                            text_cfg.title,
                        );
                        const emptyEqStr = objc_rt.makeStrFn(
                            self.runtime.nsStringClass,
                            objc_rt.getSel("stringWithUTF8String:"),
                            "",
                        );

                        const itemAlloc = objc_rt.msgSend_id0(self.runtime.menuItemClass, objc_rt.getSel("alloc"));
                        const menuItem = objc_rt.menuItemInitFn(
                            itemAlloc,
                            objc_rt.getSel("initWithTitle:action:keyEquivalent:"),
                            titleStr,
                            null,
                            emptyEqStr,
                        );
                        if (insert_index == self.runtime.item_count) {
                            objc_rt.msgSend_void_id(self.runtime.menu, objc_rt.getSel("addItem:"), menuItem);
                        } else {
                            objc_rt.msgSend_void_id_i64(
                                self.runtime.menu,
                                objc_rt.getSel("insertItem:atIndex:"),
                                menuItem,
                                @as(i64, @intCast(insert_index)),
                            );
                        }
                    }
                },
            }

            self.runtime.item_count += 1;
        }
    };

    const RemovePayload = struct {
        runtime: *TrayRuntime,
        index: usize,
        ok: bool,

        fn run(ctx: ?*anyopaque) callconv(.c) void {
            const self: *RemovePayload = @ptrCast(@alignCast(ctx));
            if (self.index >= self.runtime.item_count) {
                self.ok = false;
                return;
            }
            objc_rt.msgSend_void_i64(
                self.runtime.menu,
                objc_rt.getSel("removeItemAtIndex:"),
                @as(i64, @intCast(self.index)),
            );
            self.runtime.item_count -= 1;
            self.ok = true;
        }
    };

    const ListPayload = struct {
        runtime: *TrayRuntime,
        allocator: std.mem.Allocator,
        titles: [][]u8,
        err: ?anyerror,

        fn run(ctx: ?*anyopaque) callconv(.c) void {
            const self: *ListPayload = @ptrCast(@alignCast(ctx));
            self.titles = self.allocator.alloc([]u8, self.runtime.item_count) catch {
                self.err = error.OutOfMemory;
                return;
            };
            var idx: usize = 0;
            while (idx < self.runtime.item_count) : (idx += 1) {
                const item = objc_rt.msgSend_id_i64(
                    self.runtime.menu,
                    objc_rt.getSel("itemAtIndex:"),
                    @as(i64, @intCast(idx)),
                );
                if (item == null) {
                    self.titles[idx] = self.allocator.dupe(u8, "") catch {
                        self.err = error.OutOfMemory;
                        return;
                    };
                    continue;
                }
                const title = objc_rt.msgSend_id0(item, objc_rt.getSel("title"));
                const utf8 = objc_rt.msgSend_id0(title, objc_rt.getSel("UTF8String"));
                const cstr: [*:0]const u8 = @ptrCast(utf8);
                self.titles[idx] = self.allocator.dupe(u8, std.mem.span(cstr)) catch {
                    self.err = error.OutOfMemory;
                    return;
                };
            }
        }
    };
};
