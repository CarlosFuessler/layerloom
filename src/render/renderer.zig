const std = @import("std");
const c = @import("../c.zig").c;
const gl = @import("gl.zig");
const mesh_mod = @import("mesh.zig");
const GPUMesh = mesh_mod.GPUMesh;
const camera_mod = @import("camera.zig");
const Camera = camera_mod.Camera;
const Mat4 = camera_mod.Mat4;
const Vec3 = @import("../core/heightfield.zig").Vec3;
const fbo_mod = @import("fbo.zig");
pub const Framebuffer = fbo_mod.Framebuffer;

const MESH_VERT_SHADER: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aNormal;
    \\layout (location = 2) in vec2 aUV;
    \\layout (location = 3) in vec3 aColor;
    \\
    \\uniform mat4 uMVP;
    \\uniform mat4 uModel;
    \\
    \\out vec3 vWorldPos;
    \\out vec3 vNormal;
    \\out vec2 vUV;
    \\out vec3 vColor;
    \\
    \\void main() {
    \\    vWorldPos = (uModel * vec4(aPos, 1.0)).xyz;
    \\    vNormal = normalize(mat3(uModel) * aNormal);
    \\    vUV = aUV;
    \\    vColor = aColor;
    \\    gl_Position = uMVP * vec4(aPos, 1.0);
    \\}
;

const MESH_FRAG_SHADER: [:0]const u8 =
    \\#version 330 core
    \\in vec3 vWorldPos;
    \\in vec3 vNormal;
    \\in vec2 vUV;
    \\in vec3 vColor;
    \\
    \\uniform vec3 uLightDir;
    \\uniform vec3 uEyePos;
    \\uniform float uAmbient;
    \\uniform float uSpecular;
    \\
    \\out vec4 FragColor;
    \\
    \\void main() {
    \\    vec3 norm = normalize(vNormal);
    \\    vec3 lightDir = normalize(uLightDir);
    \\    
    \\    // Diffuse with slight wrap lighting for smooth appearance
    \\    float NdotL = max(dot(norm, lightDir), 0.0);
    \\    float diff = NdotL * 0.75 + 0.05;
    \\    
    \\    // Specular (Blinn-Phong)
    \\    vec3 viewDir = normalize(uEyePos - vWorldPos);
    \\    vec3 halfwayDir = normalize(lightDir + viewDir);
    \\    float spec = pow(max(dot(norm, halfwayDir), 0.0), 24.0) * uSpecular;
    \\    
    \\    // Combine lighting
    \\    vec3 lighting = vec3(uAmbient) + vec3(diff) + vec3(spec);
    \\    vec3 result = vColor * lighting;
    \\    
    \\    FragColor = vec4(result, 1.0);
    \\}
;

const GRID_VERT_SHADER: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\uniform mat4 uMVP;
    \\out vec3 vPos;
    \\void main() {
    \\    vPos = aPos;
    \\    gl_Position = uMVP * vec4(aPos, 1.0);
    \\}
;

const GRID_FRAG_SHADER: [:0]const u8 =
    \\#version 330 core
    \\in vec3 vPos;
    \\out vec4 FragColor;
    \\void main() {
    \\    // Clean printer grid: 10mm minor lines, 50mm major lines
    \\    float grid10 = max(1.0 - abs(fract(vPos.x / 10.0 + 0.5) - 0.5) * 24.0, 1.0 - abs(fract(vPos.y / 10.0 + 0.5) - 0.5) * 24.0);
    \\    float grid50 = max(1.0 - abs(fract(vPos.x / 50.0 + 0.5) - 0.5) * 32.0, 1.0 - abs(fract(vPos.y / 50.0 + 0.5) - 0.5) * 32.0);
    \\    grid10 = clamp(grid10, 0.0, 1.0);
    \\    grid50 = clamp(grid50, 0.0, 1.0);
    \\    
    \\    vec3 baseColor = vec3(0.12, 0.13, 0.16);
    \\    vec3 line10 = vec3(0.20, 0.22, 0.28);
    \\    vec3 line50 = vec3(0.32, 0.36, 0.44);
    \\    
    \\    vec3 col = mix(baseColor, line10, grid10 * 0.45);
    \\    col = mix(col, line50, grid50 * 0.85);
    \\    FragColor = vec4(col, 1.0);
    \\}
;

const QUAD_VERT_SHADER: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in vec2 aUV;
    \\out vec2 vUV;
    \\void main() {
    \\    vUV = aUV;
    \\    gl_Position = vec4(aPos, 0.0, 1.0);
    \\}
;

const QUAD_FRAG_SHADER: [:0]const u8 =
    \\#version 330 core
    \\in vec2 vUV;
    \\uniform sampler2D uTexture;
    \\out vec4 FragColor;
    \\void main() {
    \\    FragColor = texture(uTexture, vUV);
    \\}
;

pub const Renderer = struct {
    gpu_mesh: GPUMesh,
    mesh_program: c.GLuint = 0,
    grid_program: c.GLuint = 0,
    quad_program: c.GLuint = 0,

    grid_vao: c.GLuint = 0,
    grid_vbo: c.GLuint = 0,
    quad_vao: c.GLuint = 0,
    quad_vbo: c.GLuint = 0,

    optical_texture: gl.Texture2D,
    fbo: Framebuffer,

    wireframe: bool = false,
    show_grid: bool = true,
    light_dir: Vec3 = .{ .x = 0.5, .y = -0.7, .z = 1.0 },
    ambient_strength: f32 = 0.40,
    specular_strength: f32 = 0.30,

    pub fn init(initial_w: i32, initial_h: i32) !Renderer {
        const mesh_prog = try gl.createShaderProgram(MESH_VERT_SHADER, MESH_FRAG_SHADER);
        const grid_prog = try gl.createShaderProgram(GRID_VERT_SHADER, GRID_FRAG_SHADER);
        const quad_prog = try gl.createShaderProgram(QUAD_VERT_SHADER, QUAD_FRAG_SHADER);

        // Grid plate geometry (256x256mm standard build volume)
        var g_vao: c.GLuint = 0;
        var g_vbo: c.GLuint = 0;
        c.glGenVertexArrays(1, &g_vao);
        c.glGenBuffers(1, &g_vbo);
        c.glBindVertexArray(g_vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, g_vbo);

        const grid_size: f32 = 128.0;
        const grid_verts = [_]f32{
            -grid_size, -grid_size, -0.05,
             grid_size, -grid_size, -0.05,
             grid_size,  grid_size, -0.05,
            -grid_size, -grid_size, -0.05,
             grid_size,  grid_size, -0.05,
            -grid_size,  grid_size, -0.05,
        };
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(grid_verts)), &grid_verts, c.GL_STATIC_DRAW);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
        c.glBindVertexArray(0);

        // Quad geometry for 2D optical texture preview
        var q_vao: c.GLuint = 0;
        var q_vbo: c.GLuint = 0;
        c.glGenVertexArrays(1, &q_vao);
        c.glGenBuffers(1, &q_vbo);
        c.glBindVertexArray(q_vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, q_vbo);

        const quad_verts = [_]f32{
            -0.95, -0.95,  0.0, 1.0,
             0.95, -0.95,  1.0, 1.0,
             0.95,  0.95,  1.0, 0.0,
            -0.95, -0.95,  0.0, 1.0,
             0.95,  0.95,  1.0, 0.0,
            -0.95,  0.95,  0.0, 0.0,
        };
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(quad_verts)), &quad_verts, c.GL_STATIC_DRAW);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 4 * @sizeOf(f32), null);
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 4 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
        c.glBindVertexArray(0);

        return .{
            .gpu_mesh = GPUMesh.init(),
            .mesh_program = mesh_prog,
            .grid_program = grid_prog,
            .quad_program = quad_prog,
            .grid_vao = g_vao,
            .grid_vbo = g_vbo,
            .quad_vao = q_vao,
            .quad_vbo = q_vbo,
            .optical_texture = gl.Texture2D.init(),
            .fbo = Framebuffer.init(initial_w, initial_h),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.gpu_mesh.deinit();
        self.optical_texture.deinit();
        self.fbo.deinit();

        if (self.mesh_program != 0) c.glDeleteProgram(self.mesh_program);
        if (self.grid_program != 0) c.glDeleteProgram(self.grid_program);
        if (self.quad_program != 0) c.glDeleteProgram(self.quad_program);

        if (self.grid_vao != 0) {
            c.glDeleteVertexArrays(1, &self.grid_vao);
            c.glDeleteBuffers(1, &self.grid_vbo);
        }
        if (self.quad_vao != 0) {
            c.glDeleteVertexArrays(1, &self.quad_vao);
            c.glDeleteBuffers(1, &self.quad_vbo);
        }
    }

    pub fn render3DToFBO(self: *Renderer, vp_w: i32, vp_h: i32, camera: *const Camera) void {
        self.fbo.resize(vp_w, vp_h);
        self.fbo.bind();

        c.glClearColor(0.09, 0.10, 0.12, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        c.glEnable(c.GL_DEPTH_TEST);
        c.glDepthFunc(c.GL_LESS);

        const aspect = if (vp_h > 0) @as(f32, @floatFromInt(vp_w)) / @as(f32, @floatFromInt(vp_h)) else 1.0;
        const view = camera.getViewMatrix();
        const proj = camera.getProjectionMatrix(aspect, 1.0, 5000.0);
        const mvp = camera_mod.mat4Mul(proj, view);

        var model = [_]f32{0.0} ** 16;
        model[0] = 1.0; model[5] = 1.0; model[10] = 1.0; model[15] = 1.0;

        // 1. Draw Build Plate Grid
        if (self.show_grid) {
            c.glUseProgram(self.grid_program);
            const u_grid_mvp = c.glGetUniformLocation(self.grid_program, "uMVP");
            c.glUniformMatrix4fv(u_grid_mvp, 1, c.GL_FALSE, &mvp[0]);

            c.glBindVertexArray(self.grid_vao);
            c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
            c.glBindVertexArray(0);
        }

        // 2. Draw Relief Mesh
        c.glUseProgram(self.mesh_program);
        const u_mvp = c.glGetUniformLocation(self.mesh_program, "uMVP");
        const u_model = c.glGetUniformLocation(self.mesh_program, "uModel");
        const u_light = c.glGetUniformLocation(self.mesh_program, "uLightDir");
        const u_eye = c.glGetUniformLocation(self.mesh_program, "uEyePos");
        const u_amb = c.glGetUniformLocation(self.mesh_program, "uAmbient");
        const u_spec = c.glGetUniformLocation(self.mesh_program, "uSpecular");

        c.glUniformMatrix4fv(u_mvp, 1, c.GL_FALSE, &mvp[0]);
        c.glUniformMatrix4fv(u_model, 1, c.GL_FALSE, &model[0]);
        c.glUniform3f(u_light, self.light_dir.x, self.light_dir.y, self.light_dir.z);

        const eye = camera.getEyePosition();
        c.glUniform3f(u_eye, eye.x, eye.y, eye.z);
        c.glUniform1f(u_amb, self.ambient_strength);
        c.glUniform1f(u_spec, self.specular_strength);

        if (self.wireframe) {
            c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
        } else {
            c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_FILL);
        }

        self.gpu_mesh.draw();

        c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_FILL);
        c.glUseProgram(0);

        self.fbo.unbind();
    }

    pub fn render2DToFBO(self: *Renderer, vp_w: i32, vp_h: i32) void {
        self.fbo.resize(vp_w, vp_h);
        self.fbo.bind();

        c.glClearColor(0.07, 0.08, 0.10, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glDisable(c.GL_DEPTH_TEST);

        c.glUseProgram(self.quad_program);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.optical_texture.id);

        const u_tex = c.glGetUniformLocation(self.quad_program, "uTexture");
        c.glUniform1i(u_tex, 0);

        c.glBindVertexArray(self.quad_vao);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
        c.glBindVertexArray(0);

        c.glBindTexture(c.GL_TEXTURE_2D, 0);
        c.glUseProgram(0);

        self.fbo.unbind();
    }
};
