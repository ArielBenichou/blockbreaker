const std = @import("std");
const assert = std.debug.assert;
const GameObject = @import("GameObject.zig");
const ArrayList = std.ArrayList;
const SpriteRenderer = @import("SpriteRenderer.zig");
const ResourceManager = @import("ResourceManager.zig");
const zmx = @import("zmx.zig");
const Self = @This();

bricks: ArrayList(GameObject),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .bricks = ArrayList(GameObject).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.bricks.deinit();
}

/// Structure of expected level file:
/// ```
/// 1 1 1 1 1 1
/// 2 2 0 0 2 2
/// 3 3 4 4 3 3
/// ```
/// - `0` is empty space
/// - `1` is immovable brick
/// - `2`-`n` is brick
/// @see GameLevel.BlockType
pub fn load(
    self: *Self,
    resource_manager: *ResourceManager,
    path: []const u8,
    level_width: f32,
    level_height: f32,
) !void {
    self.bricks.clearRetainingCapacity();

    const file = try std.fs.cwd().readFileAlloc(self.allocator, path, 1024);
    defer self.allocator.free(file);

    var tile_data = ArrayList(ArrayList(BlockType)).init(self.allocator);
    defer {
        for (tile_data.items) |row| {
            row.deinit();
        }
        tile_data.deinit();
    }

    var lines = std.mem.splitSequence(u8, file, "\n");
    while (lines.next()) |line| {
        var tokens = std.mem.splitSequence(u8, line, " ");
        var row = ArrayList(BlockType).init(self.allocator);
        while (tokens.next()) |token| {
            const brick_type = std.fmt.parseInt(usize, token, 10) catch |err| {
                std.log.err("Error for token '{s}': {s}", .{ token, @errorName(err) });
                unreachable;
            };
            row.append(@enumFromInt(brick_type)) catch unreachable;
        }
        tile_data.append(row) catch unreachable;
    }

    if (tile_data.items.len > 0) {
        self.setup(
            resource_manager,
            tile_data,
            level_width,
            level_height,
        );
    }
}

pub fn draw(self: *Self, renderer: *SpriteRenderer) void {
    for (self.bricks.items) |*brick| {
        if (!brick.is_destroyed) {
            brick.draw(renderer);
        }
    }
}

pub fn isCompleted(self: Self) bool {
    for (self.bricks.items) |brick| {
        if (!brick.is_solid and !brick.is_destroyed) return false;
    }
    return true;
}

fn setup(
    self: *Self,
    resource_manager: *ResourceManager,
    tile_data: ArrayList(ArrayList(BlockType)),
    level_width: f32,
    level_height: f32,
) void {
    assert(tile_data.items.len > 0);
    const height = tile_data.items.len;
    const width = tile_data.items[0].items.len;

    // FIXME: here is why if we have a wide screen, the bricks are stretched
    // on the other side, the level decide the aspect ration, so maybe we should
    // draw black bars on the edges of the screen to maintain the aspect ratio
    const unit_width = level_width / @as(f32, @floatFromInt(width));
    const unit_height = level_height / @as(f32, @floatFromInt(height));

    for (0..height) |y| {
        for (0..width) |x| {
            const tile_type = tile_data.items[y].items[x];
            const pos: zmx.Vec2 = .{
                @as(f32, @floatFromInt(x)) * unit_width,
                @as(f32, @floatFromInt(y)) * unit_height,
            };
            const size: zmx.Vec2 = .{ unit_width, unit_height };
            switch (tile_type) {
                BlockType.empty => {},
                else => |block_type| {
                    const is_solid = block_type == .solid;
                    var brick = GameObject.init(
                        pos,
                        size,
                        resource_manager.getTexture(if (is_solid) "block_solid" else "block"),
                        block_type.color(),
                    );
                    brick.is_solid = is_solid;
                    self.bricks.append(brick) catch unreachable;
                },
            }
        }
    }
}

pub const BlockType = enum(usize) {
    empty = 0,
    solid = 1,
    brick_blue = 2,
    brick_green = 3,
    brick_orange = 4,
    brick_red = 5,

    pub fn color(self: BlockType) zmx.Vec3 {
        return switch (self) {
            .solid => .{ 0.8, 0.8, 0.7 },
            .brick_blue => .{ 0.2, 0.6, 1.0 },
            .brick_green => .{ 0.0, 0.7, 0.0 },
            .brick_orange => .{ 0.8, 0.8, 0.4 },
            .brick_red => .{ 1.0, 0.5, 0.0 },
            else => unreachable,
        };
    }
};
