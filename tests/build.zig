const std = @import("std");
const sanitizers = @import("sanitizers");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigobj = b.addObject(.{
        .name = "zig",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("lib/array.zig"),
    });
    zigobj.linkLibC();

    // ASAN
    {
        const exe = b.addExecutable(.{
            .name = "test-asan",
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFile(.{
            .file = b.path("app/test.cc"),
            .flags = &.{"-fsanitize=address"},
        });
        exe.addObject(zigobj);
        sanitizers.buildASan(b, exe);
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        const run_step = b.step("asan", "Run the test-asan test");
        run_step.dependOn(&run.step);
    }
    // LSAN
    {
        const exe = b.addExecutable(.{
            .name = "test-lsan",
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFile(.{
            .file = b.path("app/test.cc"),
            .flags = &.{"-fsanitize=leak"},
        });
        exe.addObject(zigobj);
        sanitizers.buildLSan(b, exe);
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        const run_step = b.step("lsan", "Run the test-lsan test");
        run_step.dependOn(&run.step);
    }
    // RTSAN - need LLVM 20
    {
        const exe = b.addExecutable(.{
            .name = "test-rtsan",
            .target = target,
            .optimize = optimize,
        });
        exe.addObject(zigobj);
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
