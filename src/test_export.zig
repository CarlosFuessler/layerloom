const std = @import("std");
const root = @import("root.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    std.debug.print("Generating sample 3MF and STL files...\n", .{});

    var img = try root.image.Image.createDefaultPattern(allocator, 128, 128);
    defer img.deinit();

    var stack = root.filament.FilamentStack.initDefault();
    const opt_config = root.optical.OpticalConfig{};

    var mesh = root.heightfield.HeightfieldMesh.initEmpty(allocator);
    defer mesh.deinit();

    try mesh.generate(img.luminance, img.width, img.height, 64, 64, 150, 150, &stack, opt_config);

    try root.stl.exportBinarySTL(&mesh, "sample_relief.stl");
    try root.threemf.export3MF(allocator, &mesh, &stack, .{}, "sample_painting.3mf");

    std.debug.print("Successfully generated sample_relief.stl and sample_painting.3mf!\n", .{});
}
