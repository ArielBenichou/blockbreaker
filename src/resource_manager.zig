const std = @import("std");
const gl = @import("zopengl").bindings;
const stbi = @import("zstbi");
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");

pub const ResourceManager = struct {
    const Self = @This();

    // Data
    shaders: std.StringHashMap(Shader),
    textures: std.StringHashMap(Texture),
    allocator: std.mem.Allocator,

    // Public
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .shaders = std.StringHashMap(Shader).init(allocator),
            .textures = std.StringHashMap(Texture).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        {
            var it = self.shaders.valueIterator();
            while (it.next()) |shader| {
                shader.deinit();
            }
            self.shaders.deinit();
        }

        {
            var it = self.textures.valueIterator();
            while (it.next()) |texture| {
                texture.deinit();
            }
            self.textures.deinit();
        }
    }

    pub fn loadShader(
        self: *Self,
        name: [:0]const u8,
        v_path: [:0]const u8,
        f_path: [:0]const u8,
        g_path: ?[:0]const u8,
    ) !Shader {
        const shader = try Self.loadShaderFromFile(
            self.allocator,
            v_path,
            f_path,
            g_path,
        );
        try self.shaders.put(name, shader);
        return shader;
    }

    pub fn getShader(self: Self, name: [:0]const u8) Shader {
        return self.shaders.get(name) orelse unreachable;
    }

    pub fn loadTexture(self: *Self, path: [:0]const u8, name: [:0]const u8, with_alpha: bool) !Texture {
        const texture = try Self.loadTextureFromFile(path, with_alpha);
        try self.textures.put(name, texture);
        return texture;
    }

    pub fn getTexture(self: Self, name: [:0]const u8) Texture {
        return self.textures.get(name) orelse unreachable;
    }

    fn loadShaderFromFile(allocator: std.mem.Allocator, v_path: [:0]const u8, f_path: [:0]const u8, g_path: ?[:0]const u8) !Shader {
        const MAX_FILE_SIZE = ((1 << 10) << 10) * 1; // 1 MB
        const v_code = str: {
            const file = try std.fs.cwd().openFile(v_path, .{});
            defer file.close();
            const contents = try file.readToEndAlloc(allocator, MAX_FILE_SIZE);
            break :str contents;
        };
        const f_code = str: {
            const file = try std.fs.cwd().openFile(f_path, .{});
            defer file.close();
            const contents = try file.readToEndAlloc(allocator, MAX_FILE_SIZE);
            break :str contents;
        };
        const g_code = if (g_path) |path| str: {
            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();
            const contents = try file.readToEndAlloc(allocator, MAX_FILE_SIZE);
            break :str contents;
        } else null;
        const shader = Shader.init();
        shader.compile(v_code, f_code, g_code);
        return shader;
    }

    fn loadTextureFromFile(path: [:0]const u8, with_alpha: bool) !Texture {
        var texture = Texture.init();
        if (with_alpha) {
            texture.internal_format = gl.RGBA;
            texture.image_format = gl.RGBA;
        }

        var image = try stbi.Image.loadFromFile(path, 0);
        defer image.deinit();

        texture.generate(image.width, image.height, image.data);
        return texture;
    }
};
