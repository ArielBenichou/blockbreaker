const zm = @import("zmath");
const math = @import("std").math;
// this was a bad idea
// TODO: ONLY use zm.Vec, with z, w = 0, 0
pub const F32x2 = @Vector(2, f32);
pub const Vec2 = F32x2;
pub const F32x3 = @Vector(3, f32);
pub const Vec3 = F32x3;

pub fn distanceVec2(a: Vec2, b: Vec2) f32 {
    return zm.sqrt(math.pow(f32, a[0] - b[0], 2) + math.pow(f32, a[1] - b[1], 2));
}

pub fn vec2ToVec(v: Vec2) zm.Vec {
    return zm.f32x4(v[0], v[1], 0, 0);
}
