const std = @import("std");
pub fn XY(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        pub fn init(x: T, y: T) @This() {
            return .{ .x = x, .y = y };
        }
    };
}
pub const Rgba = struct { r: u8, g: u8, b: u8, a: u8 };

pub const Variable = union(enum) {
    width: []const u8,
    height: []const u8,
    rgba: []const u8,

    pub fn initSubvar(comptime self: Variable, comptime prefix: []const u8) Variable {
        return switch (self) {
            .width => |name| return .{ .width = prefix ++ "." ++ name },
            .height => |name| return .{ .height = prefix ++ "." ++ name },
            .rgba => |name| return .{ .rgba = prefix ++ "." ++ name },
        };
    }
};

pub fn subvars(
    comptime prefix: []const u8,
    comptime count: comptime_int,
    comptime vars: [count]Variable,
) [count]Variable {
    var result: [count]Variable = undefined;
    for (vars, 0..) |v, i| {
        result[i] = v.initSubvar(prefix);
    }
    return result;
}
