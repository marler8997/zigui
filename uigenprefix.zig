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

pub fn pathStringLen(path: []const []const u8) usize {
    if (path.len == 0) unreachable;

    var len: usize = 0;
    for (path) |p| {
        len += p.len + 1;
    }
    len -= 1;
    return len;
}

pub fn pathStringCt(comptime path: []const []const u8) [pathStringLen(path)]u8 {
    if (path.len == 0) unreachable;

    var str: [pathStringLen(path)]u8 = undefined;
    var offset: usize = 0;
    for (path, 0..) |p, i| {
        @memcpy(str[offset..][0..p.len], p);
        offset += p.len;
        if (i < path.len - 1) {
            str[offset] = '.';
            offset += 1;
        }
    }
    if (offset != pathStringLen(path)) unreachable;
    return str;
}

pub const Variable = struct {
    @"type": enum {
        uint,
        rgba,
    },
    field_path: []const []const u8,

    pub fn fieldPathString(comptime self: Variable) [pathStringLen(self.field_path)]u8 {
        return pathStringCt(self.field_path);
    }

    // TODO: prefix should be a ComponentPath
    pub fn initSubvar(
        comptime self: Variable,
        comptime parent_path: []const []const u8,
        //comptime prefix: []const u8,
    ) Variable {
        return .{
            //.field_name = prefix ++ "." ++ self.field_name,
            .@"type" = self.@"type",
            .field_path = parent_path ++ self.field_path,
        };
    }
};

pub fn subvars(
    comptime path: []const []const u8,
    comptime count: comptime_int,
    comptime vars: [count]Variable,
) [count]Variable {
    var result: [count]Variable = undefined;
    for (vars, 0..) |v, i| {
        result[i] = v.initSubvar(path);
    }
    return result;
}
