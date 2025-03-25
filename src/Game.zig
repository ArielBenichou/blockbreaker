const std = @import("std");
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const SpriteRenderer = @import("SpriteRenderer.zig");
const ResourceManager = @import("ResourceManager.zig");
const GameLevel = @import("GameLevel.zig");
const GameObject = @import("GameObject.zig");
const zm = @import("zmath");
const glfw = @import("zglfw");
const glx = @import("glx.zig");
const gui = @import("zgui");
const zmx = @import("zmx.zig");

const Self = @This();

state: GameState,
renderer: ?SpriteRenderer,
levels: ArrayList(GameLevel),
level_index: usize,
player: GameObject,
player_vel: zmx.Vec2 = .{ 500, 0 },
/// reference to the resource manager singleton
resource_manager: *ResourceManager,
keys: [1024]bool,
width: u32,
height: u32,
allocator: std.mem.Allocator,

pub fn init(
    allocator: std.mem.Allocator,
    width: u32,
    height: u32,
    resource_manager: *ResourceManager,
) Self {
    return Self{
        .state = .active,
        .keys = [_]bool{false} ** 1024,
        .width = width,
        .height = height,
        .resource_manager = resource_manager,
        .renderer = null,
        .levels = ArrayList(GameLevel).init(allocator),
        .level_index = 0,
        .allocator = allocator,
        .player = undefined,
    };
}

pub fn deinit(self: Self) void {
    for (self.levels.items) |*level| {
        level.deinit();
    }
    self.levels.deinit();
}

pub fn prepare(self: *Self) !void {
    const sprite_shader = try self.resource_manager.loadShader(
        "sprite",
        "res/shaders/sprite.vs.glsl",
        "res/shaders/sprite.fs.glsl",
        null,
    );
    const proj = zm.orthographicOffCenterLhGl(
        0,
        @floatFromInt(self.width),
        0,
        @floatFromInt(self.height),
        -1,
        1,
    );
    sprite_shader.use();
    sprite_shader.setInteger("image", 0, false);
    sprite_shader.setMatrix("projection", proj, false);

    self.renderer = SpriteRenderer.init(sprite_shader);

    _ = try self.resource_manager.loadTexture(
        "res/sprites/background.jpg",
        "background",
        false,
    );
    _ = try self.resource_manager.loadTexture(
        "res/sprites/awesome_face.png",
        "face",
        true,
    );
    _ = try self.resource_manager.loadTexture(
        "res/sprites/block.png",
        "block",
        false,
    );
    _ = try self.resource_manager.loadTexture(
        "res/sprites/block_solid.png",
        "block_solid",
        false,
    );
    _ = try self.resource_manager.loadTexture(
        "res/sprites/paddle.png",
        "paddle",
        true,
    );

    const level_names = [_][]const u8{ "one", "two", "three", "four" };
    inline for (level_names) |level_name| {
        const path = "res/levels/" ++ level_name ++ ".lvl";
        var level = GameLevel.init(self.allocator);
        try level.load(
            self.resource_manager,
            path,
            @floatFromInt(self.width),
            @floatFromInt(self.height / 2),
        );
        try self.levels.append(level);
    }

    const player_size: zmx.Vec2 = .{ 100, 20 };
    const player_pos: zmx.Vec2 = .{
        @as(f32, @floatFromInt(self.width)) / 2 - player_size[0] / 2,
        @as(f32, @floatFromInt(self.height)) - player_size[1],
    };
    self.player = GameObject.init(
        player_pos,
        player_size,
        self.resource_manager.getTexture("paddle"),
        .{ 1, 1, 1 },
    );
}

pub fn update(self: Self, dt: f32) void {
    _ = self;
    _ = dt;
}

pub fn render(self: *Self) void {
    if (self.state == .active) {
        self.renderer.?.drawSprite(
            self.resource_manager.getTexture("background"),
            .{ 0, 0 },
            .{ @floatFromInt(self.width), @floatFromInt(self.height) },
            0,
            .{ 1, 1, 1 },
        );
        self.levels.items[self.level_index].draw(&self.renderer.?);
        self.player.draw(&self.renderer.?);
    }

    glx.glLogErrors(@src());
}

pub fn renderUI(self: *Self) void {
    _ = self;
}

pub fn processInput(self: *Self, dt: f32) void {
    if (self.state == .active) {
        const vel = self.player_vel * zm.splat(zmx.Vec2, dt);
        if (self.keys[@intFromEnum(glfw.Key.a)]) {
            if (self.player.position[0] >= 0) {
                self.player.position[0] -= vel[0];
            }
        }
        if (self.keys[@intFromEnum(glfw.Key.d)]) {
            if (self.player.position[0] <= @as(f32, @floatFromInt(self.width)) - self.player.size[0]) {
                self.player.position[0] += vel[0];
            }
        }
    }
}

pub const GameState = enum {
    active,
    menu,
    win,
};
