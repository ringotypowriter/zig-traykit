const tray = @import("tray_app.zig");

pub fn main() !void {
    try tray.runTray();
}
