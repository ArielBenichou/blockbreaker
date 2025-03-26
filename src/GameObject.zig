const std = @import("std");
const zmx = @import("zmx.zig");
const zm = @import("zmath");
const SpriteRenderer = @import("SpriteRenderer.zig");
const Texture = @import("Texture.zig");

const Self = @This();

position: zmx.Vec2,
size: zmx.Vec2,
velocity: zmx.Vec2,
rotation: f32,
color: zmx.Vec3,
is_solid: bool,
is_destroyed: bool,
texture: Texture,

pub fn init(
    position: zmx.Vec2,
    size: zmx.Vec2,
    texture: Texture,
    color: zmx.Vec3,
) Self {
    return Self{
        .position = position,
        .size = size,
        .velocity = .{ 0, 0 },
        .rotation = 0.0,
        .color = color,
        .is_solid = false,
        .is_destroyed = false,
        .texture = texture,
    };
}

pub fn initDefault(texture: Texture) Self {
    return Self.init(
        zm.splat(zmx.Vec2, 0),
        zm.splat(zmx.Vec2, 1),
        texture,
        zmx.Vector(1, f32),
    );
}

pub fn draw(self: *Self, renderer: *SpriteRenderer) void {
    renderer.drawSprite(
        self.texture,
        self.position,
        self.size,
        self.rotation,
        self.color,
    );
}
