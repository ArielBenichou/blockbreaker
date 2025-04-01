const std = @import("std");
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const SpriteRenderer = @import("SpriteRenderer.zig");
const ResourceManager = @import("ResourceManager.zig");
const GameLevel = @import("GameLevel.zig");
const GameObject = @import("GameObject.zig");
const BallObject = @import("BallObject.zig");
const ParticleGenerator = @import("particle.zig").ParticleGenerator;
const PostProcessor = @import("PostProcessor.zig");
const PowerUp = @import("PowerUp.zig");
const zm = @import("zmath");
const collision = @import("collision.zig");
const glfw = @import("zglfw");
const glx = @import("glx.zig");
const gui = @import("zgui");
const zmx = @import("zmx.zig");

const INITIAL_PADDLE_SIZE: zmx.Vec2 = .{ 100, 20 };
const INITIAL_PADDLE_SPEED: zmx.Vec2 = .{ 1000, 0 };
const INITIAL_BALL_VELOCITY: zmx.Vec2 = .{ 0, -500 };
const BALL_VELOCITY_X: f32 = 1000;
const BALL_RADIUS: f32 = 12.5;

const NEW_PARTICLE_COUNT: u32 = 2;
const NEW_PARTICLE_LIFETIME: f32 = 1;

const Self = @This();

state: GameState,
renderer: SpriteRenderer,
particle_renderer: ParticleGenerator,
levels: ArrayList(GameLevel),
level_index: usize,
power_ups: ArrayList(PowerUp),
/// player effects (from powerups)
/// hold timers for each effect, if >0 then apply effect
powerup_effect: struct {
    speed: f32 = 0,
    sticky: f32 = 0,
    passthrough: f32 = 0,
    increase: f32 = 0,
    confuse: f32 = 0,
    chaos: f32 = 0,
} = .{},
paddle: GameObject,
paddle_speed: zmx.Vec2 = INITIAL_PADDLE_SPEED,
ball: BallObject,
shake_time: f32 = 0,
/// reference to the resource manager singleton
resource_manager: *ResourceManager,
postprocessor: PostProcessor,
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
        .levels = ArrayList(GameLevel).init(allocator),
        .level_index = 0,
        .power_ups = ArrayList(PowerUp).init(allocator),
        .allocator = allocator,
        .paddle = undefined,
        .ball = undefined,
        .renderer = undefined,
        .particle_renderer = undefined,
        .postprocessor = undefined,
    };
}

pub fn deinit(self: Self) void {
    for (self.levels.items) |*level| {
        level.deinit();
    }
    self.levels.deinit();
    self.particle_renderer.deinit();
    self.power_ups.deinit();
}

