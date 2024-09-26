/// Enter real-time context.
/// When in a real-time context, RTSan interceptors will error if realtime
/// violations are detected. Calls to this method are injected at the code
/// generation stage when RTSan is enabled.
/// corresponds to a [[clang::nonblocking]] attribute.
pub const __rtsan_realtime_enter = @extern(?*const fn () callconv(.C) void, .{
    .name = "__rtsan_realtime_enter",
    .linkage = .weak,
}).?;
/// Exit the real-time context.
/// When not in a real-time context, RTSan interceptors will simply forward
/// intercepted method calls to the real methods.
pub const __rtsan_realtime_exit = @extern(?*const fn () callconv(.C) void, .{
    .name = "__rtsan_realtime_exit",
    .linkage = .weak,
}).?;
/// Re-enable all RTSan error reporting.
/// Must follow a call to `__rtsan_disable`.
pub const __rtsan_enable = @extern(?*const fn () callconv(.C) void, .{
    .name = "__rtsan_enable",
    .linkage = .weak,
}).?;
/// Disable all RTSan error reporting in an otherwise real-time context.
/// Must be paired with a call to `__rtsan_enable`
pub const __rtsan_disable = @extern(?*const fn () callconv(.C) void, .{
    .name = "__rtsan_disable",
    .linkage = .weak,
}).?;
/// Initializes rtsan if it has not been initialized yet.
/// Used by the RTSan runtime to ensure that rtsan is initialized before any
/// other rtsan functions are called.
pub const __rtsan_ensure_initialized = @extern(?*const fn () callconv(.C) void, .{
    .name = "__rtsan_ensure_initialized",
    .linkage = .weak,
}).?;
