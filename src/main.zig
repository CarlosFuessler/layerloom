const std = @import("std");
const RaylibApp = @import("raylib_app.zig").RaylibApp;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try RaylibApp.init(allocator);
    defer app.deinit();

    try app.run();
}
