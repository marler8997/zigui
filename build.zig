const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    //const target = b.standardTargetOptions(.{});
    //const optimize = b.standardOptimizeOption(.{});

    const zigwin32 = b.dependency("zigwin32", .{});
    const uigen = b.addModule("uigen", .{
        .source_file = .{ .path = "uigen.zig" },
    });

    inline for (&[_][]const u8 {
        "rect",
        "array",
    }) |example_name| {
        const gen_exe = b.addExecutable(.{
            .name = "example-" ++ example_name ++ "-gen",
            .root_source_file = .{ .path = "example/" ++ example_name ++ ".zig" },
            .single_threaded = true,
        });
        gen_exe.addModule("uigen", uigen);
        const run_gen = b.addRunArtifact(gen_exe);
        const out_file = run_gen.addOutputFileArg(example_name ++ ".gen.zig");

        const gen_module = b.createModule(.{
            .source_file = out_file,
        });
        const exe = b.addExecutable(.{
            .name = "example-" ++ example_name,
            .root_source_file = .{ .path = "example/main.zig" },
            .single_threaded = true,
        });
        exe.addModule("win32", zigwin32.module("zigwin32"));
        exe.addModule("generated_ui", gen_module);

        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        b.step("example-" ++ example_name, "run example").dependOn(&run.step);
    }
}