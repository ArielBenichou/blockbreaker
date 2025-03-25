const gl = @import("zopengl").bindings;

const Self = @This();

id: gl.Uint,
width: gl.Uint,
height: gl.Uint,
internal_format: gl.Uint,
image_format: gl.Uint,
wrap_s: gl.Uint,
wrap_t: gl.Uint,
filter_min: gl.Uint,
filter_max: gl.Uint,

pub fn init() Self {
    return .{
        .id = gl.createTexture(),
        .width = 0,
        .height = 0,
        .internal_format = gl.RGB,
        .image_format = gl.RGB,
        .wrap_s = gl.REPEAT,
        .wrap_t = gl.REPEAT,
        .filter_min = gl.LINEAR,
        .filter_max = gl.LINEAR,
    };
}

pub fn deinit(self: Self) void {
    gl.deleteTextures(1, &self.id);
}

pub fn generate(self: Self, width: gl.Uint, height: gl.Uint, data: *const anyopaque) void {
    self.width = width;
    self.height = height;

    gl.bindTexture(gl.TEXTURE_2D, self.id);
    gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        self.internal_format,
        width,
        height,
        0,
        self.image_format,
        gl.UNSIGNED_BYTE,
        data,
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, self.wrap_s);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, self.wrap_t);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, self.filter_min);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, self.filter_max);
    // unbind
    gl.bindTexture(gl.TEXTURE_2D, null);
}

pub fn bind(self: Self) void {
    gl.bindTexture(gl.TEXTURE_2D, self.id);
}
