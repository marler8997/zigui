const std = @import("std");
const XY = @import("xy.zig").XY;

const AnyWriter = @import("anywriter.zig").AnyWriter;
const anyWriter = @import("anywriter.zig").anyWriter;

pub const Axis = enum { x, y };
pub const Rgba = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn format(
        self: Rgba,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Rgba{{ .r = {}, .g = {}, .b = {}, .a = {} }}", .{
            self.r,
            self.g,
            self.b,
            self.a,
        });
    }
};

pub fn generate(visual: *const Visual) anyerror!u8 {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();

    const allocator = arena_instance.allocator();
    const full_cmdline = try std.process.argsAlloc(allocator);
    if (full_cmdline.len <= 1) {
        try std.io.getStdErr().writer().print("Usage: {s} OUT_FILE\n", .{
            std.fs.path.basename(full_cmdline[0])
        });
        return 0xff;
    }
    const args = full_cmdline[1..];
    if (args.len != 1) {
        std.log.err("expected 1 cmdline arg (OUT_FILE) but got {}", .{args.len});
        return 0xff;
    }

    const out_filename = args[0];
    var file = try std.fs.cwd().createFile(out_filename, .{});
    defer file.close();
    const file_writer = file.writer();
    const writer = anyWriter(&file_writer);

    try writer.writeAll(@embedFile("uigenprefix.zig"));
    try writer.print("pub const MouseButton = enum {{ }};\n", .{});
    try writer.print("pub const Renderer = struct {{\n", .{});
    try writer.print("    move: *const fn(*Renderer, x: i32, y: i32) void,\n", .{});
    try writer.print("    fillRect: *const fn(*Renderer, rgba: Rgba, XY(i32), XY(i32)) void,\n", .{});
    try writer.print("}};\n", .{});
    try writer.print("pub const Root = struct {{\n", .{});
    try visual.codegen(visual, writer, Indent{ .depth = 1 }, &[_][]const u8{ });
    try writer.print("}};\n", .{});
    return 0;
}

const Indent = struct {
    depth: u8,
    pub fn format(
        self: Indent,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        for (0 .. self.depth) |_| { try writer.writeAll("    "); }
    }
};

pub const Visual = struct {
    codegen: *const fn(
        *const Visual,
        AnyWriter,
        indent: Indent,
        path: []const []const u8,
    ) anyerror!void,
};

pub fn Arg(comptime T: type) type {
    return union(enum) {
        pub const is_ordered = switch (T) {
            u32 => true,
            Rgba => false,
            else => @compileError("todo: handle Arg of " ++ @typeName(T)),
        };

        fixed: T,
        variable: if (is_ordered) struct {
            init: T,
            min: ?T,
            max: ?T,
        } else struct {
            init: T,
        },

        const Self = @This();
        pub const ValueFormatter = struct {
            arg: Self,
            name: []const u8,
            pub fn format(
                self: ValueFormatter,
                comptime fmt: []const u8,
                options: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                _ = fmt;
                _ = options;
                switch (self.arg) {
                    .fixed => |v| try writer.print("{}", .{v}),
                    .variable => try writer.print("{s}", .{self.name}),
                }
            }
        };
        pub fn fmtValue(self: Self, name: []const u8) ValueFormatter {
            return ValueFormatter{ .arg = self, .name = name };
        }
    };
}

fn makePath(
    allocator: std.mem.Allocator,
    path: []const []const u8,
    name: []const u8,
) []const []const u8 {
    var sub_path = std.ArrayList([]const u8).init(allocator);
    defer sub_path.deinit();
    sub_path.appendSlice(path) catch @panic("OOM");
    sub_path.append(name) catch @panic("OOM");
    return sub_path.toOwnedSlice() catch @panic("OOM");
}

