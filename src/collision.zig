const zmx = @import("zmx.zig");
const zm = @import("zmath");
const GameObject = @import("GameObject.zig");
const direction = @import("direction.zig");
const Direction = direction.Direction;

const Collision = struct {
    is_colliding: bool,
    direction: Direction,
    difference: zmx.Vec2,
};

const Circle = struct {
    position: zmx.Vec2,
    radius: f32,

    pub fn center(self: Circle) zmx.Vec2 {
        return self.position + zm.splat(zmx.Vec2, self.radius);
    }
};

pub fn isCollidingAABB(self: GameObject, other: GameObject) bool {
    const is_x_collision = self.position[0] + self.size[0] >= other.position[0] and
        other.position[0] + other.size[0] >= self.position[0];
    const is_y_collision = self.position[1] + self.size[1] >= other.position[1] and
        other.position[1] + other.size[1] >= self.position[1];
    return is_x_collision and is_y_collision;
}
pub fn isCollidingCircle(self: GameObject, other: Circle) Collision {
    const cirlce_center = other.center();
    const aabb_half_extents = self.size / zm.splat(zmx.Vec2, 2);
    const aabb_center = self.position + aabb_half_extents;
    const distance = cirlce_center - aabb_center;
    const distance_clamped: zmx.Vec2 = zm.clamp(distance, -aabb_half_extents, aabb_half_extents);
    const closest = aabb_center + distance_clamped;
    const closest_distance = zmx.distanceVec2(closest, cirlce_center);
    if (closest_distance <= other.radius) {
        const dir = direction.getNearestDirection(distance);
        return Collision{
            .is_colliding = true,
            .direction = dir,
            .difference = distance_clamped,
        };
    }
    return Collision{
        .is_colliding = false,
        .direction = .up,
        .difference = .{ 0, 0 },
    };
}
