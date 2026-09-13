const std = @import("std");
const math = std.math;
const Vec3 = @import("../core/heightfield.zig").Vec3;

pub const Mat4 = [16]f32;

pub const Camera = struct {
    yaw: f32 = 0.785398, // 45 degrees
    pitch: f32 = 0.610865, // ~35 degrees
    distance: f32 = 280.0,
    target: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
    fov_degrees: f32 = 45.0,

    pub fn init() Camera {
        return .{};
    }

    pub fn reset(self: *Camera, target_size: f32) void {
        self.yaw = 0.785398;
        self.pitch = 0.610865;
        self.target = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        self.distance = target_size * 1.8;
    }

    pub fn resetIsometric(self: *Camera) void {
        self.yaw = 0.785398; // 45 deg
        self.pitch = 0.610865; // ~35 deg
        self.target = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        self.distance = 280.0;
    }

    pub fn resetTop(self: *Camera) void {
        self.yaw = 0.0;
        self.pitch = math.pi * 0.48; // Near 90 deg down
        self.target = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        self.distance = 280.0;
    }

    pub fn resetFront(self: *Camera) void {
        self.yaw = 0.0;
        self.pitch = 0.0;
        self.target = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
        self.distance = 280.0;
    }

    pub fn rotate(self: *Camera, delta_yaw: f32, delta_pitch: f32) void {
        self.yaw += delta_yaw;
        self.pitch += delta_pitch;
        // Clamp pitch to avoid gimbal lock flip
        const max_pitch = math.pi * 0.49;
        const min_pitch = -math.pi * 0.49;
        self.pitch = math.clamp(self.pitch, min_pitch, max_pitch);
    }

    pub fn pan(self: *Camera, delta_x: f32, delta_y: f32) void {
        const cos_yaw = @cos(self.yaw);
        const sin_yaw = @sin(self.yaw);

        // Pan in camera right and up directions
        const right_x = cos_yaw;
        const right_y = -sin_yaw;

        const pan_speed = self.distance * 0.002;
        self.target.x += (right_x * delta_x) * pan_speed;
        self.target.y += (right_y * delta_x) * pan_speed;
        self.target.z += delta_y * pan_speed;
    }

    pub fn zoom(self: *Camera, delta_zoom: f32) void {
        self.distance -= delta_zoom * (self.distance * 0.05);
        if (self.distance < 10.0) self.distance = 10.0;
        if (self.distance > 5000.0) self.distance = 5000.0;
    }

    pub fn getEyePosition(self: *const Camera) Vec3 {
        const cos_pitch = @cos(self.pitch);
        const sin_pitch = @sin(self.pitch);
        const cos_yaw = @cos(self.yaw);
        const sin_yaw = @sin(self.yaw);

        return .{
            .x = self.target.x + self.distance * cos_pitch * sin_yaw,
            .y = self.target.y - self.distance * cos_pitch * cos_yaw,
            .z = self.target.z + self.distance * sin_pitch,
        };
    }

    pub fn getViewMatrix(self: *const Camera) Mat4 {
        const eye = self.getEyePosition();
        const target = self.target;
        const up = Vec3.init(0, 0, 1);

        const f = Vec3.sub(target, eye).normalize();
        const s = Vec3.cross(f, up).normalize();
        const u = Vec3.cross(s, f);

        var m: Mat4 = undefined;
        m[0] = s.x;
        m[4] = s.y;
        m[8] = s.z;
        m[12] = -(s.x * eye.x + s.y * eye.y + s.z * eye.z);

        m[1] = u.x;
        m[5] = u.y;
        m[9] = u.z;
        m[13] = -(u.x * eye.x + u.y * eye.y + u.z * eye.z);

        m[2] = -f.x;
        m[6] = -f.y;
        m[10] = -f.z;
        m[14] = f.x * eye.x + f.y * eye.y + f.z * eye.z;

        m[3] = 0.0;
        m[7] = 0.0;
        m[11] = 0.0;
        m[15] = 1.0;

        return m;
    }

    pub fn getProjectionMatrix(self: *const Camera, aspect_ratio: f32, near: f32, far: f32) Mat4 {
        const fov_rad = self.fov_degrees * (math.pi / 180.0);
        const f = 1.0 / @tan(fov_rad * 0.5);

        var m: Mat4 = [_]f32{0.0} ** 16;
        m[0] = f / aspect_ratio;
        m[5] = f;
        m[10] = (far + near) / (near - far);
        m[11] = -1.0;
        m[14] = (2.0 * far * near) / (near - far);
        m[15] = 0.0;

        return m;
    }
};

pub fn mat4Mul(a: Mat4, b: Mat4) Mat4 {
    var out: Mat4 = undefined;
    for (0..4) |row| {
        for (0..4) |col| {
            var sum: f32 = 0.0;
            for (0..4) |k| {
                sum += a[k * 4 + row] * b[col * 4 + k];
            }
            out[col * 4 + row] = sum;
        }
    }
    return out;
}
