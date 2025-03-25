const Self = @This();

state: GameState,
keys: [1024]bool,
width: u32,
height: u32,

pub fn init(width: u32, height: u32) Self {
    return .{
        .state = .active,
        .keys = [_]bool{false} ** 1024,
        .width = width,
        .height = height,
    };
}

pub fn deinit(self: Self) void {
    _ = self;
}

pub fn processInput(self: Self, dt: f32) void {
    _ = self;
    _ = dt;
}

pub fn update(self: Self, dt: f32) void {
    _ = self;
    _ = dt;
}

pub fn render(self: Self) void {
    _ = self;
}

pub const GameState = enum {
    active,
    menu,
    win,
};
