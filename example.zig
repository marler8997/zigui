const std = @import("std");
const uidefs = @import("uidefs.zig");
const statedefs = @import("statedefs.zig");
const XY = @import("xy.zig").XY;

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

    {
        const label = uidefs.Node{ .label = .{ .content = .{ .fixed = "Hello" } } };
        var renderer = LogRenderer{ };
        render(&renderer.base, label);
    }
}

fn oom(e: anytype) noreturn { switch (e) { error.OutOfMemory => @panic("Out of memory") } }

pub const Renderer = struct {
    drawText: *const fn(*Renderer, XY(i32), []const u8) void,
    fillRect: *const fn(*Renderer, XY(i32), XY(i32)) void,
};

const LogRenderer = struct {
    base: Renderer = .{
        .drawText = drawText,
        .fillRect = fillRect,
    },
    fn drawText(base: *Renderer, pos: XY(i32), text: []const u8) void {
        _ = base;
        std.log.info("drawText {},{} '{s}'", .{pos.x, pos.y, text});
    }
    fn fillRect(base: *Renderer, top_left: XY(i32), bottom_right: XY(i32)) void {
        _ = base;
        std.log.info("fillRect {},{} {},{}", .{
            top_left.x, top_left.y,
            bottom_right.x, bottom_right.y,
        });
    }
};

fn render(renderer: *Renderer, node: uidefs.Node) void {
    switch (node) {
        .window => @panic("todo"),
        .label => |label| switch (label.content) {
            .fixed => |s| renderer.drawText(renderer, .{.x=0,.y=0}, s),
            .dynamic => @panic("todo"),
        },
        .button => @panic("todo"),
    }
}
