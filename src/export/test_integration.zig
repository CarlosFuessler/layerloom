const std = @import("std");
const color_mod = @import("../core/color.zig");
const RGB = color_mod.RGB;
const filament_mod = @import("../core/filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const Filament = filament_mod.Filament;
const image_mod = @import("../core/image.zig");
const Image = image_mod.Image;
const heightfield = @import("../core/heightfield.zig");
const HeightfieldMesh = heightfield.HeightfieldMesh;
const optical_mod = @import("../core/optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;
const stl_export = @import("stl.zig");
const threemf_export = @import("threemf.zig");

test "end-to-end 3MF and STL export pipeline" {
    const allocator = std.testing.allocator;

    // 1. Create a 128x128 test image
    var img = try Image.createDefaultPattern(allocator, 128, 128);
    defer img.deinit();

    // 2. Setup 4-layer Filament Stack
    var stack = FilamentStack{};
    _ = stack.add(Filament.init("Bambu PLA Basic Black", RGB.fromHex(0x0a0a0a), 0.6, 0.0, 0.64, 1));
    _ = stack.add(Filament.init("Bambu PLA Basic Blue", RGB.fromHex(0x0047ba), 3.5, 0.64, 1.28, 2));
    _ = stack.add(Filament.init("Bambu PLA Basic Red", RGB.fromHex(0xcc1122), 4.0, 1.28, 1.92, 3));
    _ = stack.add(Filament.init("Bambu PLA Basic Jade White", RGB.fromHex(0xfafafa), 5.2, 1.92, 2.40, 4));

    // 3. Render 2D Optical Transmission Preview Buffer
    const opt_buf = try allocator.alloc(u8, 128 * 128 * 4);
    defer allocator.free(opt_buf);

    const opt_config = OpticalConfig{
        .min_z = 0.40,
        .max_z = 2.40,
        .first_layer_height = 0.16,
        .layer_height = 0.08,
        .quantize_layers = true,
    };

    optical_mod.renderOpticalBuffer(
        img.luminance,
        img.width,
        img.height,
        &stack,
        opt_config,
        opt_buf,
    );

    // Verify optical buffer has valid non-zero RGBA data
    var has_color = false;
    for (0..128 * 128) |p| {
        if (opt_buf[p * 4 + 3] == 255 and (opt_buf[p * 4] > 0 or opt_buf[p * 4 + 1] > 0 or opt_buf[p * 4 + 2] > 0)) {
            has_color = true;
            break;
        }
    }
    try std.testing.expect(has_color);

    // 4. Generate Watertight 3D Heightfield Mesh (64x64 grid)
    var mesh = HeightfieldMesh.initEmpty(allocator);
    defer mesh.deinit();

    try mesh.generate(
        img.luminance,
        img.width,
        img.height,
        64,
        64,
        150.0,
        150.0,
        &stack,
        opt_config,
    );

    // Check vertex & index counts:
    // 64*64*2 vertices = 8192
    try std.testing.expectEqual(@as(usize, 64 * 64 * 2), mesh.vertices.len);
    // (63*63*2 + 63*63*2 + 4*63*2) = (7938 + 7938 + 504) = 16380 triangles = 49140 indices
    try std.testing.expectEqual(@as(usize, 49140), mesh.indices.len);

    // 5. Export Watertight Binary STL
    const stl_path = "/tmp/test_full_relief.stl";
    try stl_export.exportBinarySTL(&mesh, stl_path);
    defer std.fs.cwd().deleteFile(stl_path) catch {};

    const stl_stat = try std.fs.cwd().statFile(stl_path);
    // 84 header bytes + 16380 * 50 bytes = 819084 bytes
    try std.testing.expectEqual(@as(u64, 84 + (49140 / 3) * 50), stl_stat.size);

    // 6. Export Color-Mapped 3MF Archive
    const threemf_path = "/tmp/test_full_painting.3mf";
    try threemf_export.export3MF(
        allocator,
        &mesh,
        &stack,
        .{
            .title = "Integration Test Painting",
            .first_layer_height = 0.16,
            .layer_height = 0.08,
        },
        threemf_path,
    );
    defer std.fs.cwd().deleteFile(threemf_path) catch {};

    const threemf_stat = try std.fs.cwd().statFile(threemf_path);
    try std.testing.expect(threemf_stat.size > 1000);
}
