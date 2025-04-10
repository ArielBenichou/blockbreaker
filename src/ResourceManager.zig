const std = @import("std");
const zaudio = @import("zaudio");
const Sound = zaudio.Sound;
const gl = @import("zopengl").bindings;
const stbi = @import("zstbi");
const Shader = @import("Shader.zig");
const Texture = @import("Texture.zig");

const Self = @This();

// Data
shaders: std.StringHashMap(Shader),
textures: std.StringHashMap(Texture),
allocator: std.mem.Allocator,
sounds: std.StringHashMap(*Sound),
engine: *zaudio.Engine,

// Public
pub fn init(allocator: std.mem.Allocator, engine: *zaudio.Engine) Self {
    return Self{
        .shaders = std.StringHashMap(Shader).init(allocator),
        .textures = std.StringHashMap(Texture).init(allocator),
        .sounds = std.StringHashMap(*Sound).init(allocator),
        .allocator = allocator,
        .engine = engine,
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

    {
        var it = self.sounds.valueIterator();
        while (it.next()) |sound| {
            sound.*.destroy();
        }
        self.sounds.deinit();
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
    return self.shaders.get(name) orelse {
        std.log.warn("Shader not found: '{s}'", .{name});
        unreachable;
    };
}

pub fn loadTexture(self: *Self, path: [:0]const u8, name: [:0]const u8, with_alpha: bool) !Texture {
    const texture = try Self.loadTextureFromFile(path, with_alpha);
    try self.textures.put(name, texture);
    return texture;
}

pub fn getTexture(self: Self, name: [:0]const u8) Texture {
    return self.textures.get(name) orelse {
        std.log.warn("Texture not found: '{s}'", .{name});
        unreachable;
    };
}

pub fn loadSound(self: *Self, path: [:0]const u8, name: [:0]const u8) !*Sound {
    const sound = try self.engine.createSoundFromFile(
        path,
        .{ .flags = .{ .stream = true } },
    );
    try self.sounds.put(name, sound);
    return sound;
}

pub fn getSound(self: Self, name: [:0]const u8) *Sound {
    return self.sounds.get(name) orelse {
        std.log.warn("Sound not found: '{s}'", .{name});
        unreachable;
    };
}

fn loadShaderFromFile(allocator: std.mem.Allocator, v_path: [:0]const u8, f_path: [:0]const u8, g_path: ?[:0]const u8) !Shader {
    const MAX_FILE_SIZE = ((1 << 10) << 10) * 1; // 1 MB
    const v_code = try std.fs.cwd().readFileAlloc(
        allocator,
        v_path,
        MAX_FILE_SIZE,
    );
    defer allocator.free(v_code);
    const f_code = try std.fs.cwd().readFileAlloc(
        allocator,
        f_path,
        MAX_FILE_SIZE,
    );
    defer allocator.free(f_code);
    const g_code = if (g_path) |path| try std.fs.cwd().readFileAlloc(
        allocator,
        path,
        MAX_FILE_SIZE,
    ) else null;
    defer if (g_code) |code| allocator.free(code);
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

    var image = stbi.Image.loadFromFile(path, 0) catch |err| {
        return switch (err) {
            error.ImageInitFailed => {
                std.log.err("Texture not found: '{s}'", .{path});
                unreachable;
            },
            else => return err,
        };
    };
    defer image.deinit();

    texture.generate(
        image.width,
        image.height,
        @ptrCast(image.data),
    );
    return texture;
}