pub fn prepare(self: *Self) !void {
    // SHADERS
    const sprite_shader = try self.resource_manager.loadShader(
        "sprite",
        "res/shaders/sprite.vs.glsl",
        "res/shaders/sprite.fs.glsl",
        null,
    );
    const particle_shader = try self.resource_manager.loadShader(
        "particle",
        "res/shaders/particle.vs.glsl",
        "res/shaders/particle.fs.glsl",
        null,
    );
    const postprocessing_shader = try self.resource_manager.loadShader(
        "postprocessing",
        "res/shaders/postprocessing.vs.glsl",
        "res/shaders/postprocessing.fs.glsl",
        null,
    );
    // PROJECTION
    const proj = zm.orthographicOffCenterLhGl(
        0,
        @floatFromInt(self.width),
        0,
        @floatFromInt(self.height),
        -1,
        1,
    );
    // SET SHADER UNIFORMS
    sprite_shader.use();
    sprite_shader.setInteger("image", 0, false);
    sprite_shader.setMatrix("projection", proj, false);
    particle_shader.use();
    particle_shader.setInteger("sprite", 0, false);
    particle_shader.setMatrix("projection", proj, false);

    const TexConfig = struct {
        path: [:0]const u8,
        name: [:0]const u8,
        is_transparent: bool,
    };

    // TEXTURES
    const textures_to_load = [_]TexConfig{
        .{
            .path = "res/sprites/background.jpg",
            .name = "background",
            .is_transparent = false,
        },
        .{
            .path = "res/sprites/awesome_face.png",
            .name = "face",
            .is_transparent = true,
        },
        .{
            .path = "res/sprites/block.png",
            .name = "block",
            .is_transparent = false,
        },
        .{
            .path = "res/sprites/block_solid.png",
            .name = "block_solid",
            .is_transparent = false,
        },
        .{
            .path = "res/sprites/paddle.png",
            .name = "paddle",
            .is_transparent = true,
        },
        .{
            .path = "res/sprites/particle.png",
            .name = "particle",
            .is_transparent = true,
        },
        // Powerups
        .{
            .path = "res/sprites/powerup_speed.png",
            .name = "powerup_speed",
            .is_transparent = true,
        },
        .{
            .path = "res/sprites/powerup_sticky.png",
            .name = "powerup_sticky",
            .is_transparent = true,
        },
        .{
            .path = "res/sprites/powerup_passthrough.png",
            .name = "powerup_passthrough",
            .is_transparent = true,
        },
        .{
            .path = "res/sprites/powerup_increase.png",
            .name = "powerup_increase",
            .is_transparent = true,
        },
        .{
            .path = "res/sprites/powerup_confuse.png",
            .name = "powerup_confuse",
            .is_transparent = true,
        },
        .{
            .path = "res/sprites/powerup_chaos.png",
            .name = "powerup_chaos",
            .is_transparent = true,
        },
    };
    inline for (textures_to_load) |tex_config| {
        _ = try self.resource_manager.loadTexture(
            tex_config.path,
            tex_config.name,
            tex_config.is_transparent,
        );
    }

    // Systems
    self.renderer = SpriteRenderer.init(sprite_shader);
    self.particle_renderer = try ParticleGenerator.init(
        self.allocator,
        particle_shader,
        self.resource_manager.getTexture("particle"),
        500,
    );
    self.postprocessor = PostProcessor.init(
        postprocessing_shader,
        self.width,
        self.height,
    );

    // LEVELS
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

    // GameObjects
    const paddle_size: zmx.Vec2 = INITIAL_PADDLE_SIZE;
    const paddle_pos: zmx.Vec2 = .{
        @as(f32, @floatFromInt(self.width)) / 2 - paddle_size[0] / 2,
        @as(f32, @floatFromInt(self.height)) - paddle_size[1],
    };
    self.paddle = GameObject.init(
        paddle_pos,
        paddle_size,
        self.resource_manager.getTexture("paddle"),
        .{ 1, 1, 1 },
    );

    const ball_pos: zmx.Vec2 = .{ paddle_pos[0] + paddle_size[0] / 2 - BALL_RADIUS, paddle_pos[1] - BALL_RADIUS * 2 };
    self.ball = BallObject.init(
        ball_pos,
        BALL_RADIUS,
        INITIAL_BALL_VELOCITY,
        self.resource_manager.getTexture("face"),
    );
}

