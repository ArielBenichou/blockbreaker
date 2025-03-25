const std = @import("std");
const assert = std.debug.assert;
const SpriteRenderer = @import("SpriteRenderer.zig");
const ResourceManager = @import("ResourceManager.zig");
const zm = @import("zmath");
const glx = @import("glx.zig");
const gui = @import("zgui");
const zmx = @import("zmx.zig");

const Self = @This();

const SpriteProperties = struct {
    position: zmx.Vec2,
    size: zmx.Vec2,
    rotation: f32,
    color: zmx.Vec3,
};

state: GameState,
renderer: ?SpriteRenderer,
/// reference to the resource manager singleton
resource_manager: *ResourceManager,
keys: [1024]bool,
width: u32,
height: u32,
sprite_properties: SpriteProperties,

pub fn init(width: u32, height: u32, resource_manager: *ResourceManager) Self {
    return Self{
        .state = .active,
        .keys = [_]bool{false} ** 1024,
        .width = width,
        .height = height,
        .resource_manager = resource_manager,
        .renderer = null,
        .sprite_properties = .{
            .position = .{ 200, 200 },
            .size = .{ 300, 400 },
            .rotation = 45,
            .color = .{ 1, 0, 1 },
        },
    };
}

pub fn deinit(self: Self) void {
    _ = self;
}

pub fn processInput(self: Self, dt: f32) void {
    _ = self;
    _ = dt;
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
        "res/sprites/awesome_face_512x512.png",
        "face",
        true,
    );
}

pub fn update(self: Self, dt: f32) void {
    _ = self;
    _ = dt;
}

pub fn render(self: Self) void {
    self.renderer.?.drawSprite(
        self.resource_manager.getTexture("face"),
        self.sprite_properties.position,
        self.sprite_properties.size,
        self.sprite_properties.rotation,
        self.sprite_properties.color,
    );
    glx.glLogErrors(@src());
}

pub fn renderUI(self: *Self) void {
    gui.setNextWindowPos(.{
        .x = 20.0,
        .y = 20.0,
        .cond = .first_use_ever,
    });
    gui.setNextWindowSize(.{
        .w = 300.0,
        .h = 200.0,
        .cond = .first_use_ever,
    });

    if (gui.begin("Sprite Properties", .{})) {
        gui.spacing();
        gui.separatorText("Transform");

        var pos = self.sprite_properties.position;
        if (gui.dragFloat2("Position", .{
            .v = &pos,
            .speed = 1.0,
            .min = -1000.0,
            .max = 1000.0,
        })) {
            self.sprite_properties.position = pos;
        }

        var size = self.sprite_properties.size;
        if (gui.dragFloat2("Size", .{
            .v = &size,
            .speed = 1.0,
            .min = 1.0,
            .max = 1000.0,
        })) {
            self.sprite_properties.size = size;
        }

        var rotation = self.sprite_properties.rotation;
        if (gui.sliderFloat("Rotation", .{
            .v = &rotation,
            .min = -360.0,
            .max = 360.0,
        })) {
            self.sprite_properties.rotation = rotation;
        }

        gui.spacing();
        gui.separatorText("Appearance");

        var color = self.sprite_properties.color;
        if (gui.colorEdit3("Color", .{
            .col = &color,
        })) {
            self.sprite_properties.color = color;
        }

        if (gui.button("Reset Properties", .{})) {
            self.sprite_properties = .{
                .position = .{ 0, 0 },
                .size = .{ 100, 100 },
                .rotation = 0.0,
                .color = .{ 0, 1.0, 0 },
            };
        }
    }
    gui.end();
}

pub const GameState = enum {
    active,
    menu,
    win,
};
