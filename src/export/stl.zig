const std = @import("std");
const heightfield = @import("../core/heightfield.zig");
const HeightfieldMesh = heightfield.HeightfieldMesh;
const Vec3 = heightfield.Vec3;

fn writeU16(file: std.fs.File, val: u16) !void {
    const bytes = std.mem.toBytes(std.mem.nativeToLittle(u16, val));
    try file.writeAll(&bytes);
}

fn writeU32(file: std.fs.File, val: u32) !void {
    const bytes = std.mem.toBytes(std.mem.nativeToLittle(u32, val));
    try file.writeAll(&bytes);
}

pub fn exportBinarySTL(mesh: *const HeightfieldMesh, file_path: []const u8) !void {
    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    // 80-byte header
    var header: [80]u8 = [_]u8{0} ** 80;
    const title = "2MF Filament Painting - Watertight Binary STL";
    @memcpy(header[0..title.len], title);
    try file.writeAll(&header);

    // Number of triangles (indices.len / 3)
    const tri_count = @as(u32, @intCast(mesh.indices.len / 3));
    try writeU32(file, tri_count);

    // Write each triangle
    var i: usize = 0;
    while (i < mesh.indices.len) : (i += 3) {
        const idx0 = mesh.indices[i + 0];
        const idx1 = mesh.indices[i + 1];
        const idx2 = mesh.indices[i + 2];

        const v0 = mesh.vertices[idx0].pos;
        const v1 = mesh.vertices[idx1].pos;
        const v2 = mesh.vertices[idx2].pos;

        // Calculate face normal
        const d1 = Vec3.sub(v1, v0);
        const d2 = Vec3.sub(v2, v0);
        const normal = Vec3.cross(d1, d2).normalize();

        // Normal (3 x f32)
        try writeU32(file, @as(u32, @bitCast(normal.x)));
        try writeU32(file, @as(u32, @bitCast(normal.y)));
        try writeU32(file, @as(u32, @bitCast(normal.z)));

        // V0 (3 x f32)
        try writeU32(file, @as(u32, @bitCast(v0.x)));
        try writeU32(file, @as(u32, @bitCast(v0.y)));
        try writeU32(file, @as(u32, @bitCast(v0.z)));

        // V1 (3 x f32)
        try writeU32(file, @as(u32, @bitCast(v1.x)));
        try writeU32(file, @as(u32, @bitCast(v1.y)));
        try writeU32(file, @as(u32, @bitCast(v1.z)));

        // V2 (3 x f32)
        try writeU32(file, @as(u32, @bitCast(v2.x)));
        try writeU32(file, @as(u32, @bitCast(v2.y)));
        try writeU32(file, @as(u32, @bitCast(v2.z)));

        // Attribute byte count (u16 = 0)
        try writeU16(file, 0);
    }
}

test "stl binary write" {
    const allocator = std.testing.allocator;
    var mesh = HeightfieldMesh.initEmpty(allocator);
    defer mesh.deinit();

    const lum = [_]f32{ 0.1, 0.5, 0.3, 0.8 };
    const stack = @import("../core/filament.zig").FilamentStack.initDefault();
    try mesh.generate(&lum, 2, 2, 2, 2, 50, 50, &stack, .{});

    const tmp_path = "/tmp/test_2mf_export.stl";
    try exportBinarySTL(&mesh, tmp_path);
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    const stat = try std.fs.cwd().statFile(tmp_path);
    try std.testing.expectEqual(@as(u64, 84 + 12 * 50), stat.size);
}
