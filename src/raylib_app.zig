const std = @import("std");
const math = std.math;
const c = @import("c.zig").c;
const ray = @import("c.zig").ray;

const color_mod = @import("core/color.zig");
const RGB = color_mod.RGB;
const filament_mod = @import("core/filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const Filament = filament_mod.Filament;
const LayerSwapInfo = filament_mod.LayerSwapInfo;
const image_mod = @import("core/image.zig");
const Image = image_mod.Image;
const ImageAdjustments = image_mod.ImageAdjustments;
const optical_mod = @import("core/optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;
const heightfield = @import("core/heightfield.zig");
const HeightfieldMesh = heightfield.HeightfieldMesh;
const Vec3 = heightfield.Vec3;

const stl = @import("export/stl.zig");
const threemf = @import("export/threemf.zig");

pub const RaylibApp = struct {
    allocator: std.mem.Allocator,
    running: bool = true,

    // Core Data
    image: Image,
    adjustments: ImageAdjustments = .{},
    filament_stack: FilamentStack,
    optical_config: OpticalConfig = .{},
    mesh: HeightfieldMesh,

    // Print Dimensions
    width_mm: f32 = 150.0,
    height_mm: f32 = 150.0,
    lock_aspect: bool = true,
    mesh_resolution: u32 = 150,

    // 3D Camera & Orbit
    camera: ray.Camera3D = undefined,
    cam_yaw: f32 = 0.785398, // 45 deg
    cam_pitch: f32 = 0.610865, // 35 deg
    cam_dist: f32 = 260.0,
    cam_target: ray.Vector3 = .{ .x = 0, .y = 0, .z = 0 },

    // Raylib 3D Model & 2D Texture
    ray_mesh: ray.Mesh = std.mem.zeroes(ray.Mesh),
    ray_model: ?ray.Model = null,
    opt_texture: ?ray.Texture2D = null,
    opt_rgba_buffer: []u8 = &.{},

    // UI state
    mode_3d: bool = true,
    show_grid: bool = true,
    wireframe: bool = false,
    scrub_layer: u32 = 0, // 0 = all layers
    max_layers: u32 = 30,
    active_tab: usize = 0, // 0 = Palette, 1 = Image & Dimensions

    img_dirty: bool = true,
    mesh_dirty: bool = true,
    status_msg: [128]u8 = [_]u8{0} ** 128,
    status_timer: f32 = 0.0,

    // Mouse tracking for 3D orbit
    mouse_dragging: bool = false,
    mouse_panning: bool = false,
    prev_mouse_pos: ray.Vector2 = .{ .x = 0, .y = 0 },

    pub fn init(allocator: std.mem.Allocator) !*RaylibApp {
        ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE | ray.FLAG_MSAA_4X_HINT);
        ray.InitWindow(1440, 900, "2MF — 3D Filament Painting Studio (Raylib Native)");
        ray.SetTargetFPS(60);

        const app = try allocator.create(RaylibApp);

        const default_img = try Image.createDefaultPattern(allocator, 256, 256);
        const stack = FilamentStack.initDefault();

        app.* = .{
            .allocator = allocator,
            .image = default_img,
            .filament_stack = stack,
            .mesh = HeightfieldMesh.initEmpty(allocator),
        };

        app.optical_config.min_z = 0.40;
        app.optical_config.max_z = 2.40;
        app.optical_config.first_layer_height = 0.16;
        app.optical_config.layer_height = 0.08;
        app.filament_stack.autoDistribute(app.optical_config.min_z, app.optical_config.max_z);

        app.updateCameraPosition();
        return app;
    }

    pub fn deinit(self: *RaylibApp) void {
        if (self.ray_model) |m| {
            ray.UnloadModel(m);
            self.ray_model = null;
        }
        if (self.opt_texture) |t| {
            ray.UnloadTexture(t);
            self.opt_texture = null;
        }
        if (self.opt_rgba_buffer.len > 0) {
            self.allocator.free(self.opt_rgba_buffer);
        }
        self.mesh.deinit();
        self.image.deinit();

        ray.CloseWindow();
        self.allocator.destroy(self);
    }

    pub fn run(self: *RaylibApp) !void {
        while (!ray.WindowShouldClose() and self.running) {
            self.update();
            self.draw();
        }
    }

    fn updateCameraPosition(self: *RaylibApp) void {
        const cos_p = @cos(self.cam_pitch);
        const sin_p = @sin(self.cam_pitch);
        const cos_y = @cos(self.cam_yaw);
        const sin_y = @sin(self.cam_yaw);

        self.camera.position = .{
            .x = self.cam_target.x + self.cam_dist * cos_p * sin_y,
            .y = self.cam_target.y + self.cam_dist * sin_p,
            .z = self.cam_target.z + self.cam_dist * cos_p * cos_y,
        };
        self.camera.target = self.cam_target;
        self.camera.up = .{ .x = 0, .y = 1, .z = 0 };
        self.camera.fovy = 45.0;
        self.camera.projection = ray.CAMERA_PERSPECTIVE;
    }

    fn update(self: *RaylibApp) void {
        const dt = ray.GetFrameTime();
        if (self.status_timer > 0.0) {
            self.status_timer -= dt;
        }

        // 1. Handle Drag & Drop Files from OS Finder
        if (ray.IsFileDropped()) {
            const dropped = ray.LoadDroppedFiles();
            defer ray.UnloadDroppedFiles(dropped);
            if (dropped.count > 0 and dropped.paths != null) {
                const path_c = dropped.paths[0];
                if (path_c != null) {
                    const span = std.mem.span(path_c);
                    self.loadImageFromPath(span);
                }
            }
        }

        // 2. Handle 3D Viewport Mouse Orbit & Pan
        const mouse_pos = ray.GetMousePosition();
        const mouse_dx = mouse_pos.x - self.prev_mouse_pos.x;
        const mouse_dy = mouse_pos.y - self.prev_mouse_pos.y;
        self.prev_mouse_pos = mouse_pos;

        const screen_w = @as(f32, @floatFromInt(ray.GetScreenWidth()));
        const screen_h = @as(f32, @floatFromInt(ray.GetScreenHeight()));
        const in_viewport = (mouse_pos.x >= 380.0 and mouse_pos.x <= screen_w - 360.0 and mouse_pos.y >= 50.0 and mouse_pos.y <= screen_h - 50.0);

        if (in_viewport) {
            if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
                self.mouse_dragging = true;
            }
            if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_RIGHT) or ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_MIDDLE)) {
                self.mouse_panning = true;
            }

            const wheel = ray.GetMouseWheelMove();
            if (wheel != 0.0) {
                self.cam_dist -= wheel * (self.cam_dist * 0.08);
                self.cam_dist = math.clamp(self.cam_dist, 20.0, 3000.0);
                self.updateCameraPosition();
            }
        }

        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_LEFT)) {
            self.mouse_dragging = false;
        }
        if (ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_RIGHT) or ray.IsMouseButtonReleased(ray.MOUSE_BUTTON_MIDDLE)) {
            self.mouse_panning = false;
        }

        if (self.mouse_dragging) {
            self.cam_yaw += mouse_dx * 0.008;
            self.cam_pitch += mouse_dy * 0.008;
            self.cam_pitch = math.clamp(self.cam_pitch, -math.pi * 0.48, math.pi * 0.48);
            self.updateCameraPosition();
        } else if (self.mouse_panning) {
            const pan_scale = self.cam_dist * 0.0015;
            const cos_y = @cos(self.cam_yaw);
            const sin_y = @sin(self.cam_yaw);
            self.cam_target.x -= (cos_y * mouse_dx) * pan_scale;
            self.cam_target.z += (sin_y * mouse_dx) * pan_scale;
            self.cam_target.y += mouse_dy * pan_scale;
            self.updateCameraPosition();
        }

        // 3. Recompute Optical Preview Texture if dirty
        const pixel_count = @as(usize, self.image.width) * @as(usize, self.image.height);
        if (self.opt_rgba_buffer.len != pixel_count * 4 and pixel_count > 0) {
            if (self.opt_rgba_buffer.len > 0) self.allocator.free(self.opt_rgba_buffer);
            self.opt_rgba_buffer = self.allocator.alloc(u8, pixel_count * 4) catch &.{};
            self.img_dirty = true;
        }

        if (self.img_dirty and pixel_count > 0 and self.opt_rgba_buffer.len == pixel_count * 4) {
            optical_mod.renderOpticalBuffer(
                self.image.luminance,
                self.image.width,
                self.image.height,
                &self.filament_stack,
                self.optical_config,
                self.opt_rgba_buffer,
            );

            // Create or update Raylib Texture
            const ray_img = ray.Image{
                .data = self.opt_rgba_buffer.ptr,
                .width = @as(c_int, @intCast(self.image.width)),
                .height = @as(c_int, @intCast(self.image.height)),
                .mipmaps = 1,
                .format = ray.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
            };

            if (self.opt_texture) |t| {
                if (t.width == ray_img.width and t.height == ray_img.height) {
                    ray.UpdateTexture(t, self.opt_rgba_buffer.ptr);
                } else {
                    ray.UnloadTexture(t);
                    self.opt_texture = ray.LoadTextureFromImage(ray_img);
                }
            } else {
                self.opt_texture = ray.LoadTextureFromImage(ray_img);
            }
            self.img_dirty = false;
        }

        // 4. Regenerate 3D Raylib Model if dirty
        if (self.mesh_dirty and self.image.luminance.len > 0) {
            const grid_res = self.mesh_resolution;
            self.mesh.generate(
                self.image.luminance,
                self.image.width,
                self.image.height,
                grid_res,
                grid_res,
                self.width_mm,
                self.height_mm,
                &self.filament_stack,
                self.optical_config,
            ) catch {};

            self.uploadRaylibMesh();
            self.mesh_dirty = false;
        }

        self.max_layers = @max(1, self.optical_config.getLayerCount());
    }

    fn uploadRaylibMesh(self: *RaylibApp) void {
        if (self.ray_model) |m| {
            ray.UnloadModel(m);
            self.ray_model = null;
        }

        if (self.mesh.vertices.len == 0 or self.mesh.indices.len == 0) return;

        const v_count = self.mesh.vertices.len;
        const tri_count = self.mesh.indices.len / 3;

        // Allocate flat buffers for Raylib mesh
        const verts = self.allocator.alloc(f32, v_count * 3) catch return;
        defer self.allocator.free(verts);

        const norms = self.allocator.alloc(f32, v_count * 3) catch return;
        defer self.allocator.free(norms);

        const colors = self.allocator.alloc(u8, v_count * 4) catch return;
        defer self.allocator.free(colors);

        const indices = self.allocator.alloc(c_ushort, self.mesh.indices.len) catch return;
        defer self.allocator.free(indices);

        for (self.mesh.vertices, 0..) |v, i| {
            // Convert to Raylib coordinates (Y is up, Z is depth)
            verts[i * 3 + 0] = v.pos.x;
            verts[i * 3 + 1] = v.pos.z; // Z becomes Up in Raylib
            verts[i * 3 + 2] = -v.pos.y; // Y becomes -Z in Raylib

            norms[i * 3 + 0] = v.normal.x;
            norms[i * 3 + 1] = v.normal.z;
            norms[i * 3 + 2] = -v.normal.y;

            colors[i * 4 + 0] = @as(u8, @intFromFloat(math.clamp(v.color[0] * 255.0, 0, 255)));
            colors[i * 4 + 1] = @as(u8, @intFromFloat(math.clamp(v.color[1] * 255.0, 0, 255)));
            colors[i * 4 + 2] = @as(u8, @intFromFloat(math.clamp(v.color[2] * 255.0, 0, 255)));
            colors[i * 4 + 3] = 255;
        }

        for (self.mesh.indices, 0..) |idx, i| {
            indices[i] = @as(c_ushort, @intCast(idx));
        }

        var r_mesh = std.mem.zeroes(ray.Mesh);
        r_mesh.vertexCount = @as(c_int, @intCast(v_count));
        r_mesh.triangleCount = @as(c_int, @intCast(tri_count));
        r_mesh.vertices = verts.ptr;
        r_mesh.normals = norms.ptr;
        r_mesh.colors = colors.ptr;
        r_mesh.indices = indices.ptr;

        ray.UploadMesh(&r_mesh, false);
        self.ray_model = ray.LoadModelFromMesh(r_mesh);
    }

    pub fn loadImageFromPath(self: *RaylibApp, path: []const u8) void {
        if (Image.loadFromFile(self.allocator, path)) |new_img| {
            self.image.deinit();
            self.image = new_img;
            self.image.recomputeLuminance(self.adjustments);

            if (self.lock_aspect and self.image.width > 0 and self.image.height > 0) {
                const aspect = @as(f32, @floatFromInt(self.image.height)) / @as(f32, @floatFromInt(self.image.width));
                self.height_mm = self.width_mm * aspect;
            }

            self.img_dirty = true;
            self.mesh_dirty = true;
            self.setStatus("Loaded image successfully!");
        } else |err| {
            std.debug.print("Failed to load image: {s}\n", .{@errorName(err)});
            self.setStatus("Failed to load image file.");
        }
    }

    pub fn setStatus(self: *RaylibApp, msg: []const u8) void {
        const copy_len = @min(msg.len, self.status_msg.len - 1);
        @memcpy(self.status_msg[0..copy_len], msg[0..copy_len]);
        self.status_msg[copy_len] = 0;
        self.status_timer = 5.0;
    }

    fn draw(self: *RaylibApp) void {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.GetColor(0x0e1015ff));

        const screen_w = @as(f32, @floatFromInt(ray.GetScreenWidth()));
        const screen_h = @as(f32, @floatFromInt(ray.GetScreenHeight()));

        // 1. Draw Central 3D or 2D Viewport
        const vp_x: f32 = 380.0;
        const vp_y: f32 = 50.0;
        const vp_w = screen_w - 380.0 - 360.0;
        const vp_h = screen_h - 50.0 - 55.0;

        // Viewport background
        ray.DrawRectangleRec(.{ .x = vp_x, .y = vp_y, .width = vp_w, .height = vp_h }, ray.GetColor(0x13151bff));
        ray.DrawRectangleLinesEx(.{ .x = vp_x, .y = vp_y, .width = vp_w, .height = vp_h }, 1.0, ray.GetColor(0x282c37ff));

        if (self.mode_3d) {
            // Set Scissor for 3D Viewport
            ray.BeginScissorMode(@as(c_int, @intFromFloat(vp_x)), @as(c_int, @intFromFloat(vp_y)), @as(c_int, @intFromFloat(vp_w)), @as(c_int, @intFromFloat(vp_h)));
            ray.BeginMode3D(self.camera);

            // Draw Build Plate Grid (256x256mm build plate)
            if (self.show_grid) {
                ray.DrawGrid(26, 10.0);
            }

            // Draw 3D Heightfield Relief Model
            if (self.ray_model) |m| {
                if (self.wireframe) {
                    ray.DrawModelWires(m, .{ .x = 0, .y = 0, .z = 0 }, 1.0, ray.WHITE);
                } else {
                    ray.DrawModel(m, .{ .x = 0, .y = 0, .z = 0 }, 1.0, ray.WHITE);
                }
            }

            ray.EndMode3D();
            ray.EndScissorMode();
        } else {
            // Draw 2D Optical Transmission Preview
            if (self.opt_texture) |tex| {
                const aspect = @as(f32, @floatFromInt(tex.width)) / @as(f32, @floatFromInt(tex.height));
                var dst_w = vp_w * 0.90;
                var dst_h = dst_w / aspect;
                if (dst_h > vp_h * 0.90) {
                    dst_h = vp_h * 0.90;
                    dst_w = dst_h * aspect;
                }
                const dst_x = vp_x + (vp_w - dst_w) * 0.5;
                const dst_y = vp_y + (vp_h - dst_h) * 0.5;

                ray.DrawTexturePro(
                    tex,
                    .{ .x = 0, .y = 0, .width = @floatFromInt(tex.width), .height = @floatFromInt(tex.height) },
                    .{ .x = dst_x, .y = dst_y, .width = dst_w, .height = dst_h },
                    .{ .x = 0, .y = 0 },
                    0.0,
                    ray.WHITE,
                );
            }
        }

        // 2. Draw Top Header Bar
        self.drawHeader(screen_w);

        // 3. Draw Left Panel (Palette & Slicing)
        self.drawLeftPanel(screen_h);

        // 4. Draw Right Panel (Histogram & Export)
        self.drawRightPanel(screen_w, screen_h);

        // 5. Draw Viewport Floating Controls & Bottom Layer Scrubber
        self.drawViewportControls(vp_x, vp_y, vp_w, vp_h);

        // 6. Draw Toast Status Message
        if (self.status_timer > 0.0) {
            const msg_span = std.mem.sliceTo(&self.status_msg, 0);
            const text_w = ray.MeasureText(msg_span.ptr, 18);
            const toast_x = vp_x + (vp_w - @as(f32, @floatFromInt(text_w))) * 0.5 - 20.0;
            const toast_y = vp_y + vp_h - 70.0;

            ray.DrawRectangleRec(.{ .x = toast_x, .y = toast_y, .width = @as(f32, @floatFromInt(text_w)) + 40.0, .height = 36.0 }, ray.GetColor(0x10b981ee));
            ray.DrawRectangleLinesEx(.{ .x = toast_x, .y = toast_y, .width = @as(f32, @floatFromInt(text_w)) + 40.0, .height = 36.0 }, 1.0, ray.WHITE);
            ray.DrawText(msg_span.ptr, @intFromFloat(toast_x + 20.0), @intFromFloat(toast_y + 9.0), 18, ray.WHITE);
        }
    }

    fn drawHeader(self: *RaylibApp, screen_w: f32) void {
        ray.DrawRectangle(0, 0, @intFromFloat(screen_w), 48, ray.GetColor(0x161820ff));
        ray.DrawLine(0, 48, @intFromFloat(screen_w), 48, ray.GetColor(0x282c37ff));

        ray.DrawText("2MF STUDIO", 16, 14, 20, ray.GetColor(0x38bdf8ff));
        ray.DrawText("v1.0 Raylib Native", 150, 18, 14, ray.GetColor(0x94a3b8ff));

        // Quick Preset Pattern button
        if (self.drawButton(.{ .x = 320, .y = 10, .width = 150, .height = 28 }, "Procedural Pattern", 0x2563ebff)) {
            if (Image.createDefaultPattern(self.allocator, 256, 256)) |new_img| {
                self.image.deinit();
                self.image = new_img;
                self.image.recomputeLuminance(self.adjustments);
                self.img_dirty = true;
                self.mesh_dirty = true;
                self.setStatus("Generated test pattern!");
            } else |_| {}
        }

        // Quick Auto-Tune Layers button
        if (self.drawButton(.{ .x = 480, .y = 10, .width = 140, .height = 28 }, "Auto-Distribute Z", 0x475569ff)) {
            self.filament_stack.autoDistribute(self.optical_config.min_z, self.optical_config.max_z);
            self.img_dirty = true;
            self.mesh_dirty = true;
            self.setStatus("Layers distributed!");
        }

        // Quick Export 3MF button
        if (self.drawButton(.{ .x = screen_w - 350, .y = 10, .width = 160, .height = 28 }, "Quick Export .3MF", 0x10b981ff)) {
            self.export3MFFile("filament_painting.3mf");
        }
        if (self.drawButton(.{ .x = screen_w - 180, .y = 10, .width = 160, .height = 28 }, "Quick Export .STL", 0x3b82f6ff)) {
            self.exportSTLFile("relief_mesh.stl");
        }
    }

    fn drawLeftPanel(self: *RaylibApp, screen_h: f32) void {
        const panel_w: f32 = 370.0;
        const panel_h = screen_h - 52.0;

        ray.DrawRectangleRec(.{ .x = 5, .y = 50, .width = panel_w, .height = panel_h }, ray.GetColor(0x161820ff));
        ray.DrawRectangleLinesEx(.{ .x = 5, .y = 50, .width = panel_w, .height = panel_h }, 1.0, ray.GetColor(0x282c37ff));

        // Tab Bar
        const tab0_col: u32 = if (self.active_tab == 0) 0x2563ebff else 0x1e222dff;
        const tab1_col: u32 = if (self.active_tab == 1) 0x2563ebff else 0x1e222dff;

        if (self.drawButton(.{ .x = 10, .y = 55, .width = 175, .height = 26 }, "Filament Palette", tab0_col)) {
            self.active_tab = 0;
        }
        if (self.drawButton(.{ .x = 190, .y = 55, .width = 175, .height = 26 }, "Image & Dimensions", tab1_col)) {
            self.active_tab = 1;
        }

        if (self.active_tab == 0) {
            self.drawFilamentPalette(panel_w);
        } else {
            self.drawImageSettings(panel_w);
        }
    }

    fn drawFilamentPalette(self: *RaylibApp, panel_w: f32) void {
        _ = panel_w;
        var y: f32 = 90.0;

        ray.DrawText("PRESET PALETTES", 15, @intFromFloat(y), 13, ray.GetColor(0x38bdf8ff));
        y += 20.0;

        if (self.drawButton(.{ .x = 15, .y = y, .width = 105, .height = 22 }, "Bambu CMYK", 0x334155ff)) {
            self.filament_stack = FilamentStack.initDefault();
            self.filament_stack.autoDistribute(self.optical_config.min_z, self.optical_config.max_z);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 125, .y = y, .width = 105, .height = 22 }, "PolyLite 4-Col", 0x334155ff)) {
            self.filament_stack = FilamentStack{};
            _ = self.filament_stack.add(Filament.init("Black", RGB.fromHex(0x111111), 0.5, 0.0, 0.6, 1));
            _ = self.filament_stack.add(Filament.init("Blue", RGB.fromHex(0x0a4fa0), 3.0, 0.6, 1.2, 2));
            _ = self.filament_stack.add(Filament.init("Yellow", RGB.fromHex(0xf5d000), 5.5, 1.2, 1.8, 3));
            _ = self.filament_stack.add(Filament.init("White", RGB.fromHex(0xffffff), 5.0, 1.8, 2.4, 4));
            self.filament_stack.autoDistribute(self.optical_config.min_z, self.optical_config.max_z);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 235, .y = y, .width = 125, .height = 22 }, "Monochrome 5-Col", 0x334155ff)) {
            self.filament_stack = FilamentStack{};
            _ = self.filament_stack.add(Filament.init("Black", RGB.fromHex(0x050505), 0.4, 0.0, 0.5, 1));
            _ = self.filament_stack.add(Filament.init("Dark Gray", RGB.fromHex(0x333333), 1.2, 0.5, 1.0, 2));
            _ = self.filament_stack.add(Filament.init("Mid Gray", RGB.fromHex(0x777777), 2.5, 1.0, 1.5, 3));
            _ = self.filament_stack.add(Filament.init("Light Gray", RGB.fromHex(0xbbbbbb), 4.0, 1.5, 2.0, 4));
            _ = self.filament_stack.add(Filament.init("White", RGB.fromHex(0xffffff), 5.5, 2.0, 2.4, 5));
            self.filament_stack.autoDistribute(self.optical_config.min_z, self.optical_config.max_z);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }

        y += 32.0;
        ray.DrawLine(15, @intFromFloat(y), 360, @intFromFloat(y), ray.GetColor(0x282c37ff));
        y += 10.0;

        ray.DrawText("FILAMENT LAYERS", 15, @intFromFloat(y), 13, ray.GetColor(0x38bdf8ff));
        y += 20.0;

        // Draw Layer Cards
        for (0..self.filament_stack.count) |i| {
            const fil = &self.filament_stack.items[i];
            const card_h: f32 = 72.0;

            ray.DrawRectangleRec(.{ .x = 15, .y = y, .width = 345, .height = card_h }, ray.GetColor(0x1e222dff));
            ray.DrawRectangleLinesEx(.{ .x = 15, .y = y, .width = 345, .height = card_h }, 1.0, ray.GetColor(0x333a4dff));

            // Swatch
            const rgb8 = fil.color.toRGB8();
            ray.DrawCircle(@intFromFloat(32), @intFromFloat(y + 20), 10, ray.GetColor((@as(u32, rgb8.r) << 24) | (@as(u32, rgb8.g) << 16) | (@as(u32, rgb8.b) << 8) | 0xff));

            // Layer Name & Slot
            var name_buf: [64]u8 = undefined;
            const label = std.fmt.bufPrintZ(&name_buf, "#{d}: {s} (Slot {d})", .{ i + 1, fil.getName(), fil.slicer_slot }) catch "Layer";
            ray.DrawText(label.ptr, 50, @intFromFloat(y + 12), 14, ray.WHITE);

            // TD & Height Info
            var info_buf: [64]u8 = undefined;
            const info_txt = std.fmt.bufPrintZ(&info_buf, "TD: {d:.2} mm | Z: {d:.2} - {d:.2} mm", .{ fil.td_mm, fil.start_z, fil.end_z }) catch "Info";
            ray.DrawText(info_txt.ptr, 50, @intFromFloat(y + 32), 12, ray.GetColor(0x94a3b8ff));

            // Controls (+ / - TD)
            if (self.drawButton(.{ .x = 50, .y = y + 48, .width = 55, .height = 18 }, "- TD", 0x334155ff)) {
                fil.td_mm = @max(0.1, fil.td_mm - 0.5);
                self.img_dirty = true;
            }
            if (self.drawButton(.{ .x = 110, .y = y + 48, .width = 55, .height = 18 }, "+ TD", 0x334155ff)) {
                fil.td_mm = @min(15.0, fil.td_mm + 0.5);
                self.img_dirty = true;
            }

            y += card_h + 8.0;
        }

        // Add Layer button
        if (self.filament_stack.count < 16) {
            if (self.drawButton(.{ .x = 15, .y = y, .width = 345, .height = 26 }, "+ Add Layer", 0x2563ebff)) {
                _ = self.filament_stack.add(Filament.init("New Layer", RGB.init(0.9, 0.9, 0.9), 4.0, self.optical_config.min_z, self.optical_config.max_z, @as(u8, @intCast(self.filament_stack.count + 1))));
                self.filament_stack.autoDistribute(self.optical_config.min_z, self.optical_config.max_z);
                self.img_dirty = true;
                self.mesh_dirty = true;
            }
        }
    }

    fn drawImageSettings(self: *RaylibApp, panel_w: f32) void {
        _ = panel_w;
        var y: f32 = 90.0;

        ray.DrawText("TONAL ADJUSTMENTS", 15, @intFromFloat(y), 13, ray.GetColor(0x38bdf8ff));
        y += 22.0;

        // Brightness
        var b_buf: [32]u8 = undefined;
        const b_txt = std.fmt.bufPrintZ(&b_buf, "Brightness: {d:.2}", .{self.adjustments.brightness}) catch "";
        ray.DrawText(b_txt.ptr, 15, @intFromFloat(y), 13, ray.WHITE);
        if (self.drawButton(.{ .x = 220, .y = y - 3, .width = 40, .height = 20 }, "-", 0x334155ff)) {
            self.adjustments.brightness = math.clamp(self.adjustments.brightness - 0.1, -1.0, 1.0);
            self.image.recomputeLuminance(self.adjustments);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 265, .y = y - 3, .width = 40, .height = 20 }, "+", 0x334155ff)) {
            self.adjustments.brightness = math.clamp(self.adjustments.brightness + 0.1, -1.0, 1.0);
            self.image.recomputeLuminance(self.adjustments);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        y += 28.0;

        // Contrast
        var c_buf: [32]u8 = undefined;
        const c_txt = std.fmt.bufPrintZ(&c_buf, "Contrast: {d:.2}", .{self.adjustments.contrast}) catch "";
        ray.DrawText(c_txt.ptr, 15, @intFromFloat(y), 13, ray.WHITE);
        if (self.drawButton(.{ .x = 220, .y = y - 3, .width = 40, .height = 20 }, "-", 0x334155ff)) {
            self.adjustments.contrast = math.clamp(self.adjustments.contrast - 0.1, 0.1, 3.0);
            self.image.recomputeLuminance(self.adjustments);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 265, .y = y - 3, .width = 40, .height = 20 }, "+", 0x334155ff)) {
            self.adjustments.contrast = math.clamp(self.adjustments.contrast + 0.1, 0.1, 3.0);
            self.image.recomputeLuminance(self.adjustments);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        y += 28.0;

        // Gamma
        var g_buf: [32]u8 = undefined;
        const g_txt = std.fmt.bufPrintZ(&g_buf, "Gamma: {d:.2}", .{self.adjustments.gamma}) catch "";
        ray.DrawText(g_txt.ptr, 15, @intFromFloat(y), 13, ray.WHITE);
        if (self.drawButton(.{ .x = 220, .y = y - 3, .width = 40, .height = 20 }, "-", 0x334155ff)) {
            self.adjustments.gamma = math.clamp(self.adjustments.gamma - 0.1, 0.2, 3.0);
            self.image.recomputeLuminance(self.adjustments);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 265, .y = y - 3, .width = 40, .height = 20 }, "+", 0x334155ff)) {
            self.adjustments.gamma = math.clamp(self.adjustments.gamma + 0.1, 0.2, 3.0);
            self.image.recomputeLuminance(self.adjustments);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        y += 32.0;

        // Invert toggle
        const inv_col: u32 = if (self.adjustments.invert) 0x2563ebff else 0x334155ff;
        if (self.drawButton(.{ .x = 15, .y = y, .width = 180, .height = 22 }, "Invert Tones (Dark <-> Light)", inv_col)) {
            self.adjustments.invert = !self.adjustments.invert;
            self.image.recomputeLuminance(self.adjustments);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        y += 36.0;

        ray.DrawLine(15, @intFromFloat(y), 360, @intFromFloat(y), ray.GetColor(0x282c37ff));
        y += 10.0;

        ray.DrawText("3D PRINT DIMENSIONS", 15, @intFromFloat(y), 13, ray.GetColor(0x38bdf8ff));
        y += 22.0;

        // Dimension presets
        if (self.drawButton(.{ .x = 15, .y = y, .width = 75, .height = 22 }, "100 mm", 0x334155ff)) {
            self.width_mm = 100.0;
            self.height_mm = 100.0;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 95, .y = y, .width = 75, .height = 22 }, "150 mm", 0x334155ff)) {
            self.width_mm = 150.0;
            self.height_mm = 150.0;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 175, .y = y, .width = 75, .height = 22 }, "200 mm", 0x334155ff)) {
            self.width_mm = 200.0;
            self.height_mm = 200.0;
            self.mesh_dirty = true;
        }
        y += 30.0;

        var dim_buf: [64]u8 = undefined;
        const dim_txt = std.fmt.bufPrintZ(&dim_buf, "Size: {d:.1} x {d:.1} mm", .{ self.width_mm, self.height_mm }) catch "";
        ray.DrawText(dim_txt.ptr, 15, @intFromFloat(y), 13, ray.WHITE);
        y += 24.0;

        // Layer Height presets
        ray.DrawText("Layer Height Preset:", 15, @intFromFloat(y), 13, ray.GetColor(0x94a3b8ff));
        y += 20.0;
        if (self.drawButton(.{ .x = 15, .y = y, .width = 95, .height = 22 }, "0.04mm Ultra", 0x334155ff)) {
            self.optical_config.layer_height = 0.04;
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 115, .y = y, .width = 95, .height = 22 }, "0.08mm High", 0x334155ff)) {
            self.optical_config.layer_height = 0.08;
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
        if (self.drawButton(.{ .x = 215, .y = y, .width = 95, .height = 22 }, "0.12mm Std", 0x334155ff)) {
            self.optical_config.layer_height = 0.12;
            self.img_dirty = true;
            self.mesh_dirty = true;
        }
    }

    fn drawRightPanel(self: *RaylibApp, screen_w: f32, screen_h: f32) void {
        const panel_x = screen_w - 355.0;
        const panel_w: f32 = 350.0;
        const panel_h = screen_h - 52.0;

        ray.DrawRectangleRec(.{ .x = panel_x, .y = 50, .width = panel_w, .height = panel_h }, ray.GetColor(0x161820ff));
        ray.DrawRectangleLinesEx(.{ .x = panel_x, .y = 50, .width = panel_w, .height = panel_h }, 1.0, ray.GetColor(0x282c37ff));

        var y: f32 = 60.0;
        ray.DrawText("TONAL HISTOGRAM", @intFromFloat(panel_x + 10), @intFromFloat(y), 13, ray.GetColor(0x38bdf8ff));
        y += 22.0;

        // Draw 256-bin Histogram
        var bins: [256]u32 = undefined;
        self.image.computeHistogram(&bins);

        var max_bin: f32 = 1.0;
        for (bins) |b| {
            const fb = @as(f32, @floatFromInt(b));
            if (fb > max_bin) max_bin = fb;
        }

        const hist_w: f32 = panel_w - 20.0;
        const hist_h: f32 = 80.0;
        ray.DrawRectangleRec(.{ .x = panel_x + 10, .y = y, .width = hist_w, .height = hist_h }, ray.GetColor(0x0e1015ff));

        for (0..256) |i| {
            const h = (@as(f32, @floatFromInt(bins[i])) / max_bin) * hist_h;
            const bx = panel_x + 10.0 + (@as(f32, @floatFromInt(i)) / 255.0) * hist_w;
            ray.DrawLine(@intFromFloat(bx), @intFromFloat(y + hist_h), @intFromFloat(bx), @intFromFloat(y + hist_h - h), ray.GetColor(0x38bdf8aa));
        }

        // Filament swap vertical markers on histogram
        const z_range = self.optical_config.max_z - self.optical_config.min_z;
        for (0..self.filament_stack.count) |i| {
            const fil = &self.filament_stack.items[i];
            const norm_z = math.clamp((fil.end_z - self.optical_config.min_z) / z_range, 0.0, 1.0);
            const line_x = panel_x + 10.0 + norm_z * hist_w;
            const rgb8 = fil.color.toRGB8();
            ray.DrawLineEx(.{ .x = line_x, .y = y }, .{ .x = line_x, .y = y + hist_h }, 2.0, ray.GetColor((@as(u32, rgb8.r) << 24) | (@as(u32, rgb8.g) << 16) | (@as(u32, rgb8.b) << 8) | 0xff));
        }

        y += hist_h + 16.0;
        ray.DrawLine(@intFromFloat(panel_x + 10), @intFromFloat(y), @intFromFloat(panel_x + panel_w - 10), @intFromFloat(y), ray.GetColor(0x282c37ff));
        y += 10.0;

        ray.DrawText("BAMBU / ORCA SWAP SCHEDULE", @intFromFloat(panel_x + 10), @intFromFloat(y), 13, ray.GetColor(0x38bdf8ff));
        y += 22.0;

        // Slicer Swap List
        var swaps_buf: [16]LayerSwapInfo = undefined;
        const swap_count = self.filament_stack.generateLayerSwaps(
            self.optical_config.first_layer_height,
            self.optical_config.layer_height,
            &swaps_buf,
        );

        for (0..swap_count) |s_idx| {
            const s = swaps_buf[s_idx];
            var row_buf: [128]u8 = undefined;
            const row_txt = if (s_idx == 0)
                std.fmt.bufPrintZ(&row_buf, "Slot {d} ({s}): L1 - {d} (0.00 - {d:.2}mm)", .{ s.slicer_slot, s.name, s.end_layer, s.end_z }) catch ""
            else
                std.fmt.bufPrintZ(&row_buf, "Slot {d} ({s}): L{d} - {d} ({d:.2} - {d:.2}mm)", .{ s.slicer_slot, s.name, s.start_layer, s.end_layer, s.start_z, s.end_z }) catch "";

            ray.DrawText(row_txt.ptr, @intFromFloat(panel_x + 12), @intFromFloat(y), 12, ray.WHITE);
            y += 18.0;
        }

        y += 16.0;
        ray.DrawLine(@intFromFloat(panel_x + 10), @intFromFloat(y), @intFromFloat(panel_x + panel_w - 10), @intFromFloat(y), ray.GetColor(0x282c37ff));
        y += 16.0;

        // Big Export Buttons
        if (self.drawButton(.{ .x = panel_x + 10, .y = y, .width = panel_w - 20, .height = 36 }, "🚀 Export Slicer .3MF File", 0x10b981ff)) {
            self.export3MFFile("filament_painting.3mf");
        }
        y += 44.0;

        if (self.drawButton(.{ .x = panel_x + 10, .y = y, .width = panel_w - 20, .height = 32 }, "📦 Export Watertight Binary .STL", 0x2563ebff)) {
            self.exportSTLFile("relief_mesh.stl");
        }
    }

    fn drawViewportControls(self: *RaylibApp, vp_x: f32, vp_y: f32, vp_w: f32, vp_h: f32) void {
        // Top Toolbar inside viewport
        const btn_3d_col: u32 = if (self.mode_3d) 0x2563ebff else 0x1e222dff;
        const btn_2d_col: u32 = if (!self.mode_3d) 0x2563ebff else 0x1e222dff;

        if (self.drawButton(.{ .x = vp_x + 10, .y = vp_y + 10, .width = 120, .height = 24 }, "3D Relief View", btn_3d_col)) {
            self.mode_3d = true;
        }
        if (self.drawButton(.{ .x = vp_x + 135, .y = vp_y + 10, .width = 140, .height = 24 }, "2D Optical View", btn_2d_col)) {
            self.mode_3d = false;
        }

        if (self.mode_3d) {
            // Camera presets
            if (self.drawButton(.{ .x = vp_x + 290, .y = vp_y + 10, .width = 40, .height = 24 }, "Iso", 0x334155ff)) {
                self.cam_yaw = 0.785398;
                self.cam_pitch = 0.610865;
                self.cam_target = .{ .x = 0, .y = 0, .z = 0 };
                self.cam_dist = 260.0;
                self.updateCameraPosition();
            }
            if (self.drawButton(.{ .x = vp_x + 335, .y = vp_y + 10, .width = 40, .height = 24 }, "Top", 0x334155ff)) {
                self.cam_yaw = 0.0;
                self.cam_pitch = math.pi * 0.48;
                self.cam_target = .{ .x = 0, .y = 0, .z = 0 };
                self.cam_dist = 260.0;
                self.updateCameraPosition();
            }
            if (self.drawButton(.{ .x = vp_x + 380, .y = vp_y + 10, .width = 45, .height = 24 }, "Front", 0x334155ff)) {
                self.cam_yaw = 0.0;
                self.cam_pitch = 0.0;
                self.cam_target = .{ .x = 0, .y = 0, .z = 0 };
                self.cam_dist = 260.0;
                self.updateCameraPosition();
            }

            const grid_col: u32 = if (self.show_grid) 0x2563ebff else 0x334155ff;
            if (self.drawButton(.{ .x = vp_x + vp_w - 140, .y = vp_y + 10, .width = 60, .height = 24 }, "Grid", grid_col)) {
                self.show_grid = !self.show_grid;
            }
            const wire_col: u32 = if (self.wireframe) 0x2563ebff else 0x334155ff;
            if (self.drawButton(.{ .x = vp_x + vp_w - 75, .y = vp_y + 10, .width = 65, .height = 24 }, "Wire", wire_col)) {
                self.wireframe = !self.wireframe;
            }
        }

        // Bottom Layer Scrubber Bar
        const bar_y = vp_y + vp_h + 10.0;
        ray.DrawRectangleRec(.{ .x = vp_x, .y = bar_y, .width = vp_w, .height = 36.0 }, ray.GetColor(0x161820ff));
        ray.DrawRectangleLinesEx(.{ .x = vp_x, .y = bar_y, .width = vp_w, .height = 36.0 }, 1.0, ray.GetColor(0x282c37ff));

        if (self.drawButton(.{ .x = vp_x + 10, .y = bar_y + 6, .width = 30, .height = 24 }, "<", 0x334155ff)) {
            if (self.scrub_layer > 0) {
                self.scrub_layer -= 1;
                self.optical_config.max_layer_limit = self.scrub_layer;
                self.img_dirty = true;
            }
        }
        if (self.drawButton(.{ .x = vp_x + 45, .y = bar_y + 6, .width = 30, .height = 24 }, ">", 0x334155ff)) {
            if (self.scrub_layer < self.max_layers) {
                self.scrub_layer += 1;
                self.optical_config.max_layer_limit = self.scrub_layer;
                self.img_dirty = true;
            }
        }

        var scrub_buf: [64]u8 = undefined;
        const cur_z = if (self.scrub_layer == 0) self.optical_config.max_z else self.optical_config.getLayerZ(self.scrub_layer);
        const scrub_txt = std.fmt.bufPrintZ(&scrub_buf, "Scrub Layer: {d} / {d} (Z = {d:.2} mm)", .{ self.scrub_layer, self.max_layers, cur_z }) catch "";
        ray.DrawText(scrub_txt.ptr, @intFromFloat(vp_x + 90), @intFromFloat(bar_y + 11), 14, ray.WHITE);

        if (self.drawButton(.{ .x = vp_x + vp_w - 110, .y = bar_y + 6, .width = 100, .height = 24 }, "All Layers", 0x334155ff)) {
            self.scrub_layer = 0;
            self.optical_config.max_layer_limit = 0;
            self.img_dirty = true;
        }
    }

    fn drawButton(_: *RaylibApp, rect: ray.Rectangle, text: [:0]const u8, bg_hex: u32) bool {
        const mouse_pos = ray.GetMousePosition();
        const hovered = (mouse_pos.x >= rect.x and mouse_pos.x <= rect.x + rect.width and mouse_pos.y >= rect.y and mouse_pos.y <= rect.y + rect.height);
        const clicked = hovered and ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT);

        var color = ray.GetColor(bg_hex);
        if (hovered) {
            color = ray.ColorBrightness(color, 0.2);
        }

        ray.DrawRectangleRec(rect, color);
        ray.DrawRectangleLinesEx(rect, 1.0, ray.GetColor(0x3b4252ff));

        const text_w = ray.MeasureText(text.ptr, 13);
        const tx = rect.x + (rect.width - @as(f32, @floatFromInt(text_w))) * 0.5;
        const ty = rect.y + (rect.height - 13.0) * 0.5;
        ray.DrawText(text.ptr, @intFromFloat(tx), @intFromFloat(ty), 13, ray.WHITE);

        return clicked;
    }

    fn export3MFFile(self: *RaylibApp, path: []const u8) void {
        threemf.export3MF(
            self.allocator,
            &self.mesh,
            &self.filament_stack,
            .{
                .title = "2MF Filament Painting",
                .first_layer_height = self.optical_config.first_layer_height,
                .layer_height = self.optical_config.layer_height,
            },
            path,
        ) catch |err| {
            std.debug.print("3MF Export error: {s}\n", .{@errorName(err)});
            self.setStatus("3MF Export Failed.");
            return;
        };
        self.setStatus("Exported 3MF successfully!");
    }

    fn exportSTLFile(self: *RaylibApp, path: []const u8) void {
        stl.exportBinarySTL(&self.mesh, path) catch |err| {
            std.debug.print("STL Export error: {s}\n", .{@errorName(err)});
            self.setStatus("STL Export Failed.");
            return;
        };
        self.setStatus("Exported STL successfully!");
    }
};
