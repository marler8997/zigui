const uigen = @import("uigen");
pub fn main() !u8 {
    const rect = uigen.Rect{
        .width = .{ .fixed = 50 },
        .height = .{ .variable = .{ .init = 30 }},
        .rgba = .{ .variable = .{ .init = .{ .r = 255, .g = 0, .b = 0, .a = 255 } } },
        .listen_mouse_enter_exit = true,
    };
    return uigen.generate(&rect.base);
}
