const std = @import("std");
const glfw = @import("zglfw");
const zaudio = @import("zaudio");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const Game = @import("Game.zig");
const ResourceManager = @import("ResourceManager.zig");
const stbi = @import("zstbi");
const gui = @import("zgui");
const builtin = @import("builtin");

const WINDOW_WIDTH = 800 * 1.5;
const WINDOW_HEIGHT = 600 * 1.5;
var game: Game = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    glfw.init() catch {
        std.log.err("GLFW Initilization failed", .{});
        std.process.exit(1);
    };
    defer glfw.terminate();

    const gl_major = 3;
    const gl_minor = 3;
    glfw.windowHint(.context_version_major, gl_major);
    glfw.windowHint(.context_version_minor, gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    if (builtin.target.os.tag.isDarwin()) {
        glfw.windowHint(.opengl_forward_compat, true);
    }
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.resizable, false);
    glfw.windowHint(.doublebuffer, true);

    const window = glfw.Window.create(
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        "Block Breaker",
        null,
    ) catch {
        std.log.err("GLFW Window creation failed", .{});
        glfw.terminate();
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);

    _ = glfw.setKeyCallback(window, keyCallback);
    _ = glfw.setFramebufferSizeCallback(window, framebufferSizeCallback);

    try zopengl.loadCoreProfile(
        glfw.getProcAddress,
        gl_major,
        gl_minor,
    );

    // OpenGL Config
    gl.viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    stbi.init(allocator);
    defer stbi.deinit();

    // zgui: init
    gui.init(allocator);
    defer gui.deinit();

    gui.io.setConfigFlags(.{
        .viewport_enable = true,
        .dock_enable = true,
    });

    gui.backend.init(window);
    defer gui.backend.deinit();

    // zaudio
    zaudio.init(allocator);
    defer zaudio.deinit();

    const engine = try zaudio.Engine.create(null);
    // FIXME: this cause seg fault on WINDOWS!
    defer engine.destroy();

    // Resources
    var resource_manager = ResourceManager.init(allocator, engine);
    defer resource_manager.deinit();

    // Game
    game = Game.init(
        allocator,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        &resource_manager,
    );
    try game.prepare();
    defer game.deinit();

    var delta_time: f32 = 0.0;
    var last_frame: f32 = 0.0;

    while (!window.shouldClose()) {
        const current_frame: f32 = @floatCast(glfw.getTime());
        delta_time = current_frame - last_frame;
        last_frame = current_frame;
        glfw.pollEvents();

        game.processInput(delta_time);
        game.update(delta_time);

        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);
        game.render();
        { // zgui
            const framebuffer_size = window.getFramebufferSize();

            gui.backend.newFrame(@intCast(framebuffer_size[0]), @intCast(framebuffer_size[1]));

            game.renderUI();

            gui.backend.draw();

            { // Enable Multi-Viewports
                const ctx = glfw.getCurrentContext();
                gui.updatePlatformWindows();
                gui.renderPlatformWindowsDefault();
                glfw.makeContextCurrent(ctx);
            }
        }

        window.swapBuffers();
    }
}

fn keyCallback(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
    _ = scancode;
    _ = mods;
    if (key == .escape and action == .press) {
        window.setShouldClose(true);
    }
    const key_int: usize = @intCast(@intFromEnum(key));
    if (key_int >= 0 and key_int < 1024) {
        if (action == .press) {
            game.keys[key_int] = true;
        } else if (action == .release) {
            game.keys[key_int] = false;
        }
    }
}

fn framebufferSizeCallback(window: *glfw.Window, width: i32, height: i32) callconv(.c) void {
    _ = window;
    gl.viewport(0, 0, width, height);
}
