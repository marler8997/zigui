const uigen = @import("uigen");
pub fn main() !u8 {
    const rect = uigen.Rect{
        .width = .{ .fixed = 200 },
        .height = .{ .variable = .{ .init = 150, .min = null, .max = null }},
        .rgba = .{ .variable = .{ .init = .{ .r = 255, .g = 0, .b = 0, .a = 255 } } },
        .listen_mouse_enter_exit = true,
    };
    return uigen.generate(&rect.base);
}
