const std = @import("std");
const c = @import("../c.zig").c;
const theme_mod = @import("theme.zig");

const color_mod = @import("../core/color.zig");
const RGB = color_mod.RGB;
const filament_mod = @import("../core/filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const Filament = filament_mod.Filament;
const image_mod = @import("../core/image.zig");
const Image = image_mod.Image;
const ImageAdjustments = image_mod.ImageAdjustments;
const optical_mod = @import("../core/optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;
const heightfield = @import("../core/heightfield.zig");
const HeightfieldMesh = heightfield.HeightfieldMesh;

const renderer_mod = @import("../render/renderer.zig");
const Renderer = renderer_mod.Renderer;
const camera_mod = @import("../render/camera.zig");
const Camera = camera_mod.Camera;

const filament_panel = @import("panels/filament_panel.zig");
const image_panel = @import("panels/image_panel.zig");
const PrintDimensions = image_panel.PrintDimensions;
const viewport_panel = @import("panels/viewport_panel.zig");
const ViewportState = viewport_panel.ViewportState;
const histogram_panel = @import("panels/histogram_panel.zig");
const export_panel = @import("panels/export_panel.zig");
const ExportState = export_panel.ExportState;

var global_app_instance: ?*App = null;

fn openFileDialogCallback(userdata: ?*anyopaque, filelist: [*c]const [*c]const u8, filter: c_int) callconv(.c) void {
    _ = filter;
    if (userdata == null or filelist == null) return;
    const first_path = filelist[0];
    if (first_path != null) {
        const app: *App = @ptrCast(@alignCast(userdata));
        const span = std.mem.span(first_path);
        if (span.len > 0) {
            if (app.pending_load_path) |old| app.allocator.free(old);
            app.pending_load_path = app.allocator.dupe(u8, span) catch null;
        }
    }
}

fn requestBrowseProxy() void {
    if (global_app_instance) |app| {
        app.triggerFileBrowse();
    }
}

pub const App = struct {
    window: *c.SDL_Window,
    gl_context: c.SDL_GLContext,
    running: bool = true,
    allocator: std.mem.Allocator,

    // Core Data
    image: Image,
    adjustments: ImageAdjustments = .{},
    print_dimensions: PrintDimensions = .{},
    filament_stack: FilamentStack,
    optical_config: OpticalConfig = .{},
    mesh: HeightfieldMesh,

    // Graphics & Renderer
    renderer: Renderer,
    camera: Camera,
    viewport_state: ViewportState = .{},
    export_state: ExportState,

    // Optical transmission RGBA8 buffer
    opt_rgba_buffer: []u8 = &.{},

    // UI state
    file_path_buffer: [512]u8 = [_]u8{0} ** 512,
    pending_load_path: ?[]const u8 = null,
    img_dirty: bool = true,
    mesh_dirty: bool = true,
    left_tab: usize = 0, // 0 = Palette, 1 = Image & Slicing

    // Mouse tracking for 3D orbit
    mouse_dragging: bool = false,
    mouse_panning: bool = false,
    last_mouse_x: f32 = 0.0,
    last_mouse_y: f32 = 0.0,

    pub fn init(allocator: std.mem.Allocator) !*App {
        // 1. Initialize SDL3
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            std.debug.print("SDL_Init Error: {s}\n", .{c.SDL_GetError()});
            return error.SDLInitFailed;
        }

        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 3);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
        _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);

        const win_width: c_int = 1440;
        const win_height: c_int = 900;
        const window = c.SDL_CreateWindow(
            "Layerloom",
            win_width,
            win_height,
            c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        );
        if (window == null) {
            std.debug.print("SDL_CreateWindow Error: {s}\n", .{c.SDL_GetError()});
            return error.WindowCreateFailed;
        }

        const gl_ctx = c.SDL_GL_CreateContext(window);
        if (gl_ctx == null) {
            std.debug.print("SDL_GL_CreateContext Error: {s}\n", .{c.SDL_GetError()});
            return error.GLContextCreateFailed;
        }
        _ = c.SDL_GL_MakeCurrent(window, gl_ctx);
        _ = c.SDL_GL_SetSwapInterval(1); // Enable VSync

        // 2. Initialize Dear ImGui
        _ = c.igCreateContext(null);
        const io = c.igGetIO_Nil();
        io.*.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard;

        theme_mod.applyModernDarkTheme();

        _ = c.ImGui_ImplSDL3_InitForOpenGL(window, gl_ctx);
        _ = c.ImGui_ImplOpenGL3_Init("#version 330");

        // 3. Initialize App State
        const app = try allocator.create(App);
        global_app_instance = app;

        // Default procedural pattern image
        const img = try Image.createDefaultPattern(allocator, 256, 256);
        const stack = FilamentStack.initDefault();

        var cam = Camera.init();
        cam.resetIsometric();

        const rend = try Renderer.init(win_width, win_height);

        app.* = .{
            .window = window.?,
            .gl_context = gl_ctx.?,
            .allocator = allocator,
            .image = img,
            .filament_stack = stack,
            .mesh = HeightfieldMesh.initEmpty(allocator),
            .renderer = rend,
            .camera = cam,
            .export_state = export_panel.initExportState(),
        };

        app.optical_config.min_z = 0.40;
        app.optical_config.max_z = 2.40;
        app.optical_config.first_layer_height = 0.16;
        app.optical_config.layer_height = 0.08;
        app.filament_stack.autoDistribute(app.optical_config.min_z, app.optical_config.max_z);

        return app;
    }

    pub fn deinit(self: *App) void {
        global_app_instance = null;
        if (self.pending_load_path) |p| self.allocator.free(p);

        c.ImGui_ImplOpenGL3_Shutdown();
        c.ImGui_ImplSDL3_Shutdown();
        c.igDestroyContext(null);

        self.renderer.deinit();
        self.mesh.deinit();
        self.image.deinit();

        if (self.opt_rgba_buffer.len > 0) {
            self.allocator.free(self.opt_rgba_buffer);
        }

        _ = c.SDL_GL_DestroyContext(self.gl_context);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();

        self.allocator.destroy(self);
    }

    pub fn triggerFileBrowse(self: *App) void {
        const filters = [_]c.SDL_DialogFileFilter{
            .{ .name = "Images (*.png, *.jpg, *.jpeg, *.webp, *.bmp)", .pattern = "png;jpg;jpeg;webp;bmp" },
            .{ .name = "All Files (*.*)", .pattern = "*" },
        };
        c.SDL_ShowOpenFileDialog(openFileDialogCallback, self, self.window, &filters[0], filters.len, null, false);
    }

    pub fn loadNewImageFromPath(self: *App, raw_path: []const u8) void {
        if (Image.loadFromFile(self.allocator, raw_path)) |new_img| {
            self.image.deinit();
            self.image = new_img;
            self.image.recomputeLuminance(self.adjustments);

            if (self.print_dimensions.lock_aspect and self.image.width > 0 and self.image.height > 0) {
                const aspect = @as(f32, @floatFromInt(self.image.height)) / @as(f32, @floatFromInt(self.image.width));
                self.print_dimensions.height_mm = self.print_dimensions.width_mm * aspect;
            }

            // Copy path into file path buffer
            const copy_len = @min(raw_path.len, self.file_path_buffer.len - 1);
            @memcpy(self.file_path_buffer[0..copy_len], raw_path[0..copy_len]);
            self.file_path_buffer[copy_len] = 0;

            self.img_dirty = true;
            self.mesh_dirty = true;
            std.debug.print("Successfully loaded image from: {s}\n", .{raw_path});
        } else |err| {
            std.debug.print("Failed to load image from {s}: {s}\n", .{ raw_path, @errorName(err) });
        }
    }

    pub fn run(self: *App) !void {
        while (self.running) {
            self.handleEvents();
            self.update();
            self.render();
        }
    }

    fn handleEvents(self: *App) void {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            _ = c.ImGui_ImplSDL3_ProcessEvent(&event);

            switch (event.type) {
                c.SDL_EVENT_QUIT => {
                    self.running = false;
                },
                c.SDL_EVENT_DROP_FILE => {
                    if (event.drop.data) |drop_path| {
                        self.loadNewImageFromPath(std.mem.span(drop_path));
                    }
                },
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    // Only begin camera drag if mouse was clicked INSIDE the 3D viewport widget!
                    if (self.viewport_state.is_viewport_hovered) {
                        if (event.button.button == c.SDL_BUTTON_LEFT) {
                            self.mouse_dragging = true;
                            self.last_mouse_x = event.button.x;
                            self.last_mouse_y = event.button.y;
                        } else if (event.button.button == c.SDL_BUTTON_RIGHT or event.button.button == c.SDL_BUTTON_MIDDLE) {
                            self.mouse_panning = true;
                            self.last_mouse_x = event.button.x;
                            self.last_mouse_y = event.button.y;
                        }
                    }
                },
                c.SDL_EVENT_MOUSE_BUTTON_UP => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) {
                        self.mouse_dragging = false;
                    } else if (event.button.button == c.SDL_BUTTON_RIGHT or event.button.button == c.SDL_BUTTON_MIDDLE) {
                        self.mouse_panning = false;
                    }
                },
                c.SDL_EVENT_MOUSE_MOTION => {
                    const dx = event.motion.x - self.last_mouse_x;
                    const dy = event.motion.y - self.last_mouse_y;
                    self.last_mouse_x = event.motion.x;
                    self.last_mouse_y = event.motion.y;

                    if (self.mouse_dragging) {
                        self.camera.rotate(dx * 0.006, dy * 0.006);
                    } else if (self.mouse_panning) {
                        self.camera.pan(-dx * 0.25, dy * 0.25);
                    }
                },
                c.SDL_EVENT_MOUSE_WHEEL => {
                    // Zoom camera only if hovering viewport
                    if (self.viewport_state.is_viewport_hovered) {
                        self.camera.zoom(event.wheel.y * 1.5);
                    }
                },
                c.SDL_EVENT_WINDOW_RESIZED => {},
                else => {},
            }
        }
    }

    fn update(self: *App) void {
        // Process pending file dialog load
        if (self.pending_load_path) |path| {
            self.loadNewImageFromPath(path);
            self.allocator.free(path);
            self.pending_load_path = null;
        }

        // Reallocate optical preview buffer if image size changed
        const pixel_count = @as(usize, self.image.width) * @as(usize, self.image.height);
        if (self.opt_rgba_buffer.len != pixel_count * 4 and pixel_count > 0) {
            self.allocator.free(self.opt_rgba_buffer);
            self.opt_rgba_buffer = self.allocator.alloc(u8, pixel_count * 4) catch &.{};
            self.img_dirty = true;
        }

        // Recompute Beer-Lambert optical preview buffer
        if (self.img_dirty and pixel_count > 0 and self.opt_rgba_buffer.len == pixel_count * 4) {
            optical_mod.renderOpticalBuffer(
                self.image.luminance,
                self.image.width,
                self.image.height,
                &self.filament_stack,
                self.optical_config,
                self.opt_rgba_buffer,
            );

            // Upload RGBA buffer to GPU Texture
            self.renderer.optical_texture.updateRGBA(
                self.image.width,
                self.image.height,
                self.opt_rgba_buffer,
            );
            self.img_dirty = false;
        }

        // Regenerate 3D Mesh
        if (self.mesh_dirty and self.image.luminance.len > 0) {
            const grid_res = self.print_dimensions.mesh_resolution;
            self.mesh.generate(
                self.image.luminance,
                self.image.width,
                self.image.height,
                grid_res,
                grid_res,
                self.print_dimensions.width_mm,
                self.print_dimensions.height_mm,
                &self.filament_stack,
                self.optical_config,
            ) catch {};

            // Upload Mesh to GPU Buffers
            self.renderer.gpu_mesh.upload(&self.mesh);
            self.mesh_dirty = false;
        }

        if (self.export_state.status_timer > 0.0) {
            self.export_state.status_timer -= 0.016;
        }
    }

    fn render(self: *App) void {
        var win_w: c_int = 0;
        var win_h: c_int = 0;
        _ = c.SDL_GetWindowSize(self.window, &win_w, &win_h);

        c.ImGui_ImplOpenGL3_NewFrame();
        c.ImGui_ImplSDL3_NewFrame();
        c.igNewFrame();

        // 1. Sleek Fullscreen Main Window Layout
        c.igSetNextWindowPos(c.ImVec2{ .x = 0, .y = 0 }, c.ImGuiCond_Always, c.ImVec2{ .x = 0, .y = 0 });
        c.igSetNextWindowSize(c.ImVec2{ .x = @floatFromInt(win_w), .y = @floatFromInt(win_h) }, c.ImGuiCond_Always);

        const root_flags = c.ImGuiWindowFlags_NoTitleBar |
            c.ImGuiWindowFlags_NoResize |
            c.ImGuiWindowFlags_NoMove |
            c.ImGuiWindowFlags_NoCollapse |
            c.ImGuiWindowFlags_MenuBar |
            c.ImGuiWindowFlags_NoBringToFrontOnFocus;

        c.igPushStyleVar_Vec2(c.ImGuiStyleVar_WindowPadding, c.ImVec2{ .x = 10, .y = 10 });
        const is_open = c.igBegin("MainWindow", null, root_flags);
        c.igPopStyleVar(1);

        if (is_open) {
            // Header Top Bar
            self.renderHeaderBar();

            _ = c.igSpacing();

            // Calculate Panel Widths
            const total_w = @as(f32, @floatFromInt(win_w)) - 28.0;
            const left_panel_w: f32 = 380.0;
            const right_panel_w: f32 = 360.0;
            const center_panel_w = @max(300.0, total_w - left_panel_w - right_panel_w - 16.0);
            const content_h = @as(f32, @floatFromInt(win_h)) - 72.0;

            // Left Sidebar Card
            if (c.igBeginChild_Str("LeftSidebar", c.ImVec2{ .x = left_panel_w, .y = content_h }, c.ImGuiChildFlags_Borders, 0)) {
                if (c.igBeginTabBar("LeftTabs", 0)) {
                    if (c.igBeginTabItem(" 🎨 Filament Palette ", null, 0)) {
                        filament_panel.renderFilamentPanel(
                            &self.filament_stack,
                            &self.optical_config,
                            &self.img_dirty,
                            &self.mesh_dirty,
                        );
                        c.igEndTabItem();
                    }
                    if (c.igBeginTabItem(" 🖼️ Image & Slicing ", null, 0)) {
                        image_panel.renderImagePanel(
                            &self.image,
                            &self.adjustments,
                            &self.print_dimensions,
                            &self.optical_config,
                            &self.file_path_buffer,
                            &self.img_dirty,
                            &self.mesh_dirty,
                            requestBrowseProxy,
                            self.allocator,
                        );
                        c.igEndTabItem();
                    }
                    c.igEndTabBar();
                }
            }
            c.igEndChild();

            c.igSameLine(0, 8);

            // Center Viewport Card
            if (c.igBeginChild_Str("CenterViewport", c.ImVec2{ .x = center_panel_w, .y = content_h }, c.ImGuiChildFlags_Borders, 0)) {
                viewport_panel.renderViewportPanel(
                    &self.viewport_state,
                    &self.renderer,
                    &self.camera,
                    &self.optical_config,
                    &self.img_dirty,
                );
            }
            c.igEndChild();

            c.igSameLine(0, 8);

            // Right Sidebar Card
            if (c.igBeginChild_Str("RightSidebar", c.ImVec2{ .x = right_panel_w, .y = content_h }, c.ImGuiChildFlags_Borders, 0)) {
                // Tonal Range Histogram
                histogram_panel.renderHistogramPanel(
                    &self.image,
                    &self.filament_stack,
                    self.optical_config.min_z,
                    self.optical_config.max_z,
                );

                _ = c.igSpacing();
                _ = c.igSeparator();
                _ = c.igSpacing();

                // Slicer Schedule & Export
                export_panel.renderExportPanel(
                    &self.export_state,
                    &self.mesh,
                    &self.filament_stack,
                    &self.optical_config,
                    self.allocator,
                );
            }
            c.igEndChild();
        }
        c.igEnd();

        // 2. Render ImGui to Main Framebuffer
        c.igRender();

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        c.glViewport(0, 0, win_w, win_h);
        c.glClearColor(0.08, 0.09, 0.11, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.ImGui_ImplOpenGL3_RenderDrawData(c.igGetDrawData());
        _ = c.SDL_GL_SwapWindow(self.window);
    }

    fn renderHeaderBar(self: *App) void {
        _ = c.igTextColored(c.ImVec4{ .x = 0.35, .y = 0.75, .z = 1.0, .w = 1.0 }, "⚡ 2MF STUDIO");
        c.igSameLine(0, 8);
        c.igTextDisabled("v1.0 Native HueForge Studio", "");

        c.igSameLine(0, 30);
        if (c.igButton(" 📂 Open Image... ", c.ImVec2{ .x = 130, .y = 24 })) {
            self.triggerFileBrowse();
        }

        c.igSameLine(0, 8);
        if (c.igButton(" ⚡ Auto-Tune Layers ", c.ImVec2{ .x = 145, .y = 24 })) {
            self.filament_stack.autoDistribute(self.optical_config.min_z, self.optical_config.max_z);
            self.img_dirty = true;
            self.mesh_dirty = true;
        }

        c.igSameLine(0, 16);
        c.igPushStyleColor_Vec4(c.ImGuiCol_Button, c.ImVec4{ .x = 0.12, .y = 0.58, .z = 0.35, .w = 0.95 });
        c.igPushStyleColor_Vec4(c.ImGuiCol_ButtonHovered, c.ImVec4{ .x = 0.16, .y = 0.72, .z = 0.44, .w = 1.0 });
        if (c.igButton(" 🚀 Quick Export 3MF ", c.ImVec2{ .x = 150, .y = 24 })) {
            _ = @import("../export/threemf.zig").export3MF(
                self.allocator,
                &self.mesh,
                &self.filament_stack,
                .{
                    .title = "2MF Filament Painting",
                    .first_layer_height = self.optical_config.first_layer_height,
                    .layer_height = self.optical_config.layer_height,
                },
                "filament_painting.3mf",
            ) catch {};
            const msg = "✔ Exported filament_painting.3mf!";
            @memcpy(self.export_state.last_status_msg[0..msg.len], msg);
            self.export_state.last_status_msg[msg.len] = 0;
            self.export_state.status_timer = 5.0;
        }
        c.igPopStyleColor(2);
    }
};
