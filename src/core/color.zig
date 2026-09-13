const std = @import("std");
const math = std.math;

pub const RGB = struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,

    pub fn init(r: f32, g: f32, b: f32) RGB {
        return .{
            .r = math.clamp(r, 0.0, 1.0),
            .g = math.clamp(g, 0.0, 1.0),
            .b = math.clamp(b, 0.0, 1.0),
        };
    }

    pub fn fromRGB8(r: u8, g: u8, b: u8) RGB {
        return .{
            .r = @as(f32, @floatFromInt(r)) / 255.0,
            .g = @as(f32, @floatFromInt(g)) / 255.0,
            .b = @as(f32, @floatFromInt(b)) / 255.0,
        };
    }

    pub fn toRGB8(self: RGB) RGB8 {
        return .{
            .r = @as(u8, @intFromFloat(math.clamp(self.r * 255.0 + 0.5, 0.0, 255.0))),
            .g = @as(u8, @intFromFloat(math.clamp(self.g * 255.0 + 0.5, 0.0, 255.0))),
            .b = @as(u8, @intFromFloat(math.clamp(self.b * 255.0 + 0.5, 0.0, 255.0))),
        };
    }

    pub fn fromHex(hex: u32) RGB {
        const r = @as(u8, @truncate(hex >> 16));
        const g = @as(u8, @truncate(hex >> 8));
        const b = @as(u8, @truncate(hex));
        return fromRGB8(r, g, b);
    }

    pub fn toHex(self: RGB) u32 {
        const rgb8 = self.toRGB8();
        return (@as(u32, rgb8.r) << 16) | (@as(u32, rgb8.g) << 8) | @as(u32, rgb8.b);
    }

    pub fn toLinear(self: RGB) RGB {
        return .{
            .r = srgbToLinear(self.r),
            .g = srgbToLinear(self.g),
            .b = srgbToLinear(self.b),
        };
    }

    pub fn toSRGB(self: RGB) RGB {
        return .{
            .r = linearToSRGB(self.r),
            .g = linearToSRGB(self.g),
            .b = linearToSRGB(self.b),
        };
    }

    pub fn luminanceBT709(self: RGB) f32 {
        return 0.2126 * self.r + 0.7152 * self.g + 0.0722 * self.b;
    }

    pub fn lerp(a: RGB, b: RGB, t: f32) RGB {
        const clamped_t = math.clamp(t, 0.0, 1.0);
        return .{
            .r = a.r + (b.r - a.r) * clamped_t,
            .g = a.g + (b.g - a.g) * clamped_t,
            .b = a.b + (b.b - a.b) * clamped_t,
        };
    }

    pub fn mul(self: RGB, scalar: f32) RGB {
        return .{
            .r = self.r * scalar,
            .g = self.g * scalar,
            .b = self.b * scalar,
        };
    }

    pub fn mulRGB(a: RGB, b: RGB) RGB {
        return .{
            .r = a.r * b.r,
            .g = a.g * b.g,
            .b = a.b * b.b,
        };
    }

    pub fn add(a: RGB, b: RGB) RGB {
        return .{
            .r = a.r + b.r,
            .g = a.g + b.g,
            .b = a.b + b.b,
        };
    }
};

pub const RGBA = struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 1.0,

    pub fn init(r: f32, g: f32, b: f32, a: f32) RGBA {
        return .{
            .r = math.clamp(r, 0.0, 1.0),
            .g = math.clamp(g, 0.0, 1.0),
            .b = math.clamp(b, 0.0, 1.0),
            .a = math.clamp(a, 0.0, 1.0),
        };
    }

    pub fn fromRGB(rgb: RGB, a: f32) RGBA {
        return .{ .r = rgb.r, .g = rgb.g, .b = rgb.b, .a = a };
    }

    pub fn toRGB(self: RGBA) RGB {
        return .{ .r = self.r, .g = self.g, .b = self.b };
    }
};

pub const RGB8 = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    pub fn toRGB(self: RGB8) RGB {
        return RGB.fromRGB8(self.r, self.g, self.b);
    }
};

