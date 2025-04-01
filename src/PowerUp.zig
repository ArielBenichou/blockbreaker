const GameObject = @import("GameObject.zig");
const Texture = @import("Texture.zig");
const zmx = @import("zmx.zig");
const zm = @import("zmath");

const Self = @This();

game_object: GameObject,
is_active: bool,
powerup_type: PowerUpType,

pub fn init(
    position: zmx.Vec2,
    size: zmx.Vec2,
    texture: Texture,
    power_up_type: PowerUpType,
) Self {
    var self = Self{
        .powerup_type = power_up_type,
        .game_object = GameObject.init(
            position,
            size,
            texture,
            power_up_type.color(),
        ),
        .is_active = true,
    };
    self.game_object.velocity[1] = 200;
    return self;
}

pub fn reuse(
    self: *Self,
    position: zmx.Vec2,
    size: zmx.Vec2,
    texture: Texture,
    power_up_type: PowerUpType,
) void {
    self.game_object.position = position;
    self.game_object.size = size;
    self.game_object.texture = texture;
    self.game_object.color = power_up_type.color();
    self.powerup_type = power_up_type;
    self.is_active = true;
}

pub fn update(self: *Self, dt: f32, screen_height: f32) void {
    if (!self.is_active) return;
    self.game_object.position += zm.splat(zmx.Vec2, dt) * self.game_object.velocity;
    if (self.game_object.position[1] + self.game_object.size[1] > screen_height) {
        self.is_active = false;
    }
}

pub const PowerUpType = enum {
    speed,
    sticky,
    passthrough,
    increase,
    confuse,
    chaos,

    pub fn color(self: PowerUpType) zmx.Vec3 {
        return switch (self) {
            .speed => .{ 0.5, 0.5, 1.0 }, // blue
            .sticky => .{ 1.0, 0.5, 1.0 }, // purple
            .passthrough => .{ 0.5, 1.0, 0.5 }, // green
            .increase => .{ 1.0, 1.0, 1.0 }, // white
            .confuse => .{ 1.0, 1.0, 1.0 }, // white
            .chaos => .{ 1.0, 0.0, 0.0 }, // red
        };
    }

    pub fn name(self: PowerUpType) [:0]const u8 {
        return switch (self) {
            .speed => "powerup_speed",
            .sticky => "powerup_sticky",
            .passthrough => "powerup_passthrough",
            .increase => "powerup_increase",
            .confuse => "powerup_confuse",
            .chaos => "powerup_chaos",
        };
    }

    pub fn duration(self: PowerUpType) f32 {
        return switch (self) {
            .speed => 5,
            .sticky => 20,
            .passthrough => 10,
            .increase => 20,
            .confuse => 15,
            .chaos => 15,
        };
    }
};
