const std = @import("std");
const gl = @import("zopengl").bindings;
const log = std.log;

pub fn glLogErrors(src: std.builtin.SourceLocation) void {
    while (getError()) |msg| {
        log.err("[OPENGL] {s}:{} {s}() - {s}", .{
            src.file,
            src.line,
            src.fn_name,
            msg,
        });
    }
}

fn getError() ?[]const u8 {
    const error_code = gl.getError();
    return switch (error_code) {
        gl.INVALID_ENUM => "INVALID_ENUM",
        gl.INVALID_VALUE => "INVALID_VALUE",
        gl.INVALID_OPERATION => "INVALID_OPERATION",
        gl.STACK_OVERFLOW => "STACK_OVERFLOW",
        gl.STACK_UNDERFLOW => "STACK_UNDERFLOW",
        gl.OUT_OF_MEMORY => "OUT_OF_MEMORY",
        gl.INVALID_FRAMEBUFFER_OPERATION => "INVALID_FRAMEBUFFER_OPERATION",
        gl.NO_ERROR => null,
        else => unreachable,
    };
}
