const std = @import("std");

const objc = @cImport({
    @cInclude("objc/runtime.h");
    @cInclude("objc/message.h");
});
pub const id = ?*anyopaque;
pub const SEL = ?*anyopaque;
pub const Class = ?*anyopaque;

pub fn getClass(name: [*:0]const u8) Class {
    return objc.objc_getClass(name);
}

pub fn getSel(name: [*:0]const u8) SEL {
    return objc.sel_registerName(name);
}

const MsgSendId0 = *const fn (id, SEL) callconv(.c) id;
const MsgSendIdId = *const fn (id, SEL, id) callconv(.c) id;
const MsgSendIdIdId = *const fn (id, SEL, id, id) callconv(.c) id;
const MsgSendIdF64 = *const fn (id, SEL, f64) callconv(.c) id;
const MsgSendIdI64 = *const fn (id, SEL, i64) callconv(.c) id;
const MsgSendVoid0 = *const fn (id, SEL) callconv(.c) void;
const MsgSendVoidId = *const fn (id, SEL, id) callconv(.c) void;
const MsgSendVoidI64 = *const fn (id, SEL, i64) callconv(.c) void;
const MsgSendVoidIdI64 = *const fn (id, SEL, id, i64) callconv(.c) void;
const MakeStrFn = *const fn (id, SEL, [*:0]const u8) callconv(.c) id;
const MenuItemInitFn = *const fn (id, SEL, id, SEL, id) callconv(.c) id;

pub const msgSend_id0: MsgSendId0 = @ptrCast(&objc.objc_msgSend);
pub const msgSend_id_id: MsgSendIdId = @ptrCast(&objc.objc_msgSend);
pub const msgSend_id_id_id: MsgSendIdIdId = @ptrCast(&objc.objc_msgSend);
pub const msgSend_id_f64: MsgSendIdF64 = @ptrCast(&objc.objc_msgSend);
pub const msgSend_id_i64: MsgSendIdI64 = @ptrCast(&objc.objc_msgSend);
pub const msgSend_void0: MsgSendVoid0 = @ptrCast(&objc.objc_msgSend);
pub const msgSend_void_id: MsgSendVoidId = @ptrCast(&objc.objc_msgSend);
pub const msgSend_void_i64: MsgSendVoidI64 = @ptrCast(&objc.objc_msgSend);
pub const msgSend_void_id_i64: MsgSendVoidIdI64 = @ptrCast(&objc.objc_msgSend);
pub const makeStrFn: MakeStrFn = @ptrCast(&objc.objc_msgSend);
pub const menuItemInitFn: MenuItemInitFn = @ptrCast(&objc.objc_msgSend);

pub const NSVariableStatusItemLength: f64 = -1.0;
