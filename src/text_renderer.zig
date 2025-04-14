const std = @import("std");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const FontFace = @import("ztype/FontFace.zig");
const Shader = @import("Shader.zig");
const ResourceManager = @import("ResourceManager.zig");
const ztype = @import("ztype/root.zig");

const CharMap = std.AutoHashMap(u8, Character);

const Character = struct {
    const Self = @This();

    texture_id: gl.Uint,
    size: struct { c_uint, c_uint },
    bearing: struct { c_int, c_int },
    advance: c_long,

    pub fn generateCharMap(allocator: std.mem.Allocator, face: FontFace) !CharMap {
        var characters = CharMap.init(allocator);

        gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1); // disable byte-alignment restriction

        for (0..128) |i| {
            const c: u8 = @intCast(i);
            face.loadChar(c, .Render) catch {
                std.log.err("FREETYPE: Failed to load Glyph", .{});
                continue;
            };
            var texture: gl.Uint = undefined;
            gl.genTextures(1, &texture);
            gl.bindTexture(gl.TEXTURE_2D, texture);
            const face_glyph = face.face.*.glyph.*;
            const face_bitmap = face_glyph.bitmap;
            gl.texImage2D(
                gl.TEXTURE_2D,
                0,
                gl.RED,
                @intCast(face_bitmap.width),
                @intCast(face_bitmap.rows),
                0,
                gl.RED,
                gl.UNSIGNED_BYTE,
                face_bitmap.buffer,
            );
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
            try characters.put(
                c,
                Self{
                    .texture_id = texture,
                    .size = .{ face_bitmap.width, face_bitmap.rows },
                    .bearing = .{ face_glyph.bitmap_left, face_glyph.bitmap_top },
                    .advance = face_glyph.advance.x,
                },
            );
        }
        gl.bindTexture(gl.TEXTURE_2D, 0);
        return characters;
    }
};

pub const TextRenderer = struct {
    const Self = @This();

    vao: gl.Uint,
    vbo: gl.Uint,
    characters: CharMap,
    text_shader: Shader,

    pub fn init(
        resource_manager: *ResourceManager,
        width: u32,
        height: u32,
    ) !Self {
        const text_shader = try resource_manager.loadShader(
            "text",
            "res/shaders/text.vs.glsl",
            "res/shaders/text.fs.glsl",
            null,
        );
        text_shader.setMatrix(
            "projection",
            zm.orthographicOffCenterRhGl(
                0,
                @floatFromInt(width),
                @floatFromInt(height),
                0,
                0.1,
                1000,
            ),
            true,
        );
        text_shader.setInteger("text", 0, false);

        var vao: gl.Uint = undefined;
        gl.genVertexArrays(1, &vao);
        var vbo: gl.Uint = undefined;
        gl.genBuffers(1, &vbo);
        gl.bindVertexArray(vao);
        defer gl.bindVertexArray(0);
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        defer gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bufferData(gl.ARRAY_BUFFER, @sizeOf(gl.Float) * 6 * 4, null, gl.DYNAMIC_DRAW);
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(
            0,
            4,
            gl.FLOAT,
            gl.FALSE,
            4 * @sizeOf(gl.Float) * 4,
            @ptrFromInt(0),
        );

        return .{
            .text_shader = text_shader,
            .characters = undefined,
            .vao = vao,
            .vbo = vbo,
        };
    }

    pub fn deinit(self: *Self) void {
        self.characters.deinit();
    }

    pub fn load(self: *Self, allocator: std.mem.Allocator, font: []const u8, font_size: u32) !void {
        // TODO: probably need to clear and reset characters if load is called twice
        const ft = ztype.init() catch {
            std.log.err("FREETYPE: Could not init FreeType Library", .{});
            std.process.exit(1);
        };
        defer ft.deinit() catch unreachable;
        const fontface = try ft.loadFont(font);
        defer fontface.deinit() catch unreachable;
        try fontface.setPixelSizes(0, font_size);

        self.characters = try Character.generateCharMap(allocator, fontface);
    }

    pub fn renderText(
        self: Self,
        text: []const u8,
        x: f32,
        y: f32,
        scale: f32,
        color: ?struct { f32, f32, f32 },
    ) void {
        const text_color = color orelse .{ 0, 0, 0 };
        self.text_shader.use();
        self.text_shader.setVector3f("textColor", text_color[0], text_color[1], text_color[2], false);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindVertexArray(self.vao);
        defer gl.bindVertexArray(0);

        var my_x = x;

        for (0..text.len) |i| {
            const ch = self.characters.get(text[i]) orelse {
                std.log.warn("characters '{}' was not found in map", .{text[i]});
                continue;
            };
            const xpos = my_x + @as(f32, @floatFromInt(ch.bearing[0])) * scale;
            const ypos = y + @as(f32, @floatFromInt(self.characters.get('H').?.bearing[1] - ch.bearing[1])) * scale;

            const w = @as(f32, @floatFromInt(ch.size[0])) * scale;
            const h = @as(f32, @floatFromInt(ch.size[1])) * scale;
            // update VBO for each character
            // zig fmt: off
            const vertices = [6][4]f32{
                .{ xpos,     ypos + h,   0, 1, },
                .{ xpos + w, ypos,       1, 0, },
                .{ xpos,     ypos,       0, 0, },

                .{ xpos,     ypos + h,   0, 1, },
                .{ xpos + w, ypos + h,   1, 1, },
                .{ xpos + w, ypos,       1, 0, }
            };
            // zig fmt: on
            // render glyph texture over quad
            gl.bindTexture(gl.TEXTURE_2D, ch.texture_id);
            // update content of VBO memory
            gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
            gl.bufferSubData(gl.ARRAY_BUFFER, 0, @sizeOf(f32) * 6 * 4, &vertices); // be sure to use glBufferSubData and not glBufferData
            gl.bindBuffer(gl.ARRAY_BUFFER, 0);
            // render quad
            gl.drawArrays(gl.TRIANGLES, 0, 6);
            // now advance cursors for next glyph
            my_x += @as(f32, @floatFromInt(ch.advance >> 6)) * scale; // bitshift by 6 to get value in pixels (1/64th times 2^6 = 64)
        }
        gl.bindTexture(gl.TEXTURE_2D, 0);
    }
};
