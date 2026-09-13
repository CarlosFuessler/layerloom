const std = @import("std");
const math = std.math;
const c = @import("../c.zig").c;
const color_mod = @import("color.zig");
const RGB = color_mod.RGB;
const RGBA = color_mod.RGBA;
const RGB8 = color_mod.RGB8;

pub const ImageAdjustments = struct {
    brightness: f32 = 0.0, // [-1.0, +1.0]
    contrast: f32 = 1.0, // [0.0, 3.0]
    gamma: f32 = 1.0, // [0.1, 3.0]
    invert: bool = false,
    black_point: f32 = 0.0, // [0.0, 1.0]
    white_point: f32 = 1.0, // [0.0, 1.0]
};

pub const Image = struct {
    width: u32 = 0,
    height: u32 = 0,
    channels: u32 = 4,
    pixels: []u8 = &.{},
    luminance: []f32 = &.{},
    allocator: std.mem.Allocator,

    pub fn initEmpty(allocator: std.mem.Allocator) Image {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Image) void {
        if (self.pixels.len > 0) {
            self.allocator.free(self.pixels);
            self.pixels = &.{};
        }
        if (self.luminance.len > 0) {
            self.allocator.free(self.luminance);
            self.luminance = &.{};
        }
        self.width = 0;
        self.height = 0;
    }

    pub fn sanitizePath(allocator: std.mem.Allocator, raw_path: []const u8) ![]u8 {
        var trimmed = std.mem.trim(u8, raw_path, " \t\r\n'\"");
        if (trimmed.len == 0) return error.EmptyPath;

        // Expand ~/ if present
        if (std.mem.startsWith(u8, trimmed, "~/")) {
            const home = std.posix.getenv("HOME") orelse "/Users";
            return std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, trimmed[2..] });
        }

        // Unescape backslash-escaped spaces (e.g. from macOS terminal drag-and-drop)
        var result = std.ArrayList(u8){};
        errdefer result.deinit(allocator);

        var i: usize = 0;
        while (i < trimmed.len) {
            if (trimmed[i] == '\\' and i + 1 < trimmed.len and trimmed[i + 1] == ' ') {
                try result.append(allocator, ' ');
                i += 2;
            } else {
                try result.append(allocator, trimmed[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, file_path_raw: []const u8) !Image {
        const clean_path = try sanitizePath(allocator, file_path_raw);
        defer allocator.free(clean_path);

        const clean_z = try allocator.allocSentinel(u8, clean_path.len, 0);
        defer allocator.free(clean_z);
        @memcpy(clean_z, clean_path);

        var w: c_int = 0;
        var h: c_int = 0;
        var comp: c_int = 0;

        const raw_data = c.stbi_load(clean_z.ptr, &w, &h, &comp, 4);
        if (raw_data == null) {
            return error.ImageLoadFailed;
        }
        defer c.stbi_image_free(raw_data);

        const width_u32 = @as(u32, @intCast(w));
        const height_u32 = @as(u32, @intCast(h));
        const pixel_count = @as(usize, width_u32) * @as(usize, height_u32);
        const byte_count = pixel_count * 4;

        const pixels_copy = try allocator.alloc(u8, byte_count);
        @memcpy(pixels_copy, raw_data[0..byte_count]);

        const lum = try allocator.alloc(f32, pixel_count);

        var img = Image{
            .width = width_u32,
            .height = height_u32,
            .channels = 4,
            .pixels = pixels_copy,
            .luminance = lum,
            .allocator = allocator,
        };

        img.recomputeLuminance(.{});
        return img;
    }

    pub fn loadFromMemory(allocator: std.mem.Allocator, buffer: []const u8) !Image {
        var w: c_int = 0;
        var h: c_int = 0;
        var comp: c_int = 0;

        const raw_data = c.stbi_load_from_memory(buffer.ptr, @intCast(buffer.len), &w, &h, &comp, 4);
        if (raw_data == null) {
            return error.ImageLoadFailed;
        }
        defer c.stbi_image_free(raw_data);

        const width_u32 = @as(u32, @intCast(w));
        const height_u32 = @as(u32, @intCast(h));
        const pixel_count = @as(usize, width_u32) * @as(usize, height_u32);
        const byte_count = pixel_count * 4;

        const pixels_copy = try allocator.alloc(u8, byte_count);
        @memcpy(pixels_copy, raw_data[0..byte_count]);

        const lum = try allocator.alloc(f32, pixel_count);

        var img = Image{
            .width = width_u32,
            .height = height_u32,
            .channels = 4,
            .pixels = pixels_copy,
            .luminance = lum,
            .allocator = allocator,
        };

        img.recomputeLuminance(.{});
        return img;
    }

    /// Creates a high-detail procedural default test image (radial gradient with circular rings and patterns)
    pub fn createDefaultPattern(allocator: std.mem.Allocator, w: u32, h: u32) !Image {
        const pixel_count = @as(usize, w) * @as(usize, h);
        const pixels = try allocator.alloc(u8, pixel_count * 4);
        const lum = try allocator.alloc(f32, pixel_count);

        const cx = @as(f32, @floatFromInt(w)) * 0.5;
        const cy = @as(f32, @floatFromInt(h)) * 0.5;
        const max_radius = @sqrt(cx * cx + cy * cy);

        for (0..h) |y| {
            const fy = @as(f32, @floatFromInt(y));
            for (0..w) |x| {
                const fx = @as(f32, @floatFromInt(x));
                const dx = fx - cx;
                const dy = fy - cy;
                const dist = @sqrt(dx * dx + dy * dy);
                const angle = math.atan2(dy, dx);

                // Combine radial gradient, concentric rings, and soft harmonics
                const norm_dist = dist / max_radius;
                const ring = 0.5 + 0.5 * @sin(dist * 0.15 + angle * 3.0);
                const vignette = 1.0 - math.clamp(norm_dist * 0.9, 0.0, 1.0);
                const val = math.clamp(vignette * 0.7 + ring * 0.3, 0.0, 1.0);

                const u8_val = @as(u8, @intFromFloat(val * 255.0));
                const idx = (y * w + x) * 4;
                pixels[idx + 0] = u8_val;
                pixels[idx + 1] = u8_val;
                pixels[idx + 2] = u8_val;
                pixels[idx + 3] = 255;
            }
        }

        var img = Image{
            .width = w,
            .height = h,
            .channels = 4,
            .pixels = pixels,
            .luminance = lum,
            .allocator = allocator,
        };
        img.recomputeLuminance(.{});
        return img;
    }

    pub fn recomputeLuminance(self: *Image, adj: ImageAdjustments) void {
        const pixel_count = @as(usize, self.width) * @as(usize, self.height);
        if (self.luminance.len < pixel_count or self.pixels.len < pixel_count * 4) return;

        const bp = adj.black_point;
        const wp = if (adj.white_point > bp + 0.001) adj.white_point else bp + 0.001;
        const range = wp - bp;
        const inv_gamma = if (adj.gamma > 0.01) 1.0 / adj.gamma else 1.0;

        for (0..pixel_count) |i| {
            const idx = i * 4;
            const r_f = @as(f32, @floatFromInt(self.pixels[idx + 0])) / 255.0;
            const g_f = @as(f32, @floatFromInt(self.pixels[idx + 1])) / 255.0;
            const b_f = @as(f32, @floatFromInt(self.pixels[idx + 2])) / 255.0;

            // ITU-R BT.709 perceived luminance
            var l = 0.2126 * r_f + 0.7152 * g_f + 0.0722 * b_f;

            // Black/White point remapping
            l = (l - bp) / range;
            l = math.clamp(l, 0.0, 1.0);

            // Contrast adjustment
            l = (l - 0.5) * adj.contrast + 0.5;
            l = math.clamp(l, 0.0, 1.0);

            // Brightness adjustment
            l = l + adj.brightness;
            l = math.clamp(l, 0.0, 1.0);

            // Gamma curve
            l = math.pow(f32, l, inv_gamma);

            // Invert if requested
            if (adj.invert) {
                l = 1.0 - l;
            }

            self.luminance[i] = math.clamp(l, 0.0, 1.0);
        }
    }

    pub fn computeHistogram(self: *const Image, bins: *[256]u32) void {
        @memset(bins, 0);
        for (self.luminance) |l| {
            const bin_idx = @as(usize, @intFromFloat(math.clamp(l * 255.0 + 0.5, 0.0, 255.0)));
            bins[bin_idx] += 1;
        }
    }
};

test "create and process image" {
    const allocator = std.testing.allocator;
    var img = try Image.createDefaultPattern(allocator, 64, 64);
    defer img.deinit();

    try std.testing.expectEqual(@as(u32, 64), img.width);
    try std.testing.expectEqual(@as(u32, 64), img.height);
    try std.testing.expectEqual(@as(usize, 64 * 64), img.luminance.len);

    var bins: [256]u32 = undefined;
    img.computeHistogram(&bins);
    var total: u32 = 0;
    for (bins) |b| total += b;
    try std.testing.expectEqual(@as(u32, 64 * 64), total);
}

test "path sanitization" {
    const allocator = std.testing.allocator;
    const p1 = try Image.sanitizePath(allocator, "  '/Users/test/my image.png'  ");
    defer allocator.free(p1);
    try std.testing.expectEqualStrings("/Users/test/my image.png", p1);

    const p2 = try Image.sanitizePath(allocator, "\"/Users/test/my\\ photo.jpg\"");
    defer allocator.free(p2);
    try std.testing.expectEqualStrings("/Users/test/my photo.jpg", p2);
}
