const std = @import("std");
const c = @import("../../c.zig").c;
const renderer_mod = @import("../../render/renderer.zig");
const Renderer = renderer_mod.Renderer;
const camera_mod = @import("../../render/camera.zig");
const Camera = camera_mod.Camera;
const optical_mod = @import("../../core/optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;

pub const ViewportState = struct {
    mode_3d: bool = true,
    scrub_layer: u32 = 0, // 0 = all layers
    max_layers: u32 = 30,
    is_viewport_hovered: bool = false,
    viewport_width: i32 = 800,
    viewport_height: i32 = 600,
};

pub fn renderViewportPanel(
    state: *ViewportState,
    renderer: *Renderer,
    camera: *Camera,
    opt_config: *OpticalConfig,
    img_dirty: *bool,
) void {
    // 1. Top Viewport Toolbar
    const was_3d = state.mode_3d;
    if (was_3d) {
        c.igPushStyleColor_Vec4(c.ImGuiCol_Button, c.ImVec4{ .x = 0.20, .y = 0.50, .z = 0.90, .w = 1.0 });
    }
    if (c.igButton(" 🧊 3D Relief View ", c.ImVec2{ .x = 130, .y = 26 })) {
        state.mode_3d = true;
    }
    if (was_3d) {
        c.igPopStyleColor(1);
    }

    c.igSameLine(0, 6);
    const was_2d = !state.mode_3d;
    if (was_2d) {
        c.igPushStyleColor_Vec4(c.ImGuiCol_Button, c.ImVec4{ .x = 0.20, .y = 0.50, .z = 0.90, .w = 1.0 });
    }
    if (c.igButton(" 🌈 2D Optical Preview ", c.ImVec2{ .x = 155, .y = 26 })) {
        state.mode_3d = false;
    }
    if (was_2d) {
        c.igPopStyleColor(1);
    }

    if (state.mode_3d) {
        c.igSameLine(0, 16);
        _ = c.igCheckbox("Grid", &renderer.show_grid);
        c.igSameLine(0, 8);
        _ = c.igCheckbox("Wireframe", &renderer.wireframe);

        c.igSameLine(0, 16);
        _ = c.igTextDisabled("View:", "");
        c.igSameLine(0, 4);
        if (c.igButton("Iso", c.ImVec2{ .x = 36, .y = 22 })) camera.resetIsometric();
        c.igSameLine(0, 4);
        if (c.igButton("Top", c.ImVec2{ .x = 36, .y = 22 })) camera.resetTop();
        c.igSameLine(0, 4);
        if (c.igButton("Front", c.ImVec2{ .x = 42, .y = 22 })) camera.resetFront();
        c.igSameLine(0, 4);
        if (c.igButton("Reset", c.ImVec2{ .x = 46, .y = 22 })) camera.resetIsometric();
    }

    _ = c.igSpacing();

    // 2. Render FBO Texture inside ImGui
    const avail = c.igGetContentRegionAvail();

    const vp_w = @as(i32, @intFromFloat(@max(64.0, avail.x)));
    const vp_h = @as(i32, @intFromFloat(@max(64.0, avail.y - 42.0))); // reserve room for bottom scrubber

    state.viewport_width = vp_w;
    state.viewport_height = vp_h;

    // Render Scene into FBO
    if (state.mode_3d) {
        renderer.render3DToFBO(vp_w, vp_h, camera);
    } else {
        renderer.render2DToFBO(vp_w, vp_h);
    }

    // Display FBO Texture via ImGui
    const tex_ref = c.ImTextureRef_c{
        ._TexData = null,
        ._TexID = @as(c.ImTextureID, @intCast(renderer.fbo.color_texture)),
    };
    c.igImage(
        tex_ref,
        c.ImVec2{ .x = @floatFromInt(vp_w), .y = @floatFromInt(vp_h) },
        c.ImVec2{ .x = 0, .y = 1 },
        c.ImVec2{ .x = 1, .y = 0 },
    );

    // Track if user is hovering the viewport
    state.is_viewport_hovered = c.igIsItemHovered(0);

    // 3. Bottom Layer Scrubber Bar
    _ = c.igSpacing();

    const total_layers = opt_config.getLayerCount();
    state.max_layers = @max(1, total_layers);

    if (c.igButton(" ◀ ", c.ImVec2{ .x = 30, .y = 22 })) {
        if (state.scrub_layer > 0) {
            state.scrub_layer -= 1;
            opt_config.max_layer_limit = state.scrub_layer;
            img_dirty.* = true;
        }
    }
    c.igSameLine(0, 4);
    if (c.igButton(" ▶ ", c.ImVec2{ .x = 30, .y = 22 })) {
        if (state.scrub_layer < state.max_layers) {
            state.scrub_layer += 1;
            opt_config.max_layer_limit = state.scrub_layer;
            img_dirty.* = true;
        }
    }
    c.igSameLine(0, 8);

    var scrub_i32: c_int = @intCast(state.scrub_layer);
    c.igSetNextItemWidth(-120);

    var label_buf: [64]u8 = undefined;
    const cur_z = if (state.scrub_layer == 0) opt_config.max_z else opt_config.getLayerZ(state.scrub_layer);
    const scrub_label = std.fmt.bufPrintZ(&label_buf, "Layer {d} / {d} (Z = {d:.2} mm)", .{
        state.scrub_layer,
        state.max_layers,
        cur_z,
    }) catch "Layer";

    if (c.igSliderInt("##Scrubber", &scrub_i32, 0, @intCast(state.max_layers), scrub_label, 0)) {
        state.scrub_layer = @as(u32, @intCast(scrub_i32));
        opt_config.max_layer_limit = state.scrub_layer;
        img_dirty.* = true;
    }

    c.igSameLine(0, 8);
    if (c.igButton("All Layers", c.ImVec2{ .x = 100, .y = 22 })) {
        state.scrub_layer = 0;
        opt_config.max_layer_limit = 0;
        img_dirty.* = true;
    }
}
