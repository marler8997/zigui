const std = @import("std");
const mem = std.mem;
const testing = std.testing;

/// AnyWriter is an instance of std.io.Writer that is able to wrap
/// any other std.io.Writer type and forward data to it.
///
/// AnyWriter enables std.io.Writer to be used in places where concrete
/// types are required such as function pointer parameters or as a field
/// in a struct.
pub const AnyWriter = std.io.Writer(
    AnyWriterContext,
    anyerror,
    anyWrite,
);

/// Takes a reference to a std.io.Writer and returns a AnyWriter
/// that forwards data to it.
pub fn anyWriter(writer_ref: anytype) AnyWriter {
    const Writer = switch (@typeInfo(@TypeOf(writer_ref))) {
        .Pointer => |info| info.child,
        else => @compileError("unexpected type given to anyWriter: " ++ @typeName(@TypeOf(writer_ref))),
    };
    const Wrap = struct {
        fn write(context: *const anyopaque, bytes: []const u8) anyerror!usize {
            const ul: *const Writer = @alignCast(@ptrCast(context));
            return ul.write(bytes);
        }
    };
    return .{
        .context = .{
            .context = @ptrCast(writer_ref),
            .writeFn = &Wrap.write,
        },
    };
}

const AnyWriterContext = struct {
    context: *const anyopaque,
    writeFn: *const fn (
        context: *const anyopaque,
        byte: []const u8,
    ) anyerror!usize,
};
fn anyWrite(
    context: AnyWriterContext,
    bytes: []const u8,
) anyerror!usize {
    return context.writeFn(context.context, bytes);
}

test "function pointer that takes writer" {
    const Wrap = struct {
        fn writeHello(writer: AnyWriter) anyerror!void {
            try writer.writeAll("hello");
        }
    };
    
    var buffer: [10]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    const func: *const fn(writer: AnyWriter) anyerror!void = &Wrap.writeHello;
    try func(anyWriter(&fbs.writer()));
    try testing.expect(mem.eql(u8, fbs.getWritten(), "hello"));
}

test "fixed buffer stream via AnyWriter" {
    var buffer: [10]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try anyWriter(&fbs.writer()).writeAll("Hello");
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Hello"));

    try anyWriter(&fbs.writer()).writeAll("world");
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));

    try testing.expectError(
        error.NoSpaceLeft,
        anyWriter(&fbs.writer()).writeAll("!"),
    );
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));
}
