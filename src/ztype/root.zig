const c = @import("c.zig").c;
const FontFace = @import("FontFace.zig");

const Self = @This();

ft: c.FT_Library,

pub fn init() !Self {
    var ft: c.FT_Library = undefined;
    if (c.FT_Init_FreeType(&ft) != 0) {
        return error.FreeTypeInitFailed;
    }
    return .{
        .ft = ft,
    };
}

pub fn loadFont(self: Self, path: []const u8) !FontFace {
    var face: c.FT_Face = undefined;
    if (c.FT_New_Face(self.ft, path.ptr, 0, &face) != 0) {
        return error.LoadFontFailed;
    }
    return FontFace{
        .face = face,
    };
}
