const std = @import("std");
const color_mod = @import("color.zig");
const RGB = color_mod.RGB;
const RGB8 = color_mod.RGB8;

pub const MAX_FILAMENTS = 16;

pub const Filament = struct {
    name: [64]u8 = [_]u8{0} ** 64,
    name_len: usize = 0,
    color: RGB = .{ .r = 0.0, .g = 0.0, .b = 0.0 }, // sRGB [0..1]
    td_mm: f32 = 2.0, // Transmission Distance in mm
    start_z: f32 = 0.0, // Start height in mm
    end_z: f32 = 2.0, // Max height in mm
    slicer_slot: u8 = 1, // AMS / MMU slot 1..16

    pub fn init(name_str: []const u8, rgb: RGB, td: f32, start_z: f32, end_z: f32, slot: u8) Filament {
        var f = Filament{
            .color = rgb,
            .td_mm = td,
            .start_z = start_z,
            .end_z = end_z,
            .slicer_slot = slot,
        };
        f.setName(name_str);
        return f;
    }

    pub fn setName(self: *Filament, name_str: []const u8) void {
        const len = @min(name_str.len, self.name.len - 1);
        @memcpy(self.name[0..len], name_str[0..len]);
        self.name[len] = 0;
        self.name_len = len;
    }

    pub fn getName(self: *const Filament) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn linearColor(self: *const Filament) RGB {
        return self.color.toLinear();
    }
};

pub const FilamentPreset = struct {
    name: []const u8,
    hex: u32,
    td_mm: f32,
};

pub const PRESETS = [_]FilamentPreset{
    // Bambu Lab
    .{ .name = "Bambu PLA Basic Black", .hex = 0x0a0a0a, .td_mm = 0.6 },
    .{ .name = "Bambu PLA Basic Blue", .hex = 0x0047ba, .td_mm = 3.5 },
    .{ .name = "Bambu PLA Basic Red", .hex = 0xcc1122, .td_mm = 4.0 },
    .{ .name = "Bambu PLA Basic Yellow", .hex = 0xf5d020, .td_mm = 6.0 },
    .{ .name = "Bambu PLA Basic Jade White", .hex = 0xfafafa, .td_mm = 5.2 },
    .{ .name = "Bambu PLA Basic Grey", .hex = 0x8f8f8f, .td_mm = 2.2 },
    .{ .name = "Bambu PLA Basic Green", .hex = 0x1e8838, .td_mm = 3.8 },
    .{ .name = "Bambu PLA Basic Orange", .hex = 0xf05a22, .td_mm = 4.8 },
    .{ .name = "Bambu PLA Basic Brown", .hex = 0x5c3a21, .td_mm = 1.8 },
    .{ .name = "Bambu PLA Matte Charcoal", .hex = 0x222222, .td_mm = 0.4 },
    .{ .name = "Bambu PLA Matte Ivory White", .hex = 0xf5f3ea, .td_mm = 3.2 },

    // Polymaker PolyLite
    .{ .name = "PolyLite PLA Black", .hex = 0x111111, .td_mm = 0.8 },
    .{ .name = "PolyLite PLA Cyan", .hex = 0x00a3e0, .td_mm = 3.2 },
    .{ .name = "PolyLite PLA Magenta", .hex = 0xdb0072, .td_mm = 3.6 },
    .{ .name = "PolyLite PLA Yellow", .hex = 0xffe600, .td_mm = 5.8 },
    .{ .name = "PolyLite PLA White", .hex = 0xffffff, .td_mm = 4.6 },
    .{ .name = "PolyLite PLA Army Red", .hex = 0x9b111e, .td_mm = 2.5 },
    .{ .name = "PolyLite PLA Teal", .hex = 0x008080, .td_mm = 3.0 },

    // Sunlu
    .{ .name = "Sunlu PLA+ Black", .hex = 0x050505, .td_mm = 0.5 },
    .{ .name = "Sunlu PLA+ White", .hex = 0xfcfcfc, .td_mm = 5.0 },
    .{ .name = "Sunlu PLA+ Grey", .hex = 0x7c7c7c, .td_mm = 2.0 },
    .{ .name = "Sunlu PLA+ Blue", .hex = 0x104e8b, .td_mm = 3.4 },
    .{ .name = "Sunlu PLA+ Red", .hex = 0xcd2626, .td_mm = 3.9 },
};

pub const LayerSwapInfo = struct {
    filament_index: usize,
    slicer_slot: u8,
    name: []const u8,
    color_hex: u32,
    start_z: f32,
    start_layer: u32,
    end_z: f32,
    end_layer: u32,
};