pub fn update(self: *Self, dt: f32) void {
    { // PADDLE
        if (self.powerup_effect.increase > 0) {
            self.paddle.size[0] = INITIAL_PADDLE_SIZE[0] + 100;
        } else {
            self.paddle.size[0] = INITIAL_PADDLE_SIZE[0];
        }
    }
    { // BALL
        const mult: f32 = if (self.powerup_effect.speed > 0) 1.5 else 1;
        _ = self.ball.move(dt, @floatFromInt(self.width), mult);
    }
    { // POWERUPS
        for (self.power_ups.items) |*powerup| {
            powerup.update(dt, @floatFromInt(self.height));
        }
        if (self.powerup_effect.speed > 0) {
            self.powerup_effect.speed -= dt;
        }
        if (self.powerup_effect.sticky > 0) {
            self.powerup_effect.sticky -= dt;
        }
        if (self.powerup_effect.passthrough > 0) {
            self.powerup_effect.passthrough -= dt;
        }
        if (self.powerup_effect.increase > 0) {
            self.powerup_effect.increase -= dt;
        }
    }
    { // COLLISIONS
        self.doCollisions();
    }
    { // PARTICLES
        // if ball velocity is zero (length) we should not spawn particles
        const vel_scale = @intFromBool(!self.ball.is_stuck);
        const mult: u32 = if (self.powerup_effect.speed > 0) 2 else 1;
        self.particle_renderer.update(
            dt,
            &self.ball.game_object,
            NEW_PARTICLE_COUNT * vel_scale * mult,
            zm.splat(zmx.Vec2, self.ball.radius),
            NEW_PARTICLE_LIFETIME,
        );
    }
    // LOSE CONDITION
    if (self.ball.game_object.position[1] >= @as(f32, @floatFromInt(self.height))) {
        self.resetLevel();
        self.resetPlayer();
    }
    // SHAKE
    if (self.shake_time > 0) {
        self.shake_time -= dt;
        if (self.shake_time <= 0) {
            self.postprocessor.shake = false;
        }
    }
    // CONFUSE
    if (self.powerup_effect.confuse > 0) {
        self.powerup_effect.confuse -= dt;
        self.postprocessor.confuse = true;
    } else {
        self.postprocessor.confuse = false;
    }

    // CHAOS
    if (self.powerup_effect.chaos > 0) {
        self.powerup_effect.chaos -= dt;
        self.postprocessor.chaos = true;
    } else {
        self.postprocessor.chaos = false;
    }
}

pub fn render(self: *Self) void {
    if (self.state == .active) {
        self.postprocessor.beginRender();
        self.renderer.drawSprite(
            self.resource_manager.getTexture("background"),
            .{ 0, 0 },
            .{ @floatFromInt(self.width), @floatFromInt(self.height) },
            0,
            .{ 1, 1, 1 },
        );
        self.levels.items[self.level_index].draw(&self.renderer);
        if (self.powerup_effect.sticky > 0) {
            self.paddle.color = PowerUp.PowerUpType.sticky.color();
        } else {
            self.paddle.color = .{ 1, 1, 1 };
        }
        self.paddle.draw(&self.renderer);
        for (self.power_ups.items) |*powerup| {
            if (powerup.is_active) {
                powerup.game_object.draw(&self.renderer);
            }
        }
        self.particle_renderer.draw();
        if (self.ball.is_stuck and self.powerup_effect.sticky > 0) {
            self.ball.game_object.color = PowerUp.PowerUpType.sticky.color();
        } else if (self.powerup_effect.speed > 0) {
            self.ball.game_object.color = PowerUp.PowerUpType.speed.color();
        } else {
            self.ball.game_object.color = .{ 1, 1, 1 };
        }
        self.ball.game_object.draw(&self.renderer);
        self.postprocessor.endRender();
        self.postprocessor.render(@floatCast(glfw.getTime()));
    }

    glx.glLogErrors(@src());
}

pub fn renderUI(self: *Self) void {
    _ = self;
    // gui.setNextWindowSize(.{ .w = 300, .h = 150 });
    // if (gui.begin("Particle Configuration", .{})) {
    //     var lifetime: f32 = self.new_particle_lifetime;
    //     if (gui.sliderFloat("Lifetime (seconds)", .{
    //         .v = &lifetime,
    //         .min = 0.1,
    //         .max = 10.0,
    //         .cfmt = "%.1f",
    //     })) {
    //         self.new_particle_lifetime = lifetime;
    //     }

    //     var count: f32 = @floatFromInt(self.new_particle_count);
    //     if (gui.sliderFloat("Particle Count", .{
    //         .v = &count,
    //         .min = 1,
    //         .max = 10,
    //         .cfmt = "%.0f",
    //     })) {
    //         self.new_particle_count = @intFromFloat(count);
    //     }
    // }
    // gui.end();
}

