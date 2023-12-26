const uigen = @import("uigen");
pub fn main() !u8 {
    const rect1 = uigen.Rect{
        .width = .{ .fixed = 50 },
        .height = .{ .variable = .{ .init = 30 }},
        .rgba = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
    };


    const inner_rect1 = uigen.Rect{
        .width = .{ .fixed = 30 },
        .height = .{ .fixed = 30 },
        .rgba = .{ .r = 0, .g = 100, .b = 255, .a = 255 },
    };
    const inner_rect2 = uigen.Rect{
        .width = .{ .fixed = 30 },
        .height = .{ .fixed = 13 },
        .rgba = .{ .r = 255, .g = 100, .b = 0, .a = 255 },
        .listen_mouse_enter_exit = true,
    };
    const inner_array = uigen.Array{
        .axis = .x,
        .visuals = &[_]*const uigen.Visual{
            &inner_rect1.base,
            &inner_rect2.base,
        },
    };

    const rect3 = uigen.Rect{
        .width = .{ .fixed = 60 },
        .height = .{ .fixed = 60 },
        .rgba = .{ .r = 100, .g = 0, .b = 255, .a = 255 },
    };
    const array = uigen.Array{
        .axis = .y,
        .visuals = &[_]*const uigen.Visual{
            &rect1.base,
            &inner_array.base,
            &rect3.base,
        },
    };
    return uigen.generate(&array.base);
}
