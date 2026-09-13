const std = @import("std");
const c = @import("../../c.zig").c;
const filament_mod = @import("../../core/filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const Filament = filament_mod.Filament;
const color_mod = @import("../../core/color.zig");
const RGB = color_mod.RGB;
const optical_mod = @import("../../core/optical.zig");
const OpticalConfig = optical_mod.OpticalConfig;

pub fn renderFilamentPanel(
    stack: *FilamentStack,
    opt_config: *const OpticalConfig,
    img_dirty: *bool,
    mesh_dirty: *bool,
) void {
    _ = c.igTextColored(c.ImVec4{ .x = 0.35, .y = 0.75, .z = 1.0, .w = 1.0 }, "FILAMENT PALETTE & OPTICAL STACK");
    _ = c.igSeparator();
    _ = c.igSpacing();

    // 1. Preset Library Quick Buttons
    _ = c.igTextDisabled("Quick Presets:", "");
    if (c.igButton("Bambu 4-Color (CMYK)", c.ImVec2{ .x = 145, .y = 22 })) {
        stack.* = FilamentStack.initDefault();
        stack.autoDistribute(opt_config.min_z, opt_config.max_z);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }
    c.igSameLine(0, 6);
    if (c.igButton("PolyLite 4-Color", c.ImVec2{ .x = 120, .y = 22 })) {
        stack.* = FilamentStack{};
        _ = stack.add(Filament.init("PolyLite Black", RGB.fromHex(0x111111), 0.5, 0.0, 0.6, 1));
        _ = stack.add(Filament.init("PolyLite Blue", RGB.fromHex(0x0a4fa0), 3.0, 0.6, 1.2, 2));
        _ = stack.add(Filament.init("PolyLite Yellow", RGB.fromHex(0xf5d000), 5.5, 1.2, 1.8, 3));
        _ = stack.add(Filament.init("PolyLite White", RGB.fromHex(0xffffff), 5.0, 1.8, 2.4, 4));
        stack.autoDistribute(opt_config.min_z, opt_config.max_z);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }
    c.igSameLine(0, 6);
    if (c.igButton("Monochrome (5-Shade)", c.ImVec2{ .x = 140, .y = 22 })) {
        stack.* = FilamentStack{};
        _ = stack.add(Filament.init("Black", RGB.fromHex(0x050505), 0.4, 0.0, 0.5, 1));
        _ = stack.add(Filament.init("Dark Gray", RGB.fromHex(0x333333), 1.2, 0.5, 1.0, 2));
        _ = stack.add(Filament.init("Mid Gray", RGB.fromHex(0x777777), 2.5, 1.0, 1.5, 3));
        _ = stack.add(Filament.init("Light Gray", RGB.fromHex(0xbbbbbb), 4.0, 1.5, 2.0, 4));
        _ = stack.add(Filament.init("White", RGB.fromHex(0xffffff), 5.5, 2.0, 2.4, 5));
        stack.autoDistribute(opt_config.min_z, opt_config.max_z);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    _ = c.igSpacing();

    // 2. Action Toolbar: Add / Auto-Distribute
    if (c.igButton(" ➕ Add Layer ", c.ImVec2{ .x = 110, .y = 24 })) {
        if (stack.count < 16) {
            const last_end = if (stack.count > 0) stack.items[stack.count - 1].end_z else opt_config.min_z;
            _ = stack.add(Filament.init(
                "New Filament",
                RGB.init(0.8, 0.8, 0.8),
                3.5,
                last_end,
                @min(opt_config.max_z, last_end + 0.4),
                @as(u8, @intCast(stack.count + 1)),
            ));
            img_dirty.* = true;
            mesh_dirty.* = true;
        }
    }
    c.igSameLine(0, 8);
    if (c.igButton(" ⚡ Auto-Distribute Z Heights ", c.ImVec2{ .x = 200, .y = 24 })) {
        stack.autoDistribute(opt_config.min_z, opt_config.max_z);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }

    _ = c.igSpacing();
    _ = c.igSeparator();
    _ = c.igSpacing();

    // 3. Render Filament Stack Cards
    var to_remove: ?usize = null;
    var to_move_up: ?usize = null;
    var to_move_down: ?usize = null;

    var i: usize = 0;
    while (i < stack.count) : (i += 1) {
        c.igPushID_Int(@intCast(i));
        defer c.igPopID();

        const fil = &stack.items[i];

        // Draw colored circle / swatch preview
        var col_arr = [3]f32{ fil.color.r, fil.color.g, fil.color.b };
        if (c.igColorEdit3("##Col", &col_arr, c.ImGuiColorEditFlags_NoInputs)) {
            fil.color = RGB.init(col_arr[0], col_arr[1], col_arr[2]);
            img_dirty.* = true;
            mesh_dirty.* = true;
        }
        c.igSameLine(0, 6);

        // Name text input
        var name_buf = [_]u8{0} ** 32;
        @memcpy(name_buf[0..fil.name_len], fil.name[0..fil.name_len]);
        c.igSetNextItemWidth(140);
        if (c.igInputText("##Name", &name_buf, name_buf.len, 0, null, null)) {
            const new_len = std.mem.indexOfScalar(u8, &name_buf, 0) orelse name_buf.len;
            @memcpy(fil.name[0..new_len], name_buf[0..new_len]);
            fil.name_len = @as(u8, @intCast(new_len));
        }

        // Reordering and deletion controls
        c.igSameLine(0, 8);
        if (i > 0 and c.igButton("▲", c.ImVec2{ .x = 22, .y = 20 })) {
            to_move_up = i;
        }
        c.igSameLine(0, 4);
        if (i + 1 < stack.count and c.igButton("▼", c.ImVec2{ .x = 22, .y = 20 })) {
            to_move_down = i;
        }
        c.igSameLine(0, 4);
        if (stack.count > 1 and c.igButton("✕", c.ImVec2{ .x = 22, .y = 20 })) {
            to_remove = i;
        }

        // Sliders for TD and Height Range
        c.igIndent(28);

        // Transmission distance slider
        c.igSetNextItemWidth(200);
        if (c.igSliderFloat("TD (mm)", &fil.td_mm, 0.1, 15.0, "%.2f mm", 0)) {
            img_dirty.* = true;
            mesh_dirty.* = true;
        }
        c.igSameLine(0, 8);
        c.igTextDisabled("(Optical Opacity)", "");

        // Height range sliders
        c.igSetNextItemWidth(120);
        if (c.igSliderFloat("Start Z", &fil.start_z, 0.0, opt_config.max_z, "%.2f mm", 0)) {
            fil.start_z = @min(fil.start_z, fil.end_z);
            img_dirty.* = true;
            mesh_dirty.* = true;
        }
        c.igSameLine(0, 8);
        c.igSetNextItemWidth(120);
        if (c.igSliderFloat("End Z", &fil.end_z, 0.0, opt_config.max_z, "%.2f mm", 0)) {
            fil.end_z = @max(fil.start_z, fil.end_z);
            img_dirty.* = true;
            mesh_dirty.* = true;
        }

        var slot_i32: c_int = @intCast(fil.slicer_slot);
        c.igSetNextItemWidth(80);
        if (c.igSliderInt("AMS Slot", &slot_i32, 1, 16, "%d", 0)) {
            fil.slicer_slot = @as(u8, @intCast(slot_i32));
        }

        c.igUnindent(28);
        _ = c.igSpacing();
    }

    if (to_move_up) |idx| {
        _ = stack.moveUp(idx);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }
    if (to_move_down) |idx| {
        _ = stack.moveDown(idx);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }
    if (to_remove) |idx| {
        _ = stack.remove(idx);
        img_dirty.* = true;
        mesh_dirty.* = true;
    }
}
