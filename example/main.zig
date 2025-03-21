const std = @import("std");
const generated_ui = @import("generated_ui");
const XY = generated_ui.XY;
const Rgba = generated_ui.Rgba;

const win32 = struct {
    usingnamespace @import("win32").zig;
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").system.library_loader;
    usingnamespace @import("win32").system.memory;
    usingnamespace @import("win32").ui.input.keyboard_and_mouse;
    usingnamespace @import("win32").ui.windows_and_messaging;
    usingnamespace @import("win32").graphics.gdi;
};

const L = win32.L;
const HINSTANCE = win32.HINSTANCE;
const CW_USEDEFAULT = win32.CW_USEDEFAULT;
const MSG = win32.MSG;
const HWND = win32.HWND;
const HDC = win32.HDC;
const HBRUSH = win32.HBRUSH;
const HPEN = win32.HPEN;
const RECT = win32.RECT;

const global = struct {
    pub var root = generated_ui.Root{ };
};

fn XYAndSize(comptime T: type) type {
    return struct {
        x: T,
        y: T,
        w: T,
        h: T,
    };
}

fn getMonitorRect(hWnd: HWND) RECT {
    const monitor = win32.MonitorFromWindow(hWnd, win32.MONITOR_DEFAULTTOPRIMARY) orelse
        std.debug.panic("MonitorFromWindow failed, error={}", .{win32.GetLastError()});

    var info: win32.MONITORINFO = undefined;
    info.cbSize = @sizeOf(@TypeOf(info));
    if (0 == win32.GetMonitorInfoW(monitor, &info))
        std.debug.panic("GetMonitorInfo failed, error={}", .{win32.GetLastError()});
    return info.rcWork;
}

fn calcCenteredWindowRect(monitor_rect: RECT, desired_size: XY(i32)) XYAndSize(i32) {
    const desktop_size_x = monitor_rect.right - monitor_rect.left;
    const desktop_size_y = monitor_rect.bottom - monitor_rect.top;

    var window_size = desired_size;
    if (desktop_size_x < desired_size.x) {
        std.log.info("clamping window width {} to desktop {}", .{desired_size.x, desktop_size_x});
        window_size.x = desktop_size_x;
    }
    if (desktop_size_y < desired_size.y) {
        std.log.info("clamping window height {} to desktop {}", .{desired_size.y, desktop_size_y});
        window_size.y = desktop_size_y;
    }

    const left = monitor_rect.left + @divTrunc(desktop_size_x - window_size.x, 2);
    const top  = monitor_rect.top  + @divTrunc(desktop_size_y - window_size.y, 2);
    return .{
        .x = left, .y = top,
        .w = window_size.x, .h = window_size.y,
    };
}

fn clientToWindowSize(
    client_size: XY(i32),
    style: win32.WINDOW_STYLE,
    menu: i32,
    ex_style: win32.WINDOW_EX_STYLE,
    //dpi: u32,
) XY(i32) {
    var rect = RECT{
        .left = 0, .top = 0,
        .right = client_size.x,
        .bottom = client_size.y,
    };
    if (0 == win32.AdjustWindowRectEx(&rect, style, menu, ex_style))
        std.debug.panic("AdjustWindowRectEx failed, error={}", .{win32.GetLastError()});
    return .{
        .x = rect.right - rect.left,
        .y = rect.bottom - rect.top,
    };
}

