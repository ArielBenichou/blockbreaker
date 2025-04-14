const c = @import("c.zig").c;

const Self = @This();

face: c.FT_Face,

pub fn deinit(self: Self) !void {
    if (c.FT_Done_Face(self.face) != 0) {
        return error.FailedDeinitFontFace;
    }
}

/// The function sets the font's width and height parameters (in pixels).
/// Setting the width to 0 lets the face dynamically calculate the width based on the given height.
pub fn setPixelSizes(self: Self, width: c_uint, height: c_uint) !void {
    if (c.FT_Set_Pixel_Sizes(self.face, width, height) != 0) {
        return error.FailedSetPixelSizes;
    }
}

const LoadFlag = enum(c_int) {
    Render = c.FT_LOAD_RENDER,
};
pub fn loadChar(self: Self, char: u8, flag: LoadFlag) !void {
    if (c.FT_Load_Char(self.face, @intCast(char), @intFromEnum(flag)) != 0) {
        return error.GlyphLoadFailed;
    }
}
