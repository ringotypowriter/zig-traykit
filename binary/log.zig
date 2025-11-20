const std = @import("std");

pub fn isDebugEnabled() bool {
    return std.process.getEnvVarOwned(std.heap.c_allocator, "TRAYKIT_DEBUG") catch null != null;
}

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (!isDebugEnabled()) return;
    std.log.debug(fmt, args);
}

