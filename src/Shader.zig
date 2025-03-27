const std = @import("std");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const zmx = @import("zmx.zig");

const Self = @This();

id: gl.Uint,

pub fn init() Self {
    const id = gl.createProgram();
    return Self{
        .id = id,
    };
}

pub fn deinit(self: Self) void {
    gl.deleteProgram(self.id);
}

pub fn use(self: Self) void {
    gl.useProgram(self.id);
}

pub fn compile(
    self: Self,
    vertex_source: []u8,
    fragment_source: []u8,
    geometry_source: ?[]u8,
) void {
    var vertex_shader: gl.Uint = undefined;
    var fragment_shader: gl.Uint = undefined;
    var geometry_shader: gl.Uint = undefined;

    // Vertex Shader
    vertex_shader = gl.createShader(gl.VERTEX_SHADER);
    const vertex_source_c: [*c]u8 = @ptrCast(vertex_source.ptr);
    gl.shaderSource(vertex_shader, 1, &vertex_source_c, null);
    gl.compileShader(vertex_shader);
    Self.checkCompileErrors(vertex_shader, "VERTEX");

    // Fragment Shader
    fragment_shader = gl.createShader(gl.FRAGMENT_SHADER);
    const fragment_source_c: [*c]u8 = @ptrCast(fragment_source.ptr);
    gl.shaderSource(fragment_shader, 1, &fragment_source_c, null);
    gl.compileShader(fragment_shader);
    Self.checkCompileErrors(fragment_shader, "FRAGMENT");

    // Geometry Shader
    if (geometry_source) |source| {
        geometry_shader = gl.createShader(gl.GEOMETRY_SHADER);
        const geometry_source_c: [*c]u8 = @ptrCast(source.ptr);
        gl.shaderSource(geometry_shader, 1, &geometry_source_c, null);
        gl.compileShader(geometry_shader);
        Self.checkCompileErrors(geometry_shader, "GEOMETRY");
    }

    // Link shaders
    gl.attachShader(self.id, vertex_shader);
    gl.attachShader(self.id, fragment_shader);
    if (geometry_source != null) {
        gl.attachShader(self.id, geometry_shader);
    }
    gl.linkProgram(self.id);
    Self.checkCompileErrors(self.id, "PROGRAM");

    // Clean up
    gl.deleteShader(vertex_shader);
    gl.deleteShader(fragment_shader);
    if (geometry_source != null) {
        gl.deleteShader(geometry_shader);
    }
}

pub fn setFloat(self: Self, name: [:0]const u8, value: f32, use_shader: bool) void {
    if (use_shader) self.use();
    gl.uniform1f(
        gl.getUniformLocation(self.id, name),
        value,
    );
}

pub fn setInteger(self: Self, name: [:0]const u8, value: i32, use_shader: bool) void {
    if (use_shader) self.use();
    gl.uniform1i(
        gl.getUniformLocation(self.id, name),
        value,
    );
}

pub fn setVector2f(self: Self, name: [:0]const u8, x: f32, y: f32, use_shader: bool) void {
    if (use_shader) self.use();
    gl.uniform2f(
        gl.getUniformLocation(self.id, name),
        x,
        y,
    );
}

pub fn setVector2fv(self: Self, name: [:0]const u8, value: zmx.Vec2, use_shader: bool) void {
    if (use_shader) self.use();
    var arr: [2]f32 = .{ value[0], value[1] };
    gl.uniform2fv(
        gl.getUniformLocation(self.id, name),
        1,
        &arr,
    );
}

pub fn setVector3f(self: Self, name: [:0]const u8, x: f32, y: f32, z: f32, use_shader: bool) void {
    if (use_shader) self.use();
    gl.uniform3f(
        gl.getUniformLocation(self.id, name),
        x,
        y,
        z,
    );
}

pub fn setVector3fv(self: Self, name: [:0]const u8, value: zmx.Vec3, use_shader: bool) void {
    if (use_shader) self.use();
    var arr: [3]f32 = .{ value[0], value[1], value[2] };
    gl.uniform3fv(
        gl.getUniformLocation(self.id, name),
        1,
        &arr,
    );
}

pub fn setVector4f(self: Self, name: [:0]const u8, x: f32, y: f32, z: f32, w: f32, use_shader: bool) void {
    if (use_shader) self.use();
    gl.uniform4f(
        gl.getUniformLocation(self.id, name),
        x,
        y,
        z,
        w,
    );
}

pub fn setVector4fv(self: Self, name: [:0]const u8, value: zm.Vec, use_shader: bool) void {
    if (use_shader) self.use();
    var arr: [4]f32 = .{ value[0], value[1], value[2], value[3] };
    gl.uniform4fv(
        gl.getUniformLocation(self.id, name),
        1,
        &arr,
    );
}

pub fn setMatrix(self: Self, name: [:0]const u8, value: zm.Mat, use_shader: bool) void {
    if (use_shader) self.use();
    var mat: [16]f32 = undefined;
    zm.storeMat(&mat, value);
    gl.uniformMatrix4fv(
        gl.getUniformLocation(self.id, name),
        1,
        gl.FALSE,
        &mat,
    );
}

fn checkCompileErrors(object: u32, t: [:0]const u8) void {
    var success: gl.Int = 0;
    var info_log: [1024]u8 = undefined;
    if (!std.mem.eql(u8, t, "PROGRAM")) {
        gl.getShaderiv(object, gl.COMPILE_STATUS, &success);
        if (success == gl.FALSE) {
            gl.getShaderInfoLog(object, 1024, null, &info_log);
            std.log.warn("| ERROR::SHADER: Compile-time error: Type: {s}\n--------------------------------\n{s}\n", .{ t, info_log });
        }
    } else {
        gl.getProgramiv(object, gl.LINK_STATUS, &success);
        if (success == gl.FALSE) {
            gl.getProgramInfoLog(object, 1024, null, &info_log);
            std.log.warn("| ERROR::PROGRAM: Link-time error: Type: {s}\n--------------------------------\n{s}\n", .{ t, info_log });
        }
    }
}
