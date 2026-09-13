const std = @import("std");
const math = std.math;
const color_mod = @import("color.zig");
const RGB = color_mod.RGB;
const filament_mod = @import("filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const optical_mod = @import("optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len_sq = self.x * self.x + self.y * self.y + self.z * self.z;
        if (len_sq < 0.000001) return .{ .x = 0, .y = 0, .z = 1 };
        const inv_len = 1.0 / @sqrt(len_sq);
        return .{ .x = self.x * inv_len, .y = self.y * inv_len, .z = self.z * inv_len };
    }
};

pub const MeshVertex = struct {
    pos: Vec3,
    normal: Vec3,
    uv: [2]f32,
    color: [3]f32,
    filament_id: u8,
};

pub const Triangle = struct {
    v0: Vec3,
    v1: Vec3,
    v2: Vec3,
    normal: Vec3,
    filament_id: u8 = 0,
    color_rgb: RGB = .{ .r = 1, .g = 1, .b = 1 },
};

pub const HeightfieldMesh = struct {
    vertices: []MeshVertex = &.{},
    indices: []u32 = &.{},
    width_mm: f32 = 150.0,
    height_mm: f32 = 150.0,
    grid_w: u32 = 0,
    grid_h: u32 = 0,
    allocator: std.mem.Allocator,

    pub fn initEmpty(allocator: std.mem.Allocator) HeightfieldMesh {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *HeightfieldMesh) void {
        if (self.vertices.len > 0) {
            self.allocator.free(self.vertices);
            self.vertices = &.{};
        }
        if (self.indices.len > 0) {
            self.allocator.free(self.indices);
            self.indices = &.{};
        }
    }

    pub fn sampleLuminanceBilinear(luminance: []const f32, src_w: u32, src_h: u32, u: f32, v: f32) f32 {
        const x = @max(0.0, @min(@as(f32, @floatFromInt(src_w - 1)), u * @as(f32, @floatFromInt(src_w - 1))));
        const y = @max(0.0, @min(@as(f32, @floatFromInt(src_h - 1)), v * @as(f32, @floatFromInt(src_h - 1))));

        const x0 = @as(usize, @intFromFloat(x));
        const y0 = @as(usize, @intFromFloat(y));
        const x1 = @min(x0 + 1, src_w - 1);
        const y1 = @min(y0 + 1, src_h - 1);

        const fx = x - @as(f32, @floatFromInt(x0));
        const fy = y - @as(f32, @floatFromInt(y0));

        const v00 = luminance[y0 * src_w + x0];
        const v10 = luminance[y0 * src_w + x1];
        const v01 = luminance[y1 * src_w + x0];
        const v11 = luminance[y1 * src_w + x1];

        return (v00 * (1.0 - fx) + v10 * fx) * (1.0 - fy) + (v01 * (1.0 - fx) + v11 * fx) * fy;
    }

    /// Generates a complete 100% Watertight 3D mesh: Top surface + 4 vertical side walls + flat bottom floor (Z = 0.0)
    pub fn generate(
        self: *HeightfieldMesh,
        luminance: []const f32,
        src_w: u32,
        src_h: u32,
        target_grid_w: u32,
        target_grid_h: u32,
        width_mm: f32,
        height_mm: f32,
        stack: *const FilamentStack,
        config: OpticalConfig,
    ) !void {
        self.deinit();

        const gw = @max(2, target_grid_w);
        const gh = @max(2, target_grid_h);
        self.grid_w = gw;
        self.grid_h = gh;
        self.width_mm = width_mm;
        self.height_mm = height_mm;

        // Number of vertices:
        // 1. Top grid: gw * gh
        // 2. Bottom grid: gw * gh (for Z = 0)
        const top_vert_count = @as(usize, gw) * @as(usize, gh);
        const total_vert_count = top_vert_count * 2;

        // Number of triangles:
        // Top: (gw-1)*(gh-1)*2
        // Bottom: (gw-1)*(gh-1)*2
        // Walls: 2*(gw-1)*2 + 2*(gh-1)*2 = 4*(gw-1 + gh-1)
        const top_quads = @as(usize, gw - 1) * @as(usize, gh - 1);
        const wall_quads = (@as(usize, gw - 1) + @as(usize, gh - 1)) * 2;
        const total_tri_count = (top_quads * 2 + wall_quads) * 2;
        const total_index_count = total_tri_count * 3;

        self.vertices = try self.allocator.alloc(MeshVertex, total_vert_count);
        self.indices = try self.allocator.alloc(u32, total_index_count);

        const z_span = config.max_z - config.min_z;

        // 1. Generate top grid vertices
        for (0..gh) |gy| {
            const v = @as(f32, @floatFromInt(gy)) / @as(f32, @floatFromInt(gh - 1));
            const y_mm = (v - 0.5) * height_mm;

            for (0..gw) |gx| {
                const u = @as(f32, @floatFromInt(gx)) / @as(f32, @floatFromInt(gw - 1));
                const x_mm = (u - 0.5) * width_mm;

                const lum = sampleLuminanceBilinear(luminance, src_w, src_h, u, v);
                var z_val = config.min_z + lum * z_span;
                if (config.quantize_layers) {
                    z_val = optical_mod.quantizeZ(z_val, config.first_layer_height, config.layer_height);
                }

                const fil_idx = @as(u8, @intCast(stack.getActiveFilamentAtZ(z_val)));
                const opt_color = optical_mod.evaluateOpticalColor(z_val, stack);

                const top_idx = gy * gw + gx;
                self.vertices[top_idx] = .{
                    .pos = Vec3.init(x_mm, y_mm, z_val),
                    .normal = Vec3.init(0, 0, 1),
                    .uv = [2]f32{ u, v },
                    .color = [3]f32{ opt_color.r, opt_color.g, opt_color.b },
                    .filament_id = fil_idx,
                };

                // Corresponding bottom vertex at Z = 0.0
                const bot_idx = top_vert_count + top_idx;
                self.vertices[bot_idx] = .{
                    .pos = Vec3.init(x_mm, y_mm, 0.0),
                    .normal = Vec3.init(0, 0, -1),
                    .uv = [2]f32{ u, v },
                    .color = [3]f32{ 0.1, 0.1, 0.1 },
                    .filament_id = 0,
                };
            }
        }

        // 2. Compute smooth/faceted normals for top surface
        for (0..gh) |gy| {
            for (0..gw) |gx| {
                const idx = gy * gw + gx;
                const p = self.vertices[idx].pos;

                const left = if (gx > 0) self.vertices[gy * gw + (gx - 1)].pos else p;
                const right = if (gx + 1 < gw) self.vertices[gy * gw + (gx + 1)].pos else p;
                const down = if (gy > 0) self.vertices[(gy - 1) * gw + gx].pos else p;
                const up = if (gy + 1 < gh) self.vertices[(gy + 1) * gw + gx].pos else p;

                const dx = Vec3.sub(right, left);
                const dy = Vec3.sub(up, down);
                const n = Vec3.cross(dx, dy).normalize();
                self.vertices[idx].normal = n;
            }
        }

        // 3. Build triangle index buffers
        var idx_ptr: usize = 0;

        // --- TOP SURFACE TRIANGLES ---
        for (0..gh - 1) |gy| {
            for (0..gw - 1) |gx| {
                const idx00 = @as(u32, @intCast(gy * gw + gx));
                const idx10 = @as(u32, @intCast(gy * gw + (gx + 1)));
                const idx01 = @as(u32, @intCast((gy + 1) * gw + gx));
                const idx11 = @as(u32, @intCast((gy + 1) * gw + (gx + 1)));

                // Tri 1: (idx00, idx10, idx11)
                self.indices[idx_ptr + 0] = idx00;
                self.indices[idx_ptr + 1] = idx10;
                self.indices[idx_ptr + 2] = idx11;

                // Tri 2: (idx00, idx11, idx01)
                self.indices[idx_ptr + 3] = idx00;
                self.indices[idx_ptr + 4] = idx11;
                self.indices[idx_ptr + 5] = idx01;
                idx_ptr += 6;
            }
        }

        // --- BOTTOM SURFACE TRIANGLES (Z = 0.0, Winding reversed for outward facing normal) ---
        const b_offset = @as(u32, @intCast(top_vert_count));
        for (0..gh - 1) |gy| {
            for (0..gw - 1) |gx| {
                const idx00 = b_offset + @as(u32, @intCast(gy * gw + gx));
                const idx10 = b_offset + @as(u32, @intCast(gy * gw + (gx + 1)));
                const idx01 = b_offset + @as(u32, @intCast((gy + 1) * gw + gx));
                const idx11 = b_offset + @as(u32, @intCast((gy + 1) * gw + (gx + 1)));

                // Reverse winding: (idx00, idx11, idx10) & (idx00, idx01, idx11)
                self.indices[idx_ptr + 0] = idx00;
                self.indices[idx_ptr + 1] = idx11;
                self.indices[idx_ptr + 2] = idx10;

                self.indices[idx_ptr + 3] = idx00;
                self.indices[idx_ptr + 4] = idx01;
                self.indices[idx_ptr + 5] = idx11;
                idx_ptr += 6;
            }
        }

        // --- SIDE WALL 1: BOTTOM EDGE (gy = 0) ---
        for (0..gw - 1) |gx| {
            const top_0 = @as(u32, @intCast(0 * gw + gx));
            const top_1 = @as(u32, @intCast(0 * gw + (gx + 1)));
            const bot_0 = b_offset + top_0;
            const bot_1 = b_offset + top_1;

            self.indices[idx_ptr + 0] = top_0;
            self.indices[idx_ptr + 1] = bot_0;
            self.indices[idx_ptr + 2] = top_1;

            self.indices[idx_ptr + 3] = top_1;
            self.indices[idx_ptr + 4] = bot_0;
            self.indices[idx_ptr + 5] = bot_1;
            idx_ptr += 6;
        }

        // --- SIDE WALL 2: TOP EDGE (gy = gh - 1) ---
        const last_gy = gh - 1;
        for (0..gw - 1) |gx| {
            const top_0 = @as(u32, @intCast(last_gy * gw + gx));
            const top_1 = @as(u32, @intCast(last_gy * gw + (gx + 1)));
            const bot_0 = b_offset + top_0;
            const bot_1 = b_offset + top_1;

            self.indices[idx_ptr + 0] = top_0;
            self.indices[idx_ptr + 1] = top_1;
            self.indices[idx_ptr + 2] = bot_0;

            self.indices[idx_ptr + 3] = top_1;
            self.indices[idx_ptr + 4] = bot_1;
            self.indices[idx_ptr + 5] = bot_0;
            idx_ptr += 6;
        }

        // --- SIDE WALL 3: LEFT EDGE (gx = 0) ---
        for (0..gh - 1) |gy| {
            const top_0 = @as(u32, @intCast(gy * gw + 0));
            const top_1 = @as(u32, @intCast((gy + 1) * gw + 0));
            const bot_0 = b_offset + top_0;
            const bot_1 = b_offset + top_1;

            self.indices[idx_ptr + 0] = top_0;
            self.indices[idx_ptr + 1] = top_1;
            self.indices[idx_ptr + 2] = bot_0;

            self.indices[idx_ptr + 3] = top_1;
            self.indices[idx_ptr + 4] = bot_1;
            self.indices[idx_ptr + 5] = bot_0;
            idx_ptr += 6;
        }

        // --- SIDE WALL 4: RIGHT EDGE (gx = gw - 1) ---
        const last_gx = gw - 1;
        for (0..gh - 1) |gy| {
            const top_0 = @as(u32, @intCast(gy * gw + last_gx));
            const top_1 = @as(u32, @intCast((gy + 1) * gw + last_gx));
            const bot_0 = b_offset + top_0;
            const bot_1 = b_offset + top_1;

            self.indices[idx_ptr + 0] = top_0;
            self.indices[idx_ptr + 1] = bot_0;
            self.indices[idx_ptr + 2] = top_1;

            self.indices[idx_ptr + 3] = top_1;
            self.indices[idx_ptr + 4] = bot_0;
            self.indices[idx_ptr + 5] = bot_1;
            idx_ptr += 6;
        }
    }
};

test "heightfield generation watertight" {
    const allocator = std.testing.allocator;
    var mesh = HeightfieldMesh.initEmpty(allocator);
    defer mesh.deinit();

    const lum = [_]f32{ 0.1, 0.5, 0.3, 0.8 };
    const stack = FilamentStack.initDefault();
    try mesh.generate(&lum, 2, 2, 2, 2, 100, 100, &stack, .{});

    try std.testing.expectEqual(@as(usize, 8), mesh.vertices.len);
    try std.testing.expectEqual(@as(usize, 36), mesh.indices.len);
}
