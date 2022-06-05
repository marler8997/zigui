const std = @import("std");
const uidefs = @import("uidefs.zig");

pub const Node = struct {
    placeholder: u32 = 0,
};

pub fn getState(map: *std.StringHashMap(Node), obj: anytype) error{OutOfMemory}!void {
    const ObjType = @TypeOf(obj);
    switch (ObjType) {
        uidefs.Node => switch (obj) {
            .window => |o| return getState(map, o),
            .label => |o| return getState(map, o),
            .button => |o| return getState(map, o),
        },
        uidefs.StringData => switch (obj) {
            .fixed => return,
            .dynamic => |d| {
                try map.put(d.name, .{});
                return;
            },
        },
        else => {},
    }
    switch (@typeInfo(ObjType)) {
        .Struct => |struct_info| {
            //switch (ObjType) {
            //    else => @compileError("todo: handle: " ++ @typeName(ObjType)),
            //}
            inline for (struct_info.fields) |field| {
                try getState(map, @field(obj, field.name));
            }
        },
        .Pointer => {
            for (obj) |*element| {
                try getState(map, element.*);
            }
        },
        else => @compileError("todo: handle: " ++ @typeName(ObjType)),
    }
}
