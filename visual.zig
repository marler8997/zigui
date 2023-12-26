const std = @import("std");
const XY = @import("xy.zig").XY;

const AnyWriter = @import("anywriter.zig").AnyWriter;
const anyWriter = @import("anywriter.zig").anyWriter;

pub fn main() !void {
    const rect = Rect{
        .tl = .{ .x  = 10, .y = 15 },
        .br = .{ .x  = 20, .y = 18 },
        .rgba = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
    };

    const stdout = std.io.getStdOut().writer();
    const writer = anyWriter(&stdout);

    var next_name_suffix: u32 = 0;
    try rect.base.codegen(&rect.base, &next_name_suffix, writer);
}