pub const FilamentStack = struct {
    items: [MAX_FILAMENTS]Filament = undefined,
    count: usize = 0,

    pub fn initDefault() FilamentStack {
        var stack = FilamentStack{};
        // Default 4-color starter stack (Black -> Blue -> Red -> White)
        _ = stack.add(Filament.init("Bambu PLA Basic Black", RGB.fromHex(0x0a0a0a), 0.6, 0.0, 0.64, 1));
        _ = stack.add(Filament.init("Bambu PLA Basic Blue", RGB.fromHex(0x0047ba), 3.5, 0.64, 1.28, 2));
        _ = stack.add(Filament.init("Bambu PLA Basic Red", RGB.fromHex(0xcc1122), 4.0, 1.28, 1.92, 3));
        _ = stack.add(Filament.init("Bambu PLA Basic Jade White", RGB.fromHex(0xfafafa), 5.2, 1.92, 2.40, 4));
        return stack;
    }

    pub fn add(self: *FilamentStack, filament: Filament) bool {
        if (self.count >= MAX_FILAMENTS) return false;
        self.items[self.count] = filament;
        self.count += 1;
        return true;
    }

    pub fn remove(self: *FilamentStack, index: usize) bool {
        if (index >= self.count or self.count <= 1) return false;
        var i = index;
        while (i + 1 < self.count) : (i += 1) {
            self.items[i] = self.items[i + 1];
        }
        self.count -= 1;
        return true;
    }

    pub fn moveUp(self: *FilamentStack, index: usize) bool {
        if (index == 0 or index >= self.count) return false;
        const temp = self.items[index];
        self.items[index] = self.items[index - 1];
        self.items[index - 1] = temp;
        return true;
    }

    pub fn moveDown(self: *FilamentStack, index: usize) bool {
        if (index + 1 >= self.count) return false;
        const temp = self.items[index];
        self.items[index] = self.items[index + 1];
        self.items[index + 1] = temp;
        return true;
    }

    pub fn autoDistribute(self: *FilamentStack, min_z: f32, max_z: f32) void {
        if (self.count == 0) return;
        const span = max_z - min_z;
        const step = span / @as(f32, @floatFromInt(self.count));
        for (0..self.count) |i| {
            const z_start = min_z + @as(f32, @floatFromInt(i)) * step;
            const z_end = if (i + 1 == self.count) max_z else min_z + @as(f32, @floatFromInt(i + 1)) * step;
            self.items[i].start_z = z_start;
            self.items[i].end_z = z_end;
        }
    }

    pub fn getActiveFilamentAtZ(self: *const FilamentStack, z: f32) usize {
        if (self.count == 0) return 0;
        var highest_idx: usize = 0;
        for (0..self.count) |i| {
            if (z >= self.items[i].start_z) {
                highest_idx = i;
            }
        }
        return highest_idx;
    }

    pub fn generateLayerSwaps(
        self: *const FilamentStack,
        first_layer_height: f32,
        layer_height: f32,
        out_buffer: []LayerSwapInfo,
    ) usize {
        const count = @min(self.count, out_buffer.len);
        for (0..count) |i| {
            const f = &self.items[i];
            const start_layer = zToLayer(f.start_z, first_layer_height, layer_height);
            const end_layer = zToLayer(f.end_z, first_layer_height, layer_height);

            out_buffer[i] = .{
                .filament_index = i,
                .slicer_slot = f.slicer_slot,
                .name = f.getName(),
                .color_hex = f.color.toHex(),
                .start_z = f.start_z,
                .start_layer = start_layer,
                .end_z = f.end_z,
                .end_layer = end_layer,
            };
        }
        return count;
    }
};

pub fn zToLayer(z: f32, first_layer_height: f32, layer_height: f32) u32 {
    if (z <= 0.0) return 1;
    if (z <= first_layer_height) return 1;
    const diff = z - first_layer_height;
    const layer_idx = 1 + @as(u32, @intFromFloat(@floor(diff / layer_height + 0.5)));
    return layer_idx;
}

pub fn layerToZ(layer: u32, first_layer_height: f32, layer_height: f32) f32 {
    if (layer <= 1) return first_layer_height;
    return first_layer_height + @as(f32, @floatFromInt(layer - 1)) * layer_height;
}

test "filament stack default initialization" {
    const stack = FilamentStack.initDefault();
    try std.testing.expectEqual(@as(usize, 4), stack.count);
    try std.testing.expectEqualStrings("Bambu PLA Basic Black", stack.items[0].getName());
}
