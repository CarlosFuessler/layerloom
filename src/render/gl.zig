const std = @import("std");
const c = @import("../c.zig").c;

pub fn checkGLError(operation_name: []const u8) void {
    var err = c.glGetError();
    while (err != c.GL_NO_ERROR) : (err = c.glGetError()) {
        std.debug.print("[OpenGL Error] after {s}: 0x{X}\n", .{ operation_name, err });
    }
}

pub fn compileShader(shader_type: c.GLenum, source: [:0]const u8) !c.GLuint {
    const shader = c.glCreateShader(shader_type);
    if (shader == 0) return error.ShaderCreationFailed;

    const src_ptr: ?[*]const u8 = source.ptr;
    const len: c.GLint = @intCast(source.len);
    c.glShaderSource(shader, 1, &src_ptr, &len);
    c.glCompileShader(shader);

    var success: c.GLint = 0;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var info_log: [1024]u8 = undefined;
        var log_len: c.GLsizei = 0;
        c.glGetShaderInfoLog(shader, 1024, &log_len, &info_log);
        std.debug.print("[GLSL Compile Error]: {s}\n", .{info_log[0..@as(usize, @intCast(log_len))]});
        c.glDeleteShader(shader);
        return error.ShaderCompilationFailed;
    }

    return shader;
}

pub fn createShaderProgram(vert_src: [:0]const u8, frag_src: [:0]const u8) !c.GLuint {
    const vert = try compileShader(c.GL_VERTEX_SHADER, vert_src);
    defer c.glDeleteShader(vert);

    const frag = try compileShader(c.GL_FRAGMENT_SHADER, frag_src);
    defer c.glDeleteShader(frag);

    const program = c.glCreateProgram();
    if (program == 0) return error.ProgramCreationFailed;

    c.glAttachShader(program, vert);
    c.glAttachShader(program, frag);
    c.glLinkProgram(program);

    var success: c.GLint = 0;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        var info_log: [1024]u8 = undefined;
        var log_len: c.GLsizei = 0;
        c.glGetProgramInfoLog(program, 1024, &log_len, &info_log);
        std.debug.print("[GLSL Link Error]: {s}\n", .{info_log[0..@as(usize, @intCast(log_len))]});
        c.glDeleteProgram(program);
        return error.ProgramLinkFailed;
    }

    return program;
}

pub const Texture2D = struct {
    id: c.GLuint = 0,
    width: u32 = 0,
    height: u32 = 0,

    pub fn init() Texture2D {
        var tex: c.GLuint = 0;
        c.glGenTextures(1, &tex);
        c.glBindTexture(c.GL_TEXTURE_2D, tex);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        return .{ .id = tex };
    }

    pub fn deinit(self: *Texture2D) void {
        if (self.id != 0) {
            c.glDeleteTextures(1, &self.id);
            self.id = 0;
        }
    }

    pub fn updateRGBA(self: *Texture2D, width: u32, height: u32, data: []const u8) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.id);
        if (self.width != width or self.height != height) {
            self.width = width;
            self.height = height;
            c.glTexImage2D(
                c.GL_TEXTURE_2D,
                0,
                c.GL_RGBA8,
                @intCast(width),
                @intCast(height),
                0,
                c.GL_RGBA,
                c.GL_UNSIGNED_BYTE,
                data.ptr,
            );
        } else {
            c.glTexSubImage2D(
                c.GL_TEXTURE_2D,
                0,
                0,
                0,
                @intCast(width),
                @intCast(height),
                c.GL_RGBA,
                c.GL_UNSIGNED_BYTE,
                data.ptr,
            );
        }
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
    }
};
