const std = @import("std");
const math = std.math;
const gl = @import("zopengl").bindings;
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");
const zmx = @import("zmx.zig");
const zm = @import("zmath");

const Self = @This();

shader: Shader,
quad_vao: gl.Uint,

pub fn init(shader: Shader) Self {
    var self = Self{
        .shader = shader,
        .quad_vao = 0,
    };
    self.initRenderData();
    return self;
}

pub fn deinit(self: Self) void {
    gl.deleteVertexArrays(1, &self.quad_vao);
}

pub fn drawSprite(
    self: Self,
    texture: Texture,
    position: zmx.Vec2,
    size: zmx.Vec2,
    rotate: f32,
    color: zmx.Vec3,
) void {
    self.shader.use();
    var model = zm.identity();

    model = zm.mul(model, zm.scaling(size[0], size[1], 1.0));

    // move the origin to the center of the sprite
    model = zm.mul(model, zm.translation(-0.5 * size[0], -0.5 * size[1], 0.0));
    // rotate the sprite
    model = zm.mul(model, zm.rotationZ(math.degreesToRadians(rotate)));
    // move the origin back to the top-left corner
    model = zm.mul(model, zm.translation(0.5 * size[0], 0.5 * size[1], 0.0));

    model = zm.mul(model, zm.translation(position[0], position[1], 0.0));

    self.shader.setMatrix("model", model, false);
    self.shader.setVector3fv("spriteColor", color, false);

    gl.activeTexture(gl.TEXTURE0);
    texture.bind();

    {
        gl.bindVertexArray(self.quad_vao);
        defer gl.bindVertexArray(0);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
    }
}

fn initRenderData(self: *Self) void {
    // zig fmt: off
    // NOTE: here we have 0,0 as the top-left origin 'anchor' point
    const  vertices = [_]f32{ 
        // pos      // tex
        0.0, 1.0,   0.0, 1.0,
        1.0, 0.0,   1.0, 0.0,
        0.0, 0.0,   0.0, 0.0, 
    
        0.0, 1.0,   0.0, 1.0,
        1.0, 1.0,   1.0, 1.0,
        1.0, 0.0,   1.0, 0.0
    };
    // zig fmt: on

    gl.genVertexArrays(1, &self.quad_vao);

    var vbo: gl.Uint = undefined;
    gl.genBuffers(1, &vbo);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    defer gl.bindBuffer(gl.ARRAY_BUFFER, 0);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @sizeOf(f32) * vertices.len,
        @ptrCast(&vertices),
        gl.STATIC_DRAW,
    );

    gl.bindVertexArray(self.quad_vao);
    defer gl.bindVertexArray(0);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(
        0,
        4,
        gl.FLOAT,
        gl.FALSE,
        4 * @sizeOf(f32),
        @ptrFromInt(0),
    );
}
