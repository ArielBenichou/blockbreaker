const GameObject = @import("GameObject.zig");
const Texture = @import("Texture.zig");
const zmx = @import("zmx.zig");
const zm = @import("zmath");

const Self = @This();

game_object: GameObject,
radius: f32,
is_stuck: bool,

pub fn init(position: zmx.Vec2, radius: f32, velocity: zmx.Vec2, texture: Texture) Self {
    const diameter = radius * 2;
    var ball = Self{
        .game_object = GameObject.init(
            position,
            zm.splat(zmx.Vec2, diameter),
            texture,
            zm.splat(zmx.Vec3, 1),
        ),
        .radius = radius,
        .is_stuck = true,
    };
    ball.game_object.velocity = velocity;
    return ball;
}

pub fn initDefault(texture: Texture) Self {
    const game_obj = GameObject.initDefault(texture);
    return Self{
        .game_object = game_obj,
        .radius = 12.5,
        .is_stuck = true,
    };
}

pub fn move(self: *Self, delta_time: f32, window_width: f32, mult: f32) zmx.Vec2 {
    if (!self.is_stuck) {
        // update position by velocity
        self.game_object.position += self.game_object.velocity * zm.splat(zmx.Vec2, delta_time * mult);

        // check for collisions with walls and bounce if necessary
        if (self.game_object.position[0] <= 0.0) {
            // bounce off left wall
            self.game_object.velocity[0] = -self.game_object.velocity[0];
            self.game_object.position[0] = 0.0;
        } else if (self.game_object.position[0] >= window_width - self.radius) {
            // bounce off right wall
            self.game_object.velocity[0] = -self.game_object.velocity[0];
            self.game_object.position[0] = window_width - self.radius;
        }

        if (self.game_object.position[1] <= 0.0) {
            // bounce off top wall
            self.game_object.velocity[1] = -self.game_object.velocity[1];
            self.game_object.position[1] = 0.0;
        } else {
            // the player has lost
        }
    }
    return self.game_object.position;
}
pub fn reset(self: *Self, position: zmx.Vec2, velocity: zmx.Vec2) void {
    self.game_object.position = position;
    self.game_object.velocity = velocity;
    self.is_stuck = true;
}