pub const Array = struct {
    base: Visual = .{
        .codegen = codegen,
    },
    axis: Axis,
    visuals: []const *const Visual,

    fn codegen(
        base: *const Visual,
        writer: AnyWriter,
        indent: Indent,
        path: []const []const u8,
    ) anyerror!void {
        const self = @fieldParentPtr(Array, "base", base);

        for (self.visuals, 0..) |visual, i| {
            var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena_instance.deinit();
            const allocator = arena_instance.allocator();
            const field_name = std.fmt.allocPrint(allocator, "element{}", .{i}) catch @panic("OOM");
            defer allocator.free(field_name);
            const sub_path = makePath(allocator, path, field_name);
            defer allocator.free(sub_path);
            try writer.print("{}const Element{} = struct {{\n", .{indent, i});
            try visual.codegen(visual, writer, .{ .depth = indent.depth + 1 }, sub_path);
            try writer.print("{}}};\n", .{indent});
        }

        for (self.visuals, 0..) |_, i| {
            try writer.print("{}element{}: @This().Element{1} = .{{}},\n", .{indent, i});
        }

        try writer.print("{}pub fn getWidth(self: @This()) u32 {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    var width: u32 = 0;\n", .{indent});
        for (self.visuals, 0..) |_, i| {
            switch (self.axis) {
                .x => {
                    try writer.print("{}    width += self.element{}.getWidth();\n", .{indent, i});
                },
                .y => {
                    try writer.print("{}    width = @max(width, self.element{}.getWidth());\n", .{indent, i});
                },
            }
        }
        try writer.print("{}    return width;\n", .{indent});
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}pub fn getHeight(self: @This()) u32 {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    var height: u32 = 0;\n", .{indent});
        for (self.visuals, 0..) |_, i| {
            switch (self.axis) {
                .x => {
                    try writer.print("{}    height = @max(height, self.element{}.getHeight());\n", .{indent, i});
                },
                .y => {
                    try writer.print("{}    height += self.element{}.getHeight();\n", .{indent, i});
                },
            }
        }
        try writer.print("{}    return height;\n", .{indent});
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}pub fn mouseExit(self: *@This()) void {{\n", .{indent});
        //
        // TODO: save the previous element that contains the mouse and use that
        //       to  limit how many elements we call
        //
        for (self.visuals, 0..) |_, i| {
            try writer.print("{}    self.element{}.mouseExit();\n", .{indent, i});
        }
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}pub fn mouseMove(self: *@This(), pos: XY(i32)) void {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});

        try writer.print("{}    if (pos.x < 0) @panic(\"codebug\");\n", .{indent});
        try writer.print("{}    if (pos.y < 0) @panic(\"codebug\");\n", .{indent});
        //
        // TODO: save the previous element that contains the mouse and use that
        //       to  limit how many elements we check
        //
        try writer.print("{}    var offset: i32 = 0;\n", .{indent});
        const main_width_height: []const u8 = switch (self.axis) { .x => "Width", .y => "Height" };
        const cross_width_height: []const u8 = switch (self.axis) { .x => "Height", .y => "Width" };
        const cross_axis: Axis = switch (self.axis) { .x => .y, .y => .x };
        for (self.visuals, 0..) |_, i| {
            try writer.print("{}    {{\n", .{indent});
            try writer.print("{}        const size: i32 = @intCast(self.element{}.get{s}());\n", .{indent, i, main_width_height});
            try writer.print("{}        const next_offset = offset + size;\n", .{indent});
            try writer.print("{}        if (pos.{s} >= offset and pos.{1s} < next_offset) {{\n", .{indent, @tagName(self.axis)});
            try writer.print("{}            const cross_size = self.element{}.get{s}();\n", .{indent, i, cross_width_height});
            try writer.print("{}            if (pos.{s} < cross_size) {{\n", .{indent, @tagName(cross_axis)});
            try writer.print("{}                self.element{}.mouseMove(\n", .{indent, i});
            try writer.print("{}                    .{{ .x = pos.x - {s}, .y = pos.y - {s}}},\n", .{
                indent,
                switch (self.axis) { .x => "offset", .y => "0" },
                switch (self.axis) { .x => "0", .y => "offset" },
            });
            try writer.print("{}                );\n", .{indent});
            try writer.print("{}            }} else {{\n", .{indent});
            try writer.print("{}                self.element{}.mouseExit();\n", .{indent, i});
            try writer.print("{}            }}\n", .{indent});
            try writer.print("{}        }} else {{\n", .{indent});
            try writer.print("{}            self.element{}.mouseExit();\n", .{indent, i});
            try writer.print("{}        }}\n", .{indent});
            try writer.print("{}        offset = next_offset;\n", .{indent});
            try writer.print("{}    }}\n", .{indent});
        }
        try writer.print("{}}}\n", .{indent});
//        try writer.print("    pub fn mouseButton(self: *@This(), pos: XY(i32), btn: MouseButton) void {{\n", .{});
//        try writer.print("        self.hackunused();\n", .{});
//        try writer.print("        _ = pos;\n", .{});
//        try writer.print("        _ = btn;\n", .{});
//        try writer.print("    }}\n", .{});
//        // TODO: button
//        // TODO: invalidateRect
//        // TODO: resize
        try writer.print("{}pub fn render(self: *@This(), renderer: *Renderer) void {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    var total_offset: i32 = 0;\n", .{indent});
        for (self.visuals, 0..) |_, i| {
            if (i > 0) {
                try writer.print("{}    {{\n", .{indent});
                try writer.print("{}        const size: i32 = @intCast(self.element{}.get{s}());\n", .{indent, i - 1, main_width_height});
                switch (self.axis) {
                    .x => {
                        try writer.print("{}        renderer.move(renderer, size, 0);\n", .{indent});
                    },
                    .y => {
                        try writer.print("{}        renderer.move(renderer, 0, size);\n", .{indent});
                    },
                }
                try writer.print("{}        total_offset += size;\n", .{indent});
                try writer.print("{}    }}\n", .{indent});
            }
            try writer.print("{}    self.element{}.render(renderer);\n", .{indent, i});
        }
        switch (self.axis) {
            .x => {
                try writer.print("{}    renderer.move(renderer, -total_offset, 0);\n", .{indent});
            },
            .y => {
                try writer.print("{}    renderer.move(renderer, 0, -total_offset);\n", .{indent});
            },
        }
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}// call to keep zig from complaining about self being unused\n", .{indent});
        try writer.print("{}fn hackunused(_: *const @This()) void {{ }}\n", .{indent});

        try writer.print("{}pub const vars = \n", .{indent});
        for (0 .. self.visuals.len) |i| {
            const prefix: []const u8 = if (i == 0) "  " else "++";
            try writer.print("{}    {s} subvars(&[_][]const u8 {{ \"element{}\" }}, @This().Element{2}.vars.len, @This().Element{2}.vars)\n", .{indent, prefix, i, });
        }
        try writer.print("{};\n", .{indent});
    }
};

