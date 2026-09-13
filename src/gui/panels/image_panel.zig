const std = @import("std");
const c = @import("../../c.zig").c;
const image_mod = @import("../../core/image.zig");
const Image = image_mod.Image;
const ImageAdjustments = image_mod.ImageAdjustments;
const optical_mod = @import("../../core/optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;

pub const PrintDimensions = struct {
    width_mm: f32 = 150.0,
    height_mm: f32 = 150.0,
    lock_aspect: bool = true,
    mesh_resolution: u32 = 200, // 200x200 grid
};

pub fn renderImagePanel(
    img: *Image,
    adj: *ImageAdjustments,
    print_dim: *PrintDimensions,
    opt_config: *OpticalConfig,
    file_path_buf: *[512]u8,
    img_dirty: *bool,
    mesh_dirty: *bool,
    request_browse_fn: ?*const fn () void,
    allocator: std.mem.Allocator,
) void {
    _ = c.igTextColored(c.ImVec4{ .x = 0.35, .y = 0.75, .z = 1.0, .w = 1.0 }, "SOURCE IMAGE & DIMENSIONS");
    _ = c.igSeparator();
    _ = c.igSpacing();

    // 1. Native File Dialog & Dropzone Box
    if (c.igButton("  📂  Choose Image File...  ", c.ImVec2{ .x = -1.0, .y = 36 })) {
        if (request_browse_fn) |browse| {
            browse();
        }
    }

    c.igTextDisabled("Tip: Drag & drop any PNG/JPG/WebP onto the window!", "");
    _ = c.igSpacing();

    // Manual path entry fallback
    _ = c.igTextUnformatted("Or Paste File Path:", null);
    c.igSetNextItemWidth(-70);
    _ = c.igInputText("##ImagePath", file_path_buf, file_path_buf.len, 0, null, null);
    c.igSameLine(0, 6);

    if (c.igButton("Load", c.ImVec2{ .x = 60, .y = 22 })) {
        const path_len = std.mem.indexOfScalar(u8, file_path_buf, 0) orelse file_path_buf.len;
        if (path_len > 0) {
            const path_slice = file_path_buf[0..path_len];
            if (Image.loadFromFile(allocator, path_slice)) |new_img| {
                img.deinit();
                img.* = new_img;
                img.recomputeLuminance(adj.*);
                if (print_dim.lock_aspect and img.width > 0 and img.height > 0) {
                    const aspect = @as(f32, @floatFromInt(img.height)) / @as(f32, @floatFromInt(img.width));
                    print_dim.height_mm = print_dim.width_mm * aspect;
                }
                img_dirty.* = true;
                mesh_dirty.* = true;
            } else |_| {
                std.debug.print("Failed to open image: {s}\n", .{path_slice});
            }
        }
    }

    if (c.igButton("🌸 Procedural Test Pattern", c.ImVec2{ .x = -1.0, .y = 24 })) {
        if (Image.createDefaultPattern(allocator, 256, 256)) |new_img| {
            img.deinit();
            img.* = new_img;
            img.recomputeLuminance(adj.*);
            img_dirty.* = true;
            mesh_dirty.* = true;
        } else |_| {}
    }

    // Image Specs Card
    if (img.width > 0 and img.height > 0) {
        _ = c.igSpacing();
        const aspect = @as(f32, @floatFromInt(img.width)) / @as(f32, @floatFromInt(img.height));
        _ = c.igTextColored(c.ImVec4{ .x = 0.3, .y = 0.9, .z = 0.6, .w = 1.0 }, "✔ Active Image: %u x %u px (Aspect %.2f:1)", img.width, img.height, aspect);
    }

    _ = c.igSpacing();
    _ = c.igSeparator();
    _ = c.igSpacing();
    _ = c.igTextColored(c.ImVec4{ .x = 0.95, .y = 0.75, .z = 0.25, .w = 1.0 }, "Tonal Curve & Remapping");

    // 2. Adjustments sliders
    if (c.igSliderFloat("Brightness", &adj.brightness, -1.0, 1.0, "%.2f", 0)) {
        img.recomputeLuminance(adj.*);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("Contrast", &adj.contrast, 0.0, 3.0, "%.2f", 0)) {
        img.recomputeLuminance(adj.*);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("Gamma", &adj.gamma, 0.1, 3.0, "%.2f", 0)) {
        img.recomputeLuminance(adj.*);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igCheckbox("Invert Tones (Dark <-> Light)", &adj.invert)) {
        img.recomputeLuminance(adj.*);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("Black Point", &adj.black_point, 0.0, 0.95, "%.2f", 0)) {
        adj.black_point = @min(adj.black_point, adj.white_point - 0.01);
        img.recomputeLuminance(adj.*);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("White Point", &adj.white_point, 0.05, 1.0, "%.2f", 0)) {
        adj.white_point = @max(adj.black_point + 0.01, adj.white_point);
        img.recomputeLuminance(adj.*);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    _ = c.igSpacing();
    _ = c.igSeparator();
    _ = c.igSpacing();
    _ = c.igTextColored(c.ImVec4{ .x = 0.95, .y = 0.75, .z = 0.25, .w = 1.0 }, "3D Print Dimensions & Slicing");

    // Size presets
    if (c.igButton("100mm", c.ImVec2{ .x = 65, .y = 20 })) {
        print_dim.width_mm = 100.0;
        if (print_dim.lock_aspect and img.width > 0 and img.height > 0) {
            print_dim.height_mm = 100.0 * (@as(f32, @floatFromInt(img.height)) / @as(f32, @floatFromInt(img.width)));
        } else {
            print_dim.height_mm = 100.0;
        }
        mesh_dirty.* = true;
    }
    c.igSameLine(0, 6);
    if (c.igButton("150mm", c.ImVec2{ .x = 65, .y = 20 })) {
        print_dim.width_mm = 150.0;
        if (print_dim.lock_aspect and img.width > 0 and img.height > 0) {
            print_dim.height_mm = 150.0 * (@as(f32, @floatFromInt(img.height)) / @as(f32, @floatFromInt(img.width)));
        } else {
            print_dim.height_mm = 150.0;
        }
        mesh_dirty.* = true;
    }
    c.igSameLine(0, 6);
    if (c.igButton("200mm", c.ImVec2{ .x = 65, .y = 20 })) {
        print_dim.width_mm = 200.0;
        if (print_dim.lock_aspect and img.width > 0 and img.height > 0) {
            print_dim.height_mm = 200.0 * (@as(f32, @floatFromInt(img.height)) / @as(f32, @floatFromInt(img.width)));
        } else {
            print_dim.height_mm = 200.0;
        }
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("Width (mm)", &print_dim.width_mm, 20.0, 400.0, "%.1f mm", 0)) {
        if (print_dim.lock_aspect and img.width > 0 and img.height > 0) {
            const aspect = @as(f32, @floatFromInt(img.height)) / @as(f32, @floatFromInt(img.width));
            print_dim.height_mm = print_dim.width_mm * aspect;
        }
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("Length (mm)", &print_dim.height_mm, 20.0, 400.0, "%.1f mm", 0)) {
        if (print_dim.lock_aspect and img.width > 0 and img.height > 0) {
            const aspect = @as(f32, @floatFromInt(img.width)) / @as(f32, @floatFromInt(img.height));
            print_dim.width_mm = print_dim.height_mm * aspect;
        }
        mesh_dirty.* = true;
    }

    _ = c.igCheckbox("Lock Aspect Ratio", &print_dim.lock_aspect);

    if (c.igSliderFloat("Base Thickness (mm)", &opt_config.min_z, 0.16, 2.0, "%.2f mm", 0)) {
        opt_config.min_z = @min(opt_config.min_z, opt_config.max_z - 0.2);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("Max Height (mm)", &opt_config.max_z, 0.40, 5.0, "%.2f mm", 0)) {
        opt_config.max_z = @max(opt_config.min_z + 0.2, opt_config.max_z);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("First Layer Height", &opt_config.first_layer_height, 0.10, 0.30, "%.2f mm", 0)) {
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    // Layer height presets
    _ = c.igTextUnformatted("Layer Step Height Preset:", null);
    if (c.igButton("0.04mm (Ultra)", c.ImVec2{ .x = 100, .y = 20 })) {
        opt_config.layer_height = 0.04;
        img_dirty.* = true;
        mesh_dirty.* = true;
    }
    c.igSameLine(0, 6);
    if (c.igButton("0.08mm (High)", c.ImVec2{ .x = 100, .y = 20 })) {
        opt_config.layer_height = 0.08;
        img_dirty.* = true;
        mesh_dirty.* = true;
    }
    c.igSameLine(0, 6);
    if (c.igButton("0.12mm (Std)", c.ImVec2{ .x = 90, .y = 20 })) {
        opt_config.layer_height = 0.12;
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igSliderFloat("Layer Step Height", &opt_config.layer_height, 0.02, 0.20, "%.2f mm", 0)) {
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    if (c.igCheckbox("Quantize Z to Slice Heights", &opt_config.quantize_layers)) {
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    var res_i32: c_int = @intCast(print_dim.mesh_resolution);
    if (c.igSliderInt("Mesh Grid Density", &res_i32, 50, 400, "%d x %d", 0)) {
        print_dim.mesh_resolution = @as(u32, @intCast(res_i32));
        mesh_dirty.* = true;
    }
}
