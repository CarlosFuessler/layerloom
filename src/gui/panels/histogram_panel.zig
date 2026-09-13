const std = @import("std");
const c = @import("../../c.zig").c;
const image_mod = @import("../../core/image.zig");
const Image = image_mod.Image;
const filament_mod = @import("../../core/filament.zig");
const FilamentStack = filament_mod.FilamentStack;

pub fn renderHistogramPanel(
    img: *const Image,
    stack: *const FilamentStack,
    min_z: f32,
    max_z: f32,
) void {
    _ = c.igTextColored(c.ImVec4{ .x = 0.4, .y = 0.8, .z = 1.0, .w = 1.0 }, "TONAL HISTOGRAM & LAYER BOUNDARIES");
    _ = c.igSeparator();

    if (img.luminance.len == 0) {
        _ = c.igTextDisabled("No image data loaded.", "");
        return;
    }

    var bins: [256]u32 = undefined;
    img.computeHistogram(&bins);

    var max_val: f32 = 1.0;
    var float_bins: [256]f32 = undefined;
    for (0..256) |i| {
        const val = @as(f32, @floatFromInt(bins[i]));
        float_bins[i] = val;
        if (val > max_val) max_val = val;
    }

    // Normalize for display
    for (0..256) |i| {
        float_bins[i] /= max_val;
    }

    // Render Histogram
    c.igPlotHistogram_FloatPtr(
        "##Histogram",
        &float_bins,
        256,
        0,
        null,
        0.0,
        1.0,
        c.ImVec2{ .x = -1.0, .y = 90.0 },
        @sizeOf(f32),
    );

    // Color swatches and height intervals below histogram
    _ = c.igSpacing();
    _ = c.igTextUnformatted("Layer Range Distribution:", null);

    const span = max_z - min_z;
    if (span > 0.001) {
        for (0..stack.count) |i| {
            const fil = &stack.items[i];
            const start_pct = std.math.clamp((fil.start_z - min_z) / span, 0.0, 1.0) * 100.0;
            const end_pct = std.math.clamp((fil.end_z - min_z) / span, 0.0, 1.0) * 100.0;

            const col_vec = c.ImVec4{ .x = fil.color.r, .y = fil.color.g, .z = fil.color.b, .w = 1.0 };
            _ = c.igColorButton("##FilColor", col_vec, c.ImGuiColorEditFlags_NoTooltip, c.ImVec2{ .x = 16, .y = 16 });
            c.igSameLine(0, 6);
            c.igText("%s: %.2fmm - %.2fmm (%.0f%% - %.0f%%)", fil.getName().ptr, fil.start_z, fil.end_z, start_pct, end_pct);
        }
    }
}