pub const Rect = struct {
    base: Visual = .{
        .codegen = &codegen,
    },
    width: Arg(u32),
    height: Arg(u32),
    rgba: Arg(Rgba),
    listen_mouse_enter_exit: bool = false,

    fn codegen(
        base: *const Visual,
        writer: AnyWriter,
        indent: Indent,
        path: []const []const u8,
    ) anyerror!void {
        const self = @fieldParentPtr(Rect, "base", base);

        switch (self.width) {
            .fixed => {},
            .variable => |v| {
                try writer.print("{}width: u32 = {},\n", .{indent, v.init});
            },
        }
        switch (self.height) {
            .fixed => {},
            .variable => |v| {
                try writer.print("{}height: u32 = {},\n", .{indent, v.init});
            },
        }
        switch (self.rgba) {
            .fixed => {},
            .variable => |v| {
                try writer.print("{}rgba: Rgba = {},\n", .{indent, v.init});
            },
        }

        try writer.print("{}pub fn getWidth(self: @This()) u32 {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    return {};\n", .{indent, self.width.fmtValue("self.width")});
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}pub fn getHeight(self: @This()) u32 {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    return {};\n", .{indent, self.height.fmtValue("self.height")});
        try writer.print("{}}}\n", .{indent});
        //try writer.print("{}pub fn getRgba(self: @This()) Rgba {{\n", .{indent});
        //try writer.print("{}    self.hackunused();\n", .{indent});
        //try writer.print("{}    return {};\n", .{indent, self.rgba.fmtValue("self.rgba")});
        //try writer.print("{}}}\n", .{indent});
        try writer.print("{}pub fn mouseExit(self: *@This()) void {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        if (self.listen_mouse_enter_exit) {
            try writer.print("{}    std.log.info(\"MOUSE EXIT!\", .{{}});\n", .{indent});
        }
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}pub fn mouseMove(self: *@This(), pos: XY(i32)) void {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    if (pos.x < 0) @panic(\"codebug\");\n", .{indent});
        try writer.print("{}    if (pos.x >= self.getWidth()) @panic(\"codebug\");\n", .{indent});
        try writer.print("{}    if (pos.y < 0) @panic(\"codebug\");\n", .{indent});
        try writer.print("{}    if (pos.y >= self.getHeight()) @panic(\"codebug\");\n", .{indent});
        if (self.listen_mouse_enter_exit) {
            try writer.print("{}    std.log.info(\"MOUSE {{}}!\", .{{pos}});\n", .{indent});
        }
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}pub fn mouseButton(self: *@This(), pos: XY(i32), btn: MouseButton) void {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    _ = pos;\n", .{indent});
        try writer.print("{}    _ = btn;\n", .{indent});
        try writer.print("{}}}\n", .{indent});
        // TODO: button
        // TODO: invalidateRect
        // TODO: resize
        try writer.print("{}pub fn render(self: *@This(), renderer: *Renderer) void {{\n", .{indent});
        try writer.print("{}    self.hackunused();\n", .{indent});
        try writer.print("{}    renderer.fillRect(renderer, {}, .{{.x=0,.y=0}}, .{{.x=@intCast({}),.y=@intCast({})}});\n", .{
            indent,
            self.rgba.fmtValue("self.rgba"),
            self.width.fmtValue("self.width"),
            self.height.fmtValue("self.height"),
        });
        try writer.print("{}}}\n", .{indent});
        try writer.print("{}// call to keep zig from complaining about self being unused\n", .{indent});
        try writer.print("{}fn hackunused(_: *const @This()) void {{ }}\n", .{indent});

        try writer.print("{}pub const vars = [_]Variable{{\n", .{indent});
        switch (self.width) {
            .fixed => {},
            .variable => try writer.print("{}    {},\n", .{indent, fmtVariable(path, "width", .uint)}),
        }
        switch (self.height) {
            .fixed => {},
            .variable => try writer.print("{}    {},\n", .{indent, fmtVariable(path, "height", .uint)}),
        }
        switch (self.rgba) {
            .fixed => {},
            .variable => try writer.print("{}    {},\n", .{indent, fmtVariable(path, "rgba", .rgba)}),
        }
        try writer.print("{}}};\n", .{indent});
    }
};

const VariableType = enum {
    uint, rgba
};
pub const VariableFormatter = struct {
    path: []const []const u8,
    name: []const u8,
    @"type": VariableType,

    pub fn format(
        self: VariableFormatter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            ".{{ .@\"type\" = .{s}, .field_path = &[_][]const u8 {{",
            .{ @tagName(self.@"type") },
        );
        for (self.path) |name| {
            try writer.print(" \"{s}\",", .{name});
        }
        try writer.print(" \"{s}\"", .{self.name});
        try writer.print(" }} }}", .{});
    }
};
pub fn fmtVariable(
    path: []const []const u8,
    name: []const u8,
    t: VariableType,
) VariableFormatter {
    return .{
        .path = path,
        .name = name,
        .@"type" = t,
    };
}

//pub const StaticLabel = struct {
//    base: Visual,
//};