pub fn main() void {
    const CLASS_NAME_EXAMPLE = L("ExampleWindow");
    const wc_example = win32.WNDCLASSW{
        .style = .{},
        .lpfnWndProc = WndProcExample,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = win32.GetModuleHandleW(null),
        .hIcon = null,
        .hCursor = win32.LoadCursorA(null, @ptrCast(win32.IDC_ARROW)),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = CLASS_NAME_EXAMPLE,
    };
    if (0 == win32.RegisterClassW(&wc_example))
        fatal("RegisterClass failed, error={}", .{win32.GetLastError()});

    const window_style_example: win32.WINDOW_STYLE = .{
        .BORDER = 1,
        .DLGFRAME = 1,
        .SYSMENU=1,
        .THICKFRAME=1,
    };
    const window_style_example_ex: win32.WINDOW_EX_STYLE = .{};
    const hwnd_example = win32.CreateWindowExW(
        window_style_example_ex,
        CLASS_NAME_EXAMPLE, // Window class
        L("Example"),
        window_style_example,
        0, 0, // position
        0, 0, // size
        null, // Parent window
        null, // Menu
        win32.GetModuleHandleW(null), // Instance handle
        null, // Additional application data
    ) orelse {
        std.log.err("CreateWindow failed with {}", .{win32.GetLastError()});
        std.process.exit(0xff);
    };

    const example_window_desired_size = clientToWindowSize(
        .{
            .x = @intCast(global.root.getWidth()),
            .y = @intCast(global.root.getHeight()),
        },
        window_style_example,
        0, // menu
        window_style_example_ex,
    );

    const monitor_rect = getMonitorRect(hwnd_example);
    const window_rect_example = calcCenteredWindowRect(monitor_rect, example_window_desired_size);
    std.log.info("desired window size {}x{} to {}x{} at {},{}", .{
        example_window_desired_size.x,
        example_window_desired_size.y,
        window_rect_example.w, window_rect_example.h,
        window_rect_example.x, window_rect_example.y,
    });

    // TODO: position the window close to the systray
    std.debug.assert(0 != win32.SetWindowPos(
        hwnd_example,
        null,
        window_rect_example.x, window_rect_example.y,
        window_rect_example.w, window_rect_example.h,
        win32.SET_WINDOW_POS_FLAGS{
            .NOZORDER = 1,
        },
    ));
    _ = win32.ShowWindow(hwnd_example, win32.SW_SHOW);

    createControlWindow(window_rect_example);

    var msg: MSG = undefined;
    while (win32.GetMessageW(&msg, null, 0, 0) != 0) {
        // No need for TranslateMessage since we don't use WM_*CHAR messages
        //_ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
}

fn createControlWindow(window_rect_example: XYAndSize(i32)) void {
    const CLASS_NAME = L("ControlWindow");
    const wc_control = win32.WNDCLASSW{
        .style = .{},
        .lpfnWndProc = WndProcControl,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = win32.GetModuleHandleW(null),
        .hIcon = null,
        .hCursor = win32.LoadCursorA(null, @ptrCast(win32.IDC_ARROW)),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = CLASS_NAME,
    };
    if (0 == win32.RegisterClassW(&wc_control))
        fatal("RegisterClass failed, error={}", .{win32.GetLastError()});

    const window_style: win32.WINDOW_STYLE = .{
        .BORDER = 1,
        .DLGFRAME = 1,
        .SYSMENU=1,
        .THICKFRAME=1,
    };
    const window_style_ex: win32.WINDOW_EX_STYLE = .{};
    const hWnd = win32.CreateWindowExW(
        window_style_ex,
        CLASS_NAME, // Window class
        L("Controls"),
        window_style,
        0, 0, // position
        0, 0, // size
        null, // Parent window
        null, // Menu
        win32.GetModuleHandleW(null), // Instance handle
        null, // Additional application data
    ) orelse {
        std.log.err("CreateWindow failed with {}", .{win32.GetLastError()});
        std.process.exit(0xff);
    };

    var next_y: i32 = 20;
    addControls(hWnd, &next_y);
    const window_size = clientToWindowSize(
        .{
            // TODO: base size on the number of controls
            .x = 200,
            .y = next_y,
        },
        window_style,
        0, // menu
        window_style_ex,
    );

    std.log.info("control window at {},{}", .{
        window_rect_example.x - window_size.x,
        // TODO: center the y axis?
        window_rect_example.y,
    });

    // TODO: position the window close to the systray
    std.debug.assert(0 != win32.SetWindowPos(
        hWnd,
        null,
        window_rect_example.x - window_size.x,
        // TODO: center the y axis?
        window_rect_example.y,
        window_size.x, window_size.y,
        win32.SET_WINDOW_POS_FLAGS{
            .NOZORDER = 1,
        },
    ));
    _ = win32.ShowWindow(hWnd, win32.SW_SHOW);
}

const var_event_reserve_count = 10;
fn addControls(hWnd: HWND, y: *i32) void {
    const line_height = 20;

    const label_width = 100;
    inline for (generated_ui.Root.vars, 1..) |v, i| {
        const event_base = var_event_reserve_count * i;
        const field_path = comptime v.fieldPathString();
        createText(
            L(&field_path),
            10, y.*,
            label_width, line_height,
            hWnd,
            //@ptrFromInt(i),
        );
        switch (v.@"type") {
            .rgba => {},
            .uint => {
                createButton(
                    L("-"),
                    10 + label_width, y.*,
                    20, line_height,
                    hWnd,
                    @ptrFromInt(event_base),
                );
                createButton(
                    L("+"),
                    10 + label_width + 20, y.*,
                    20, line_height,
                    hWnd,
                    @ptrFromInt(event_base + 1),
                );
            },
        }

        y.* += line_height;
    }
}

fn createText(
    text: [*:0]const u16,
    x: i32, y: i32,
    width: i32, height: i32,
    parent: HWND,
) void {
    _ = win32.CreateWindowExW(
        .{},
        L("STATIC"),
        text,
        .{
            .CHILD=1,
            .VISIBLE=1,
            // SS_CENTER?
        },
        x, y,
        width, height,
        parent, // Parent window
        null, // menu
        null, // Instance handle
        null, // Additional application data
    ) orelse fatal(
        "CreateWindow for text failed, error={}", .{win32.GetLastError()}
    );
    //if (0 == win32.SetWindowText(wnd, text))
    //fatal("SetWindowText failed, error={}", .{win32.GetLastError()});
}

fn createButton(
    text: [*:0]const u16,
    x: i32, y: i32,
    width: i32, height: i32,
    parent: HWND,
    menu: win32.HMENU,
) void {
    _ = win32.CreateWindowExW(
        .{},
        L("BUTTON"),
        text,
        .{
            .CHILD=1,
            .VISIBLE=1,
            .TABSTOP=1,
        },
        x, y,
        width, height,
        parent, // Parent window
        menu,
        null, // Instance handle
        null, // Additional application data
    ) orelse fatal(
        "CreateWindow for button failed, error={}", .{win32.GetLastError()}
    );
}


pub const Renderer = struct {
    base: generated_ui.Renderer = .{
        .move = move,
        .fillRect = fillRect,
    },
    hdc: HDC,
    offset: XY(i32) = .{ .x = 0, .y = 0 },

    fn move(base: *generated_ui.Renderer, x: i32, y: i32) void {
        const self: *Renderer = @fieldParentPtr("base", base);
        self.offset.x += x;
        self.offset.y += y;
    }
    fn fillRect(base: *generated_ui.Renderer, rgba: Rgba, tl: XY(i32), br: XY(i32)) void {
        const self: *Renderer = @fieldParentPtr("base", base);
        const rect = RECT{
            .left = self.offset.x + tl.x,
            .top = self.offset.y + tl.y,
            .right = self.offset.x + br.x,
            .bottom = self.offset.y + br.y,
        };
        const rgb = noAlpha(rgba) orelse @panic("todo");
        const brush = win32.CreateSolidBrush(rgb.colorRef()) orelse
            fatal("CreateSolidBrush failed, error={}", .{win32.GetLastError()});
        defer {
            if (0 == win32.DeleteObject(brush))
                fatal("DeleteObject for hbrush failed, error={}", .{win32.GetLastError()});
        }
        if (0 == win32.FillRect(self.hdc, &rect, brush))
            fatal("FillRect failed, error={}", .{win32.GetLastError()});
    }
};
pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.log.err(fmt, args);
    // TODO: detect if there is a console or not, only show message box
    //       if there is not a console
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const msg = std.fmt.allocPrintZ(arena.allocator(), fmt, args) catch @panic("Out of memory");
    const result = win32.MessageBoxA(null, msg.ptr, null, win32.MB_OK);
    std.log.info("MessageBox result is {}", .{result});
    std.process.exit(0xff);
}

