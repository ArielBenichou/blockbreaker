const zmx = @import("zmx.zig");
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
    return Self{
        .position = .{ 0, 0 },
        .size = .{ 1, 1 },
        .velocity = .{ 0, 0 },
        .rotation = 0.0,
        .color = .{ 1, 1, 1 },
        .is_solid = false,
        .is_destroyed = false,
        .texture = texture,
    };
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
