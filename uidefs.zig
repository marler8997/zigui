pub const StringData = union(enum) {
    fixed: []const u8,
    dynamic: struct {
        name: []const u8,
    },
};

pub const Node = union(enum) {
    window: Window,
    label: Label,
    button: Button,

    pub const Window = struct {
        title: StringData,
        body: []const Node,
    };
    pub const Label = struct {
        content: StringData,
    };
    pub const Button = struct {
        label: StringData,
    };
};

