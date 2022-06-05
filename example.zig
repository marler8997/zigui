const std = @import("std");
const uidefs = @import("uidefs.zig");
const statedefs = @import("statedefs.zig");

pub fn main() !void {
    const example_counter = uidefs.Node { .window = .{
        .title = .{ .fixed = "Counter Example" },
        .body = &[_]uidefs.Node {
            .{ .label = .{ .content = .{ .dynamic = .{ .name = "count" } } } },
            .{ .button = .{ .label = .{ .fixed = "decrement" } } },
            .{ .button = .{ .label = .{ .fixed = "increment" } } },
        },
    }};
    
    std.log.info("{}", .{example_counter});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var state_map = std.StringHashMap(statedefs.Node).init(arena.allocator());
    try statedefs.getState(&state_map, example_counter);
    {
        var it = state_map.iterator();
        while (it.next()) |kv| {
            std.log.info("{s}: {}", .{kv.key_ptr.*, kv.value_ptr.*});
        }
    }
}

fn oom(e: anytype) noreturn { switch (e) { error.OutOfMemory => @panic("Out of memory") } }
