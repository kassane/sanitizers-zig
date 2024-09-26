const std = @import("std");

// [[clang::nonblocking]]
fn array() callconv(.C) void {

    // raw_c_allocator: Real-time violation: intercepted call to real-time unsafe function
    //                  `malloc` in real-time context!
    // c_allocator: Real-time violation: intercepted call to real-time unsafe function
    //              `posix_memalign` in real-time context!
    // page_allocator (no-libc/syscalls): None

    var arr = std.ArrayList([]const u8).init(std.heap.c_allocator);
    // defer arr.deinit();
    arr.append("foo") catch unreachable;
    arr.append("bar") catch unreachable;
    arr.append("baz") catch unreachable;
}

fn openfile() callconv(.C) void {
    const file = std.fs.cwd().openFile("build.zig.zon", .{}) catch unreachable;
    defer file.close();
}

comptime {
    @export(&array, .{
        .name = "ffi_zigarray",
        .linkage = .weak,
    });
    @export(&openfile, .{
        .name = "ffi_zig_openfile",
    });
}
