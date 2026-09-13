const std = @import("std");
const c = @import("../../c.zig").c;
const heightfield = @import("../../core/heightfield.zig");
const HeightfieldMesh = heightfield.HeightfieldMesh;
const filament_mod = @import("../../core/filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const LayerSwapInfo = filament_mod.LayerSwapInfo;
const optical_mod = @import("../../core/optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;
const stl = @import("../../export/stl.zig");
const threemf = @import("../../export/threemf.zig");

pub const ExportState = struct {
    last_status_msg: [256]u8 = [_]u8{0} ** 256,
    status_timer: f32 = 0.0,
    export_3mf_path: [256]u8 = [_]u8{0} ** 256,
    export_stl_path: [256]u8 = [_]u8{0} ** 256,
};

pub fn initExportState() ExportState {
    var state = ExportState{};
    const default_3mf = "filament_painting.3mf";
    const default_stl = "relief_mesh.stl";
    @memcpy(state.export_3mf_path[0..default_3mf.len], default_3mf);
    @memcpy(state.export_stl_path[0..default_stl.len], default_stl);
    return state;
}

pub fn renderExportPanel(
    state: *ExportState,
    mesh: *const HeightfieldMesh,
    stack: *const FilamentStack,
    opt_config: *const OpticalConfig,
    allocator: std.mem.Allocator,
) void {
    _ = c.igTextColored(c.ImVec4{ .x = 0.35, .y = 0.75, .z = 1.0, .w = 1.0 }, "SLICER LAYER SCHEDULE & EXPORT");
    _ = c.igSeparator();
    _ = c.igSpacing();

    // 1. Slicer Filament Swap Schedule Table
    var swaps_buf: [16]LayerSwapInfo = undefined;
    const swap_count = stack.generateLayerSwaps(
        opt_config.first_layer_height,
        opt_config.layer_height,
        &swaps_buf,
    );

    _ = c.igTextColored(c.ImVec4{ .x = 0.95, .y = 0.75, .z = 0.25, .w = 1.0 }, "Bambu / Orca / Prusa Swap Schedule:");
    _ = c.igSpacing();

    if (c.igBeginTable("SwapTable", 4, c.ImGuiTableFlags_Borders | c.ImGuiTableFlags_RowBg, c.ImVec2{ .x = 0, .y = 0 }, 0)) {
        c.igTableSetupColumn("Slot", c.ImGuiTableColumnFlags_WidthFixed, 45, 0);
        c.igTableSetupColumn("Filament", c.ImGuiTableColumnFlags_WidthStretch, 0, 0);
        c.igTableSetupColumn("Layers", c.ImGuiTableColumnFlags_WidthFixed, 75, 0);
        c.igTableSetupColumn("Height Range", c.ImGuiTableColumnFlags_WidthFixed, 105, 0);
        c.igTableHeadersRow();

        for (0..swap_count) |s_idx| {
            const s = swaps_buf[s_idx];
            c.igTableNextRow(0, 0);

            // Slot column
            _ = c.igTableSetColumnIndex(0);
            _ = c.igText("#%d", s.slicer_slot);

            // Filament column (with color hex badge)
            _ = c.igTableSetColumnIndex(1);
            _ = c.igText("%s (#%06X)", s.name.ptr, s.color_hex);

            // Layers column
            _ = c.igTableSetColumnIndex(2);
            if (s_idx == 0) {
                _ = c.igText("1 -> %d", s.end_layer);
            } else {
                _ = c.igText("%d -> %d", s.start_layer, s.end_layer);
            }

            // Height Range column
            _ = c.igTableSetColumnIndex(3);
            _ = c.igText("%.2f - %.2f mm", s.start_z, s.end_z);
        }
        c.igEndTable();
    }

    _ = c.igSpacing();

    // Copy to Clipboard Button
    if (c.igButton(" 📋 Copy Slicer Instructions to Clipboard ", c.ImVec2{ .x = -1.0, .y = 24 })) {
        var copy_text = std.ArrayList(u8){};
        defer copy_text.deinit(allocator);
        var writer = copy_text.writer(allocator);

        writer.writeAll("=== 2MF Bambu/OrcaSlicer Layer Swaps ===\n") catch {};
        for (0..swap_count) |s_idx| {
            const s = swaps_buf[s_idx];
            if (s_idx == 0) {
                writer.print("• Start: Slot #{d} ({s}) -> Layers 1-{d} (0.00-{d:.2}mm)\n", .{ s.slicer_slot, s.name, s.end_layer, s.end_z }) catch {};
            } else {
                writer.print("• Swap: Slot #{d} ({s}) -> Layer {d} ({d:.2}mm) up to Layer {d} ({d:.2}mm)\n", .{ s.slicer_slot, s.name, s.start_layer, s.start_z, s.end_layer, s.end_z }) catch {};
            }
        }
        const text_z = allocator.allocSentinel(u8, copy_text.items.len, 0) catch null;
        if (text_z) |tz| {
            defer allocator.free(tz);
            @memcpy(tz, copy_text.items);
            _ = c.SDL_SetClipboardText(tz.ptr);
            const msg = "Copied instructions to clipboard!";
            @memcpy(state.last_status_msg[0..msg.len], msg);
            state.last_status_msg[msg.len] = 0;
            state.status_timer = 4.0;
        }
    }

    _ = c.igSpacing();
    _ = c.igSeparator();
    _ = c.igSpacing();

    // 2. Export Buttons
    _ = c.igTextColored(c.ImVec4{ .x = 0.95, .y = 0.75, .z = 0.25, .w = 1.0 }, "Export Production Files");

    // 3MF Export
    c.igPushStyleColor_Vec4(c.ImGuiCol_Button, c.ImVec4{ .x = 0.12, .y = 0.58, .z = 0.35, .w = 0.95 });
    c.igPushStyleColor_Vec4(c.ImGuiCol_ButtonHovered, c.ImVec4{ .x = 0.16, .y = 0.72, .z = 0.44, .w = 1.0 });
    if (c.igButton(" 🚀 Export Color-Mapped .3MF File ", c.ImVec2{ .x = -1.0, .y = 36 })) {
        const path_len = std.mem.indexOfScalar(u8, &state.export_3mf_path, 0) orelse state.export_3mf_path.len;
        const target_path = if (path_len > 0) state.export_3mf_path[0..path_len] else "filament_painting.3mf";

        threemf.export3MF(
            allocator,
            mesh,
            stack,
            .{
                .title = "2MF Filament Painting",
                .first_layer_height = opt_config.first_layer_height,
                .layer_height = opt_config.layer_height,
            },
            target_path,
        ) catch |err| {
            const err_msg = std.fmt.bufPrintZ(&state.last_status_msg, "Export failed: {s}", .{@errorName(err)}) catch "Error";
            _ = err_msg;
            state.status_timer = 5.0;
        };

        if (state.status_timer <= 5.0) {
            const success_msg = std.fmt.bufPrintZ(&state.last_status_msg, "✔ Exported 3MF successfully to {s}!", .{target_path}) catch "OK";
            _ = success_msg;
            state.status_timer = 6.0;
        }
    }
    c.igPopStyleColor(2);

    _ = c.igSpacing();

    // Binary STL Export
    if (c.igButton(" 📦 Export Watertight Binary .STL File ", c.ImVec2{ .x = -1.0, .y = 30 })) {
        const path_len = std.mem.indexOfScalar(u8, &state.export_stl_path, 0) orelse state.export_stl_path.len;
        const target_path = if (path_len > 0) state.export_stl_path[0..path_len] else "relief_mesh.stl";

        stl.exportBinarySTL(mesh, target_path) catch |err| {
            const err_msg = std.fmt.bufPrintZ(&state.last_status_msg, "STL export failed: {s}", .{@errorName(err)}) catch "Error";
            _ = err_msg;
            state.status_timer = 5.0;
            return;
        };

        const success_msg = std.fmt.bufPrintZ(&state.last_status_msg, "✔ Exported STL successfully to {s}!", .{target_path}) catch "OK";
        _ = success_msg;
        state.status_timer = 6.0;
    }

    // Status Banner
    const status_len = std.mem.indexOfScalar(u8, &state.last_status_msg, 0) orelse state.last_status_msg.len;
    if (status_len > 0 and state.status_timer > 0.0) {
        _ = c.igSpacing();
        _ = c.igTextColored(c.ImVec4{ .x = 0.2, .y = 1.0, .z = 0.4, .w = 1.0 }, "%s", &state.last_status_msg);
    }
}
