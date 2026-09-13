const std = @import("std");
const math = std.math;
const color_mod = @import("color.zig");
const RGB = color_mod.RGB;
const RGBA = color_mod.RGBA;
const RGB8 = color_mod.RGB8;
const RGBA8 = color_mod.RGBA8;
const filament_mod = @import("filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const Filament = filament_mod.Filament;

pub const OpticalConfig = struct {
    min_z: f32 = 0.80, // Base layer thickness in mm
    max_z: f32 = 4.00, // Total model height in mm
    first_layer_height: f32 = 0.16,
    layer_height: f32 = 0.08,
    quantize_layers: bool = true,
    max_active_layer: u32 = 999999, // Layer scrubber
    max_layer_limit: u32 = 0, // 0 = all layers, >0 = limit to layer N

    pub fn getLayerCount(self: *const OpticalConfig) u32 {
        if (self.max_z <= self.first_layer_height) return 1;
        const remaining = self.max_z - self.first_layer_height;
        const extra = @as(u32, @intFromFloat(@ceil(remaining / self.layer_height)));
        return 1 + extra;
    }

    pub fn getLayerZ(self: *const OpticalConfig, layer_num: u32) f32 {
        if (layer_num == 0) return self.max_z;
        if (layer_num == 1) return self.first_layer_height;
        return self.first_layer_height + @as(f32, @floatFromInt(layer_num - 1)) * self.layer_height;
    }
};

pub fn quantizeZ(z: f32, first_layer: f32, step: f32) f32 {
    if (z <= first_layer) return first_layer;
    const extra = z - first_layer;
    const steps = @round(extra / step);
    return first_layer + steps * step;
}

/// Computes the exact Beer-Lambert transmitted RGB color for a given height Z
pub fn evaluateOpticalColor(z: f32, stack: *const FilamentStack) RGB {
    if (stack.count == 0) return RGB.init(0, 0, 0);

    // Filament 0 is the opaque base layer
    const base_fil = &stack.items[0];
    var accum_linear = base_fil.linearColor();

    if (stack.count == 1 or z <= base_fil.end_z) {
        return accum_linear.toSRGB();
    }

    // Stack translucent layers over the base
    for (1..stack.count) |i| {
        const fil = &stack.items[i];
        if (z <= fil.start_z) break;

        const effective_top = @min(z, fil.end_z);
        const thickness = @max(0.0, effective_top - fil.start_z);
        if (thickness > 0.0001) {
            const fil_linear = fil.linearColor();
            accum_linear = color_mod.blendBeerLambert(accum_linear, fil_linear, thickness, fil.td_mm);
        }
    }

    return accum_linear.toSRGB();
}

/// Renders the full 2D optical transmission buffer
pub fn renderOpticalBuffer(
    luminance: []const f32,
    width: u32,
    height: u32,
    stack: *const FilamentStack,
    config: OpticalConfig,
    out_rgba: []u8,
) void {
    const pixel_count = @as(usize, width) * @as(usize, height);
    if (luminance.len < pixel_count or out_rgba.len < pixel_count * 4) return;

    const z_range = config.max_z - config.min_z;
    const max_scrub_z = if (config.max_layer_limit > 0) config.getLayerZ(config.max_layer_limit) else config.max_z;

    for (0..pixel_count) |i| {
        const lum = luminance[i];
        var z = config.min_z + lum * z_range;

        // Quantize to discrete slicer layer heights if enabled
        if (config.quantize_layers) {
            z = quantizeZ(z, config.first_layer_height, config.layer_height);
        }

        z = @min(z, max_scrub_z);

        const srgb = evaluateOpticalColor(z, stack);
        const rgb8 = srgb.toRGB8();

        const out_idx = i * 4;
        out_rgba[out_idx + 0] = rgb8.r;
        out_rgba[out_idx + 1] = rgb8.g;
        out_rgba[out_idx + 2] = rgb8.b;
        out_rgba[out_idx + 3] = 255;
    }
}

test "evaluate optical color" {
    const stack = FilamentStack.initDefault();
    const c0 = evaluateOpticalColor(0.2, &stack);
    const c1 = evaluateOpticalColor(1.0, &stack);
    const c2 = evaluateOpticalColor(2.2, &stack);

    try std.testing.expect(c0.r >= 0.0 and c0.r <= 1.0);
    try std.testing.expect(c1.r >= 0.0 and c1.r <= 1.0);
    try std.testing.expect(c2.r >= 0.0 and c2.r <= 1.0);
}