const Rgb = struct {
    r: u8,
    g: u8,
    b: u8,
    fn colorRef(self: Rgb) u32 {
        return
            (@as(u32, self.r) <<  0) |
            (@as(u32, self.g) <<  8) |
            (@as(u32, self.b) << 16) ;
    }
};
fn noAlpha(rgba: Rgba) ?Rgb {
    if (rgba.a != 255) return null;
    return .{ .r = rgba.r, .g = rgba.g, .b = rgba.b };
}

fn get_x_lparam(lParam: win32.LPARAM) i16 {
    return @intCast(lParam & 0xffff);
}
fn get_y_lparam(lParam: win32.LPARAM) i16 {
    return @intCast((lParam >> 16) & 0xffff);
}

fn WndProcExample(
    hWnd: HWND,
    uMsg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(std.os.windows.WINAPI) win32.LRESULT {
    //if (hWnd != global.hwnd_example and uMsg != win32.WM_CREATE) @panic("codebug");

    switch (uMsg) {
        // TODO: handle when the mouse exits the window
        win32.WM_MOUSEMOVE => {
            const pos = XY(i32){
                .x = get_x_lparam(lParam),
                .y = get_y_lparam(lParam),
            };
            if (pos.x >= 0 and pos.x < global.root.getWidth() and pos.y >= 0 and pos.y < global.root.getHeight()) {
                global.root.mouseMove(pos);
            } else {
                global.root.mouseExit();
            }
        },
        //win32.WM_KEYDOWN => { wmKey(wParam, lParam, .down); return 0; },
        //win32.WM_KEYUP => { wmKey(wParam, lParam, .up); return 0; },
        win32.WM_DESTROY => {
            win32.PostQuitMessage(0);
            return 0;
        },
        win32.WM_PAINT => {
            var ps: win32.PAINTSTRUCT = undefined;
            const hdc = win32.BeginPaint(hWnd, &ps) orelse
                std.debug.panic("BeginPaint failed, error={}", .{win32.GetLastError()});

            var renderer = Renderer{ .hdc = hdc };
            global.root.render(&renderer.base);

            _ = win32.EndPaint(hWnd, &ps);
            return 0;
        },
        //win32.WM_SIZE => {
        //// since we "stretch" the image accross the full window, we
        //// always invalidate the full client area on each window resize
        //std.debug.assert(0 != win32.InvalidateRect(hWnd, null, 0));
        //},
        else => {},
    }
    return win32.DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

fn WndProcControl(
    hWnd: HWND,
    uMsg: u32,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) callconv(std.os.windows.WINAPI) win32.LRESULT {
    switch (uMsg) {
        win32.WM_DESTROY => {
            win32.PostQuitMessage(0);
            return 0;
        },
        win32.WM_COMMAND => {
            const var_index = @divTrunc(wParam, var_event_reserve_count);
            if (var_index >= generated_ui.Root.vars.len) {
                std.log.err("WM_COMMAND for id {} (index {}) out of range", .{wParam, var_index});
                return 0;
            } else {
                std.log.info("TODO: handle WM_COMMAND for id {} (index {})", .{wParam, var_index});
                return 0;
            }
        },
        else => {},
    }
    return win32.DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

fn getClientSize(hWnd: HWND) XY(i32) {
    var rect: RECT = undefined;
    if (0 == win32.GetClientRect(hWnd, &rect))
        fatal("GetClientRect failed, error={}", .{win32.GetLastError()});
    return .{
        .x = rect.right - rect.left,
        .y = rect.bottom - rect.top,
    };
}