pub fn processInput(self: *Self, dt: f32) void {
    // quick change level with num 1-4
    if (self.keys[@intFromEnum(glfw.Key.n)]) {
        self.selectLevel(@mod(self.level_index + 1, self.levels.items.len));
    }

    if (self.keys[@intFromEnum(glfw.Key.one)]) {
        self.powerup_effect.confuse = 10;
    } else if (self.keys[@intFromEnum(glfw.Key.two)]) {
        self.powerup_effect.chaos = 10;
    }

    if (self.state == .active) {
        const vel = self.paddle_speed[0] * dt;
        if (self.keys[@intFromEnum(glfw.Key.a)]) {
            if (self.paddle.position[0] >= 0) {
                self.paddle.position[0] -= vel;
                if (self.ball.is_stuck) {
                    self.ball.game_object.position[0] -= vel;
                }
            }
        }
        if (self.keys[@intFromEnum(glfw.Key.d)]) {
            if (self.paddle.position[0] <= @as(f32, @floatFromInt(self.width)) - self.paddle.size[0]) {
                self.paddle.position[0] += vel;
                if (self.ball.is_stuck) {
                    self.ball.game_object.position[0] += vel;
                }
            }
        }
        if (self.keys[@intFromEnum(glfw.Key.space)]) {
            self.ball.is_stuck = false;
        }
    }
}

pub fn doCollisions(self: *Self) void {
    { // BRICK COLLISIONS
        const level = self.levels.items[self.level_index];
        const bricks = level.bricks;
        for (bricks.items) |*brick| {
            if (!brick.is_destroyed) {
                const col = collision.isCollidingCircle(brick.*, .{
                    .position = self.ball.game_object.position,
                    .radius = self.ball.radius,
                });
                if (col.is_colliding) {
                    if (!brick.is_solid) {
                        brick.is_destroyed = true;
                        self.spawnPowerUp(brick.position + brick.size / zm.splat(zmx.Vec2, 2));
                    } else {
                        // SHAKE ON HIT SOLID
                        self.shake_time = 0.1;
                        self.postprocessor.shake = true;
                    }
                    if (brick.is_solid or self.powerup_effect.passthrough <= 0) {
                        switch (col.direction) {
                            .left, .right => {
                                self.ball.game_object.velocity[0] = -self.ball.game_object.velocity[0];
                                const penetration = self.ball.radius - @abs(col.difference[0]);
                                if (col.direction == .left) {
                                    self.ball.game_object.position[0] += penetration;
                                } else {
                                    self.ball.game_object.position[0] -= penetration;
                                }
                            },
                            .up, .down => {
                                self.ball.game_object.velocity[1] = -self.ball.game_object.velocity[1];
                                const penetration = self.ball.radius - @abs(col.difference[1]);
                                if (col.direction == .up) {
                                    self.ball.game_object.position[1] -= penetration;
                                } else {
                                    self.ball.game_object.position[1] += penetration;
                                }
                            },
                        }
                    }
                }
            }
        }
    }

    { // PADDLE COLLISIONS
        { // \w BALL
            const col = collision.isCollidingCircle(self.paddle, .{
                .position = self.ball.game_object.position,
                .radius = self.ball.radius,
            });
            if (col.is_colliding) {
                if (self.powerup_effect.sticky > 0) {
                    self.ball.is_stuck = true;
                    self.ball.game_object.velocity = INITIAL_BALL_VELOCITY;
                } else if (!self.ball.is_stuck) {
                    const center_paddle = self.paddle.position[0] + self.paddle.size[0] / 2;
                    const distance = (self.ball.game_object.position[0] + self.ball.radius) - center_paddle;
                    const percentage = distance / (self.paddle.size[0] / 2);
                    const strength = 1.0;
                    const old_velocity = self.ball.game_object.velocity;
                    self.ball.game_object.velocity[0] = BALL_VELOCITY_X * percentage * strength;
                    // Vertical velocity is always negative - the ceiling (top of screen) is -1
                    self.ball.game_object.velocity[1] = -1 * std.math.clamp(@abs(old_velocity[1]), 500, 1000);
                    const norm = zm.normalize2(zmx.vec2ToVec(self.ball.game_object.velocity)) * zm.length2(zmx.vec2ToVec(old_velocity));
                    self.ball.game_object.velocity = .{ norm[0], norm[1] };
                }
            }
        }
        { // \w POWERUP
            for (self.power_ups.items) |*powerup| {
                const is_colliding = collision.isCollidingAABB(self.paddle, powerup.game_object);
                if (is_colliding) {
                    if (powerup.is_active) {
                        powerup.is_active = false;
                        switch (powerup.powerup_type) {
                            .speed => {
                                self.powerup_effect.speed = powerup.powerup_type.duration();
                            },
                            .sticky => {
                                self.powerup_effect.sticky = powerup.powerup_type.duration();
                            },
                            .passthrough => {
                                self.powerup_effect.passthrough = powerup.powerup_type.duration();
                            },
                            .increase => {
                                self.powerup_effect.increase = powerup.powerup_type.duration();
                            },
                            .confuse => {
                                self.powerup_effect.confuse = powerup.powerup_type.duration();
                            },
                            .chaos => {
                                self.powerup_effect.chaos = powerup.powerup_type.duration();
                            },
                        }
                    }
                }
            }
        }
    }
}

