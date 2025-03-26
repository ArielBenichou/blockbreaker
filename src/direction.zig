const zmx = @import("zmx.zig");
const zm = @import("zmath");
const std = @import("std");

pub const Direction = enum {
    up,
    down,
    left,
    right,

    pub fn value(self: Direction) zmx.Vec2 {
        return switch (self) {
            .up => .{ 0, 1 },
            .down => .{ 0, -1 },
            .left => .{ -1, 0 },
            .right => .{ 1, 0 },
        };
    }
};

pub fn getNearestDirection(target: zmx.Vec2) Direction {
    var max: f32 = 0;
    var best_match: Direction = undefined;

    inline for (std.meta.fields(Direction)) |field| {
        const direction = @as(Direction, @enumFromInt(field.value));
        const dot = zm.dot2(
            zm.normalize2(zmx.vec2ToVec(target)),
            zmx.vec2ToVec(direction.value()),
        )[0];
        if (dot > max) {
            max = dot;
            best_match = direction;
        }
    }
    return best_match;
}
