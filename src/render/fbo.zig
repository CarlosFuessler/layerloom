const std = @import("std");
const c = @import("../c.zig").c;

pub const Framebuffer = struct {
    fbo: c.GLuint = 0,
    color_texture: c.GLuint = 0,
    depth_rbo: c.GLuint = 0,
    width: i32 = 0,
    height: i32 = 0,

    pub fn init(width: i32, height: i32) Framebuffer {
        var self = Framebuffer{
            .width = @max(1, width),
            .height = @max(1, height),
        };
        self.create();
        return self;
    }

    pub fn deinit(self: *Framebuffer) void {
        self.destroy();
    }

    pub fn resize(self: *Framebuffer, width: i32, height: i32) void {
        const w = @max(1, width);
        const h = @max(1, height);
        if (self.width == w and self.height == h) return;

        self.width = w;
        self.height = h;
        self.destroy();
        self.create();
    }

    fn create(self: *Framebuffer) void {
        c.glGenFramebuffers(1, &self.fbo);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.fbo);

        // Color texture
        c.glGenTextures(1, &self.color_texture);
        c.glBindTexture(c.GL_TEXTURE_2D, self.color_texture);
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA8,
            self.width,
            self.height,
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            null,
        );
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, self.color_texture, 0);

        // Depth renderbuffer
        c.glGenRenderbuffers(1, &self.depth_rbo);
        c.glBindRenderbuffer(c.GL_RENDERBUFFER, self.depth_rbo);
        c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH24_STENCIL8, self.width, self.height);
        c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_STENCIL_ATTACHMENT, c.GL_RENDERBUFFER, self.depth_rbo);

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
        c.glBindRenderbuffer(c.GL_RENDERBUFFER, 0);
    }

    fn destroy(self: *Framebuffer) void {
        if (self.fbo != 0) {
            c.glDeleteFramebuffers(1, &self.fbo);
            self.fbo = 0;
        }
        if (self.color_texture != 0) {
            c.glDeleteTextures(1, &self.color_texture);
            self.color_texture = 0;
        }
        if (self.depth_rbo != 0) {
            c.glDeleteRenderbuffers(1, &self.depth_rbo);
            self.depth_rbo = 0;
        }
    }

    pub fn bind(self: *const Framebuffer) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.fbo);
        c.glViewport(0, 0, self.width, self.height);
    }

    pub fn unbind(_: *const Framebuffer) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }
};
