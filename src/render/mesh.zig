const std = @import("std");
const c = @import("../c.zig").c;
const heightfield = @import("../core/heightfield.zig");
const HeightfieldMesh = heightfield.HeightfieldMesh;
const MeshVertex = heightfield.MeshVertex;

pub const GPUMesh = struct {
    vao: c.GLuint = 0,
    vbo: c.GLuint = 0,
    ebo: c.GLuint = 0,
    index_count: c.GLsizei = 0,

    pub fn init() GPUMesh {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        var ebo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);

        c.glBindVertexArray(vao);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);

        const stride: c.GLsizei = @sizeOf(MeshVertex);

        // Location 0: Position (3 x float)
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(@offsetOf(MeshVertex, "pos")));

        // Location 1: Normal (3 x float)
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(@offsetOf(MeshVertex, "normal")));

        // Location 2: UV (2 x float)
        c.glEnableVertexAttribArray(2);
        c.glVertexAttribPointer(2, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(@offsetOf(MeshVertex, "uv")));

        // Location 3: Color (3 x float)
        c.glEnableVertexAttribArray(3);
        c.glVertexAttribPointer(3, 3, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(@offsetOf(MeshVertex, "color")));

        c.glBindVertexArray(0);

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .index_count = 0,
        };
    }

    pub fn deinit(self: *GPUMesh) void {
        if (self.vao != 0) {
            c.glDeleteVertexArrays(1, &self.vao);
            c.glDeleteBuffers(1, &self.vbo);
            c.glDeleteBuffers(1, &self.ebo);
            self.vao = 0;
            self.vbo = 0;
            self.ebo = 0;
        }
    }

    pub fn upload(self: *GPUMesh, mesh: *const HeightfieldMesh) void {
        if (mesh.vertices.len == 0 or mesh.indices.len == 0) return;

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(mesh.vertices.len * @sizeOf(MeshVertex)),
            mesh.vertices.ptr,
            c.GL_DYNAMIC_DRAW,
        );

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
        c.glBufferData(
            c.GL_ELEMENT_ARRAY_BUFFER,
            @intCast(mesh.indices.len * @sizeOf(u32)),
            mesh.indices.ptr,
            c.GL_DYNAMIC_DRAW,
        );

        self.index_count = @intCast(mesh.indices.len);
    }

    pub fn draw(self: *const GPUMesh) void {
        if (self.index_count == 0) return;
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, self.index_count, c.GL_UNSIGNED_INT, null);
        c.glBindVertexArray(0);
    }
};