pub const RGBA8 = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn toRGBA(self: RGBA8) RGBA {
        return .{
            .r = @as(f32, @floatFromInt(self.r)) / 255.0,
            .g = @as(f32, @floatFromInt(self.g)) / 255.0,
            .b = @as(f32, @floatFromInt(self.b)) / 255.0,
            .a = @as(f32, @floatFromInt(self.a)) / 255.0,
        };
    }
};

/// Exact IEC 61966-2-1 sRGB to Linear conversion
pub fn srgbToLinear(c_val: f32) f32 {
    const c_clamped = math.clamp(c_val, 0.0, 1.0);
    if (c_clamped <= 0.04045) {
        return c_clamped / 12.92;
    } else {
        return math.pow(f32, (c_clamped + 0.055) / 1.055, 2.4);
    }
}

/// Exact IEC 61966-2-1 Linear to sRGB conversion
pub fn linearToSRGB(c_val: f32) f32 {
    const c_clamped = math.clamp(c_val, 0.0, 1.0);
    if (c_clamped <= 0.0031308) {
        return c_clamped * 12.92;
    } else {
        return 1.055 * math.pow(f32, c_clamped, 1.0 / 2.4) - 0.055;
    }
}

/// Standard Natural Log of 10 for Beer-Lambert Transmission Distance calculations
pub const LN_10: f32 = 2.302585092994046;

/// Calculate optical transmittance T in [0.0, 1.0] for a layer of thickness (mm) with transmission distance TD (mm)
/// Transmission Distance (TD) is defined as the thickness where transmittance drops to 10% (T = 0.1)
/// T(d) = 10^(-d / TD) = exp(-alpha * d), where alpha = ln(10) / TD
pub fn calculateTransmittance(thickness_mm: f32, td_mm: f32) f32 {
    if (thickness_mm <= 0.0) return 1.0;
    if (td_mm <= 0.0001) return 0.0;
    const exponent = -(LN_10 * thickness_mm) / td_mm;
    return @exp(exponent);
}

/// Blend an incoming base color with an overlying translucent filament layer using Beer-Lambert law
/// `base_linear`: Color beneath the layer (in Linear RGB)
/// `layer_linear`: Native color of the top filament (in Linear RGB)
/// `thickness_mm`: Thickness of the top filament layer in mm
/// `td_mm`: Transmission Distance of the top filament in mm
pub fn blendBeerLambert(base_linear: RGB, layer_linear: RGB, thickness_mm: f32, td_mm: f32) RGB {
    if (thickness_mm <= 0.0) return base_linear;
    const t = calculateTransmittance(thickness_mm, td_mm); // Transmittance [0, 1]
    const opacity = 1.0 - t;

    // The translucent layer absorbs transmitted light while adding its own reflected body color
    // Transmitted component: base * layer * T
    // Surface/Volume scattering component: layer * (1 - T)
    return .{
        .r = layer_linear.r * (opacity + base_linear.r * t),
        .g = layer_linear.g * (opacity + base_linear.g * t),
        .b = layer_linear.b * (opacity + base_linear.b * t),
    };
}

test "color srgb linear roundtrip" {
    const original = RGB.init(0.2, 0.5, 0.8);
    const linear = original.toLinear();
    const srgb = linear.toSRGB();
    try std.testing.expectApproxEqAbs(original.r, srgb.r, 0.001);
    try std.testing.expectApproxEqAbs(original.g, srgb.g, 0.001);
    try std.testing.expectApproxEqAbs(original.b, srgb.b, 0.001);
}

test "beer lambert transmittance" {
    // At thickness = TD, transmittance should be exactly 0.1 (10%)
    const td: f32 = 3.0;
    const t_at_td = calculateTransmittance(td, td);
    try std.testing.expectApproxEqAbs(t_at_td, 0.10, 0.001);

    // At thickness = 0, transmittance is 1.0
    try std.testing.expectApproxEqAbs(calculateTransmittance(0.0, td), 1.0, 0.0001);

    // At 2 * TD, transmittance is 0.01 (1%)
    try std.testing.expectApproxEqAbs(calculateTransmittance(2.0 * td, td), 0.01, 0.001);
}
