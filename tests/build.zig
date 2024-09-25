const std = @import("std");
const sanitizers = @import("sanitizers");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // FIXME
    // {
    //     const exe = b.addExecutable(.{
    //         .name = "test-asan",
    //         .target = target,
    //         .optimize = optimize,
    //     });
    //     exe.addCSourceFile(.{
    //         .file = b.path("app/test.cc"),
    //         .flags = &.{"-fsanitize=address"},
    //     });
    //     sanitizers.buildASan(b, exe);
    //         b.installArtifact(exe);
    //         const run = b.addRunArtifact(exe);
    //         const run_step = b.step("asan", "Run the test-asan test");
    //         run_step.dependOn(&run.step);
    // }
    // LLVM 20
    {
        const libzig = b.addStaticLibrary(.{
            .name = "zig",
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("lib/array.zig"),
        });
        libzig.linkLibC();

        const exe = b.addExecutable(.{
            .name = "test-rtsan",
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibrary(libzig);
        exe.addCSourceFile(.{
            .file = b.path("app/test.cc"),
            .flags = &.{"-fsanitize=realtime"},
        });
        sanitizers.buildRTSan(b, exe);
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        const run_step = b.step("rtsan", "Run the test-rtsan test");
        run_step.dependOn(&run.step);
    }
}
