const std = @import("std");
const gl = @import("zopengl").bindings;
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");
const zm = @import("zmath");
const Self = @This();
postprocessing_shader: Shader,
texture: Texture,
width: gl.Uint,
height: gl.Uint,
confuse: bool,
shake: bool,
chaos: bool,

msfbo: gl.Uint,
fbo: gl.Uint,
rbo: gl.Uint,
vao: gl.Uint,

pub fn init(shader: Shader, width: u32, height: u32) Self {
    var self = Self{
        .width = @intCast(width),
        .height = @intCast(height),
        .postprocessing_shader = shader,
        .texture = Texture.init(),
        .confuse = false,
        .shake = false,
        .chaos = false,
        .msfbo = undefined,
        .fbo = undefined,
        .rbo = undefined,
        .vao = undefined,
    };
    gl.genFramebuffers(1, &self.msfbo);
    gl.genFramebuffers(1, &self.fbo);
    gl.genRenderbuffers(1, &self.rbo);
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.msfbo);
    gl.bindRenderbuffer(gl.RENDERBUFFER, self.rbo);
    gl.renderbufferStorageMultisample(
        gl.RENDERBUFFER,
        4,
        gl.RGB,
        @intCast(self.width),
        @intCast(self.height),
    );
    gl.framebufferRenderbuffer(
        gl.FRAMEBUFFER,
        gl.COLOR_ATTACHMENT0,
        gl.RENDERBUFFER,
        self.rbo,
    );
    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        std.log.err("ERROR::POSTPROCESSOR: Failed to initialize MSFBO\n", .{});
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.fbo);
    self.texture.generate(self.width, self.height, null);
    gl.framebufferTexture2D(
        gl.FRAMEBUFFER,
        gl.COLOR_ATTACHMENT0,
        gl.TEXTURE_2D,
        self.texture.id,
        0,
    );
    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        std.log.err("ERROR::POSTPROCESSOR: Failed to initialize FBO\n", .{});
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    self.initRenderData();
    self.postprocessing_shader.setInteger("scene", 0, true);
    // the '300' is kind of the strengh is think, small is stronger
    const offset: gl.Float = 1 / 300;
    // zig fmt: off
    const offsets = [9][2]gl.Float{
        .{ -offset,  offset  },  // top-left
        .{  0.0,     offset  },  // top-center
        .{  offset,  offset  },  // top-right
        .{ -offset,  0.0     },  // center-left
        .{  0.0,     0.0     },  // center-center
        .{  offset,  0.0     },  // center - right
        .{ -offset, -offset  },  // bottom-left
        .{  0.0,    -offset  },  // bottom-center
        .{  offset, -offset  },   // bottom-right     
    };
    // zig fmt: on
    gl.uniform2fv(
        gl.getUniformLocation(self.postprocessing_shader.id, "offsets"),
        9,
        @ptrCast(&offsets),
    );
    // zig fmt: off
    const edge_kernel = [9]gl.Int{
        -1, -1, -1,
        -1,  9, -1,
        -1, -1, -1,
    };
    // zig fmt: on
    gl.uniform1iv(
        gl.getUniformLocation(self.postprocessing_shader.id, "edge_kernel"),
        9,
        &edge_kernel,
    );
    // zig fmt: off
    const blur_kernel = [9]gl.Float{
        1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0,
        2.0 / 16.0, 4.0 / 16.0, 2.0 / 16.0,
        1.0 / 16.0, 2.0 / 16.0, 1.0 / 16.0,
    };
    // zig fmt: on
    gl.uniform1fv(
        gl.getUniformLocation(self.postprocessing_shader.id, "blur_kernel"),
        9,
        &blur_kernel,
    );
    return self;
}

pub fn beginRender(self: *Self) void {
    gl.bindFramebuffer(gl.FRAMEBUFFER, self.msfbo);
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
}

pub fn endRender(self: *Self) void {
    gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self.msfbo);
    gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, self.fbo);
    gl.blitFramebuffer(
        0,
        0,
        @intCast(self.width),
        @intCast(self.height),
        0,
        0,
        @intCast(self.width),
        @intCast(self.height),
        gl.COLOR_BUFFER_BIT,
        gl.NEAREST,
    );
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
}

pub fn render(self: *Self, time: f32) void {
    self.postprocessing_shader.use();
    self.postprocessing_shader.setFloat("time", time, false);
    self.postprocessing_shader.setBoolean("confuse", self.confuse, false);
    self.postprocessing_shader.setBoolean("shake", self.shake, false);
    self.postprocessing_shader.setBoolean("chaos", self.chaos, false);
    gl.activeTexture(gl.TEXTURE0);
    self.texture.bind();
    gl.bindVertexArray(self.vao);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    gl.bindVertexArray(0);
}

pub fn initRenderData(self: *Self) void {
    var vbo: gl.Uint = undefined;
    // zig fmt: off
    const vertices = [_]gl.Float{
        // pos   // tex
        -1, -1,  0, 0,
         1,  1,  1, 1,
        -1,  1,  0, 1,

        -1, -1,  0, 0,
         1, -1,  1, 0,
         1,  1,  1, 1,
    };
    // zig fmt: off
    gl.genVertexArrays(1, &self.vao);
    gl.genBuffers(1, &vbo);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(gl.Float), &vertices, gl.STATIC_DRAW);

    gl.bindVertexArray(self.vao);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, 4 * @sizeOf(gl.Float), null,);

    gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bindVertexArray(0);
}
