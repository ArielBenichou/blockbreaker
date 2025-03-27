const zm = @import("zmath");
const zmx = @import("zmx.zig");
const std = @import("std");
const GameObject = @import("GameObject.zig");
const Texture = @import("Texture.zig");
const Shader = @import("Shader.zig");
const gl = @import("zopengl").bindings;

const Particle = struct {
    position: zmx.Vec2,
    velocity: zmx.Vec2,
    lifetime: f32,
    color: zm.Vec,

    pub fn init() Particle {
        return Particle{
            .position = .{ 0, 0 },
            .velocity = .{ 0, 0 },
            .lifetime = 0,
            .color = .{ 1, 1, 1, 1 },
        };
    }

    pub fn is_alive(self: Particle) bool {
        return self.lifetime > 0;
    }
};

pub const ParticleGenerator = struct {
    particles: std.ArrayList(Particle),
    last_used_particle: usize,
    max_particles: usize,
    shader: Shader,
    texture: Texture,
    vao: gl.Uint,

    pub fn init(
        allocator: std.mem.Allocator,
        shader: Shader,
        texture: Texture,
        max_particles: usize,
    ) !ParticleGenerator {
        // init particles
        var particles = std.ArrayList(Particle).init(allocator);
        for (0..max_particles) |_| {
            try particles.append(Particle.init());
        }

        // init render data
        const vao = vao: {
            var id: gl.Uint = undefined;
            var vbo: gl.Uint = undefined;
            // zig fmt: off
            const quad = [_]gl.Float{
                0.0, 1.0, 0.0, 1.0,
                1.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 0.0,

                0.0, 1.0, 0.0, 1.0,
                1.0, 1.0, 1.0, 1.0,
                1.0, 0.0, 1.0, 0.0,
            };
            // zig fmt: on
            gl.genVertexArrays(1, &id);
            gl.genBuffers(1, &vbo);
            gl.bindVertexArray(id);
            defer gl.bindVertexArray(0);
            gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
            gl.bufferData(
                gl.ARRAY_BUFFER,
                @sizeOf(gl.Float) * quad.len,
                &quad,
                gl.STATIC_DRAW,
            );
            gl.enableVertexAttribArray(0);
            gl.vertexAttribPointer(
                0,
                4,
                gl.FLOAT,
                gl.FALSE,
                4 * @sizeOf(gl.Float),
                @ptrFromInt(0),
            );
            break :vao id;
        };

        return ParticleGenerator{
            .particles = particles,
            .last_used_particle = 0,
            .max_particles = max_particles,
            .shader = shader,
            .texture = texture,
            .vao = vao,
        };
    }

    pub fn deinit(self: ParticleGenerator) void {
        self.particles.deinit();
        gl.deleteVertexArrays(1, &self.vao);
    }

    pub fn update(
        self: *ParticleGenerator,
        dt: f32,
        game_object: *GameObject,
        new_particles: usize,
        offset: zmx.Vec2,
        lifetime: f32,
    ) void {
        // spawn new particles
        for (0..new_particles) |_| {
            const index = self.first_unused_particle();
            self.respawn_particle(index, game_object, offset, lifetime);
        }
        // update particles
        for (self.particles.items) |*particle| {
            particle.lifetime -= dt;
            if (particle.is_alive()) {
                particle.position -= particle.velocity * zm.splat(zmx.Vec2, dt);
                particle.color[3] -= dt * 2.5;
            }
        }
    }

    pub fn draw(self: *ParticleGenerator) void {
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE);
        defer gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        self.shader.use();
        for (self.particles.items) |particle| {
            if (particle.is_alive()) {
                self.shader.setVector2fv("offset", particle.position, false);
                self.shader.setVector4fv("color", particle.color, false);
                self.texture.bind();
                gl.bindVertexArray(self.vao);
                defer gl.bindVertexArray(0);
                gl.drawArrays(gl.TRIANGLES, 0, 6);
            }
        }
    }

    fn first_unused_particle(self: *ParticleGenerator) usize {
        const index = find: {
            {
                var i = self.last_used_particle;
                // try to find from the last used particle index - probably faster
                while (i < self.max_particles) : (i += 1) {
                    const particle = self.particles.items[i];
                    if (!particle.is_alive()) {
                        break :find i;
                    }
                }
            }
            // if not found, try to find from the beginning
            for (self.particles.items, 0..) |particle, i| {
                if (!particle.is_alive()) {
                    break :find i;
                }
            }
            // if not found, return 0 - overriding the first particle
            break :find 0;
        };
        self.last_used_particle = index;
        return index;
    }

    fn respawn_particle(
        self: *ParticleGenerator,
        index: usize,
        game_object: *GameObject,
        offset: zmx.Vec2,
        lifetime: f32,
    ) void {
        const particle = &self.particles.items[index];
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        var rng = prng.random();
        const random = ((rng.float(f32) * 10) - 5);
        const rColor = 0.5 + rng.float(f32);
        particle.position = game_object.position + offset + zmx.Vec2{ random, 0 };
        particle.color = .{ rColor, rColor, rColor, 1 };
        particle.lifetime = lifetime;
        particle.velocity = game_object.velocity * zm.splat(zmx.Vec2, 0.1);
    }
};