fn resetLevel(self: *Self) void {
    const level_names = [_][]const u8{
        "res/levels/one.lvl",
        "res/levels/two.lvl",
        "res/levels/three.lvl",
        "res/levels/four.lvl",
    };
    self.levels.items[self.level_index].load(
        self.resource_manager,
        level_names[self.level_index],
        @floatFromInt(self.width),
        @floatFromInt(self.height / 2),
    ) catch unreachable;

    for (self.power_ups.items) |*powerup| {
        powerup.is_active = false;
    }
    self.powerup_effect = .{};
}

fn resetPlayer(self: *Self) void {
    self.paddle.size = INITIAL_PADDLE_SIZE;
    self.paddle.position = .{
        @as(f32, @floatFromInt(self.width)) / 2 - INITIAL_PADDLE_SIZE[0] / 2,
        @as(f32, @floatFromInt(self.height)) - INITIAL_PADDLE_SIZE[1],
    };
    self.ball.reset(
        .{
            self.paddle.position[0] + self.paddle.size[0] / 2 - BALL_RADIUS,
            self.paddle.position[1] - BALL_RADIUS * 2,
        },
        INITIAL_BALL_VELOCITY,
    );
}

fn selectLevel(self: *Self, level_index: usize) void {
    self.resetLevel();
    self.resetPlayer();
    self.level_index = level_index;
}

fn spawnPowerUp(self: *Self, position: zmx.Vec2) void {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    var rng = prng.random();
    const success_chance = 0.5;
    if (rng.float(f32) <= success_chance) {
        const powerup_type = rng.enumValue(PowerUp.PowerUpType);
        const size = INITIAL_PADDLE_SIZE / zm.splat(zmx.Vec2, 2);
        const pos = position - size / zm.splat(zmx.Vec2, 2);
        const tex = self.resource_manager.getTexture(powerup_type.name());
        // first we try to find an inactive powerup, and "respawn" it
        const has_reused = reuse_powerup: {
            for (self.power_ups.items) |*powerup| {
                if (!powerup.is_active) {
                    powerup.reuse(
                        pos,
                        size,
                        tex,
                        powerup_type,
                    );
                    break :reuse_powerup true;
                }
            }
            break :reuse_powerup false;
        };
        if (!has_reused) {
            self.power_ups.append(PowerUp.init(
                pos,
                size,
                tex,
                powerup_type,
            )) catch unreachable;
        }
    }
}

pub const GameState = enum {
    active,
    menu,
    win,
};
