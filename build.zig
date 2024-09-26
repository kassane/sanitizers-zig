const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = RTSanModule(b);
}

pub fn RTSanModule(b: *std.Build) *std.Build.Module {
    return b.addModule("rtsan", .{
        .root_source_file = b.path("bindings/rtsan.zig"),
    });
}

pub fn buildASan(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const dep = b.dependency("compiler-rt", .{});
    lib.root_module.sanitize_c = false;
    if (!lib.root_module.resolved_target.?.query.isNative()) lib.linkage = .dynamic;

    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("lib"));
    lib.addCSourceFiles(.{
        .root = dep.path("lib/asan"),
        .files = &.{
            "asan_activation.cpp",
            "asan_allocator.cpp",
            "asan_debugging.cpp",
            "asan_descriptions.cpp",
            "asan_errors.cpp",
            "asan_fake_stack.cpp",
            "asan_flags.cpp",
            "asan_globals.cpp",
            "asan_interceptors.cpp",
            "asan_interceptors_memintrinsics.cpp",
            "asan_memory_profile.cpp",
            "asan_new_delete.cpp",
            "asan_poisoning.cpp",
            "asan_preinit.cpp",
            "asan_premap_shadow.cpp",
            "asan_report.cpp",
            "asan_rtl.cpp",
            "asan_rtl_static.cpp",
            "asan_shadow_setup.cpp",
            "asan_stack.cpp",
            "asan_stats.cpp",
            "asan_thread.cpp",
            "asan_suppressions.cpp",
        },
    });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/asan"),
        .files = switch (lib.rootModuleTarget().os.tag) {
            .windows => &.{
                "asan_malloc_win.cpp",
                "asan_globals_win.cpp",
                "asan_win.cpp",
                "asan_win_dll_thunk.cpp",
                "asan_win_dynamic_runtime_thunk.cpp",
                "asan_win_weak_interception.cpp",
            },
            .fuchsia => &.{
                "asan_fuchsia.cpp",
            },
            .macos => &.{
                "asan_mac.cpp",
                "asan_malloc_mac.cpp",
                "asan_posix.cpp",
            },
            .linux => &.{
                "asan_linux.cpp",
                "asan_malloc_linux.cpp",
                "asan_posix.cpp",
            },
            else => &.{},
        },
        .flags = cxxflags,
    });
    // lib.addCSourceFiles(.{
    //     .root = dep.path("lib/asan_abi"),
    //     .files = &.{
    //         "asan_abi.cpp",
    //         // "asan_abi_shim.cpp",
    //     },
    //     .flags = cxxflags,
    // });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/lsan"),
        .files = switch (lib.rootModuleTarget().os.tag) {
            .linux => &.{
                "lsan_linux.cpp",
                "lsan_common_linux.cpp",
            },
            .macos => &.{
                "lsan_mac.cpp",
                "lsan_common_mac.cpp",
                "lsan_malloc_mac.cpp",
            },
            .fuchsia => &.{
                "lsan_common_fuchsia.cpp",
                "lsan_fuchsia.cpp",
            },
            else => @panic("unsupported os"),
        },
        .flags = cxxflags,
    });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/lsan"),
        .files = &.{
            "lsan_common.cpp",
        },
        .flags = cxxflags,
    });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/ubsan"),
        .files = &.{
            "ubsan_diag.cpp",
            "ubsan_flags.cpp",
            "ubsan_init.cpp",
            "ubsan_monitor.cpp",
            "ubsan_type_hash.cpp",
            "ubsan_type_hash_itanium.cpp",
            "ubsan_type_hash_win.cpp",
            "ubsan_value.cpp",
            "ubsan_win_dll_thunk.cpp",
            "ubsan_win_dynamic_runtime_thunk.cpp",
            "ubsan_win_weak_interception.cpp",
        },
        .flags = cxxflags,
    });
    if (!lib.rootModuleTarget().isDarwin())
        lib.addAssemblyFile(dep.path("lib/asan/asan_interceptors_vfork.S"));
    if (lib.rootModuleTarget().cpu.arch.isX86())
        lib.addAssemblyFile(dep.path("lib/asan/asan_rtl_x86_64.S"));
    if (lib.rootModuleTarget().abi != .msvc) {
        lib.linkLibCpp();
    } else {
        lib.linkLibC();
    }
    buildInterception(lib, dep);
    buildSanCommon(lib, dep);
}

pub fn buildLSan(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const dep = b.dependency("compiler-rt", .{});
    lib.root_module.sanitize_c = false;
    if (!lib.root_module.resolved_target.?.query.isNative()) lib.linkage = .dynamic;

    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("lib"));
    lib.addCSourceFiles(.{
        .root = dep.path("lib/lsan"),
        .files = switch (lib.rootModuleTarget().os.tag) {
            .linux => &.{
                "lsan_linux.cpp",
                "lsan_common_linux.cpp",
            },
            .macos => &.{
                "lsan_mac.cpp",
                "lsan_common_mac.cpp",
                "lsan_malloc_mac.cpp",
            },
            .fuchsia => &.{
                "lsan_common_fuchsia.cpp",
                "lsan_fuchsia.cpp",
            },
            else => @panic("unsupported os"),
        },
        .flags = cxxflags,
    });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/lsan"),
        .files = &.{
            "lsan.cpp",
            "lsan_allocator.cpp",
            "lsan_common.cpp",
            "lsan_interceptors.cpp",
            "lsan_posix.cpp",
            "lsan_preinit.cpp",
            "lsan_thread.cpp",
        },
        .flags = cxxflags,
    });
    if (lib.rootModuleTarget().abi != .msvc) {
        lib.linkLibCpp();
    } else {
        lib.linkLibC();
    }
    buildInterception(lib, dep);
    buildSanCommon(lib, dep);
}

fn buildInterception(lib: *std.Build.Step.Compile, dependency: ?*std.Build.Dependency) void {
    const dep = dependency orelse @panic("compiler-rt dependency not provided");

    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("lib"));
    lib.addCSourceFiles(.{
        .root = dep.path("lib/interception"),
        .files = switch (lib.rootModuleTarget().os.tag) {
            .windows => &.{
                "interception_win.cpp",
            },
            .linux => &.{
                "interception_linux.cpp",
            },
            .macos => &.{
                "interception_mac.cpp",
            },
            else => &.{},
        },
        .flags = cxxflags,
    });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/interception"),
        .files = &.{"interception_type_test.cpp"},
        .flags = cxxflags,
    });
}
fn buildSanCommon(lib: *std.Build.Step.Compile, dependency: ?*std.Build.Dependency) void {
    const dep = dependency orelse @panic("compiler-rt dependency not provided");

    const has_libc = lib.root_module.link_libc orelse false;
    const has_libcpp = lib.root_module.link_libcpp orelse false;
    const has_linked = if (lib.rootModuleTarget().abi != .msvc)
        has_libcpp
    else
        has_libc;

    const need_libc = if (has_linked) &[_][]const u8{
        "sanitizer_posix_libcdep.cpp",
        "sanitizer_symbolizer_posix_libcdep.cpp",
        "sanitizer_linux_libcdep.cpp",
        "sanitizer_stoptheworld_linux_libcdep.cpp",
        "sanitizer_unwind_linux_libcdep.cpp",
        "sanitizer_mac_libcdep.cpp",
        "sanitizer_stoptheworld_netbsd_libcdep.cpp",
        "sanitizer_common_libcdep.cpp",
        "sanitizer_coverage_libcdep_new.cpp",
        "sanitizer_stacktrace_libcdep.cpp",
        "sanitizer_symbolizer_libcdep.cpp",
    } else &[_][]const u8{
        "sanitizer_common_nolibc.cpp",
    };

    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("lib"));
    lib.addCSourceFiles(.{
        .root = dep.path("lib/sanitizer_common"),
        .files = need_libc,
        .flags = cxxflags,
    });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/sanitizer_common"),
        .files = switch (lib.rootModuleTarget().os.tag) {
            .fuchsia => &.{
                "sanitizer_coverage_fuchsia.cpp",
                "sanitizer_fuchsia.cpp",
                "sanitizer_procmaps_fuchsia.cpp",
                "sanitizer_stoptheworld_fuchsia.cpp",
                "sanitizer_symbolizer_report_fuchsia.cpp",
                "sanitizer_symbolizer_markup_fuchsia.cpp",
                "sanitizer_unwind_fuchsia.cpp",
            },
            .freebsd => &.{
                "sanitizer_platform_limits_freebsd.cpp",
                "sanitizer_procmaps_bsd.cpp",
                "sanitizer_posix.cpp",
                "sanitizer_platform_limits_posix.cpp",
            },
            .linux => &.{
                if (lib.rootModuleTarget().cpu.arch == .s390x)
                    "sanitizer_linux_s390.cpp"
                else
                    "sanitizer_linux.cpp",
                "sanitizer_posix.cpp",
                "sanitizer_platform_limits_linux.cpp",
                "sanitizer_platform_limits_posix.cpp",
                "sanitizer_procmaps_linux.cpp",
            },
            .macos => &.{
                "sanitizer_mac.cpp",
                "sanitizer_posix.cpp",
                "sanitizer_procmaps_mac.cpp",
                "sanitizer_stoptheworld_mac.cpp",
                "sanitizer_symbolizer_mac.cpp",
                "sanitizer_platform_limits_posix.cpp",
            },
            .netbsd => &.{
                "sanitizer_netbsd.cpp",
                "sanitizer_platform_limits_netbsd.cpp",
                "sanitizer_procmaps_bsd.cpp",
                "sanitizer_posix.cpp",
            },
            .solaris => &.{
                "sanitizer_platform_limits_solaris.cpp",
                "sanitizer_solaris.cpp",
                "sanitizer_procmaps_solaris.cpp",
            },
            .windows => &.{
                "sanitizer_coverage_win_dll_thunk.cpp",
                "sanitizer_coverage_win_dynamic_runtime_thunk.cpp",
                "sanitizer_coverage_win_sections.cpp",
                "sanitizer_coverage_win_weak_interception.cpp",
                "sanitizer_unwind_win.cpp",
                "sanitizer_win.cpp",
                "sanitizer_stoptheworld_win.cpp",
                "sanitizer_win_dll_thunk.cpp",
                "sanitizer_win_dynamic_runtime_thunk.cpp",
                "sanitizer_win_weak_interception.cpp",
                "sanitizer_symbolizer_win.cpp",
            },
            else => &.{},
        },
        .flags = cxxflags,
    });
    lib.addCSourceFiles(.{
        .root = dep.path("lib/sanitizer_common"),
        .files = &.{
            "sancov_flags.cpp",
            "sanitizer_allocator.cpp",
            "sanitizer_allocator_checks.cpp",
            "sanitizer_allocator_report.cpp",
            "sanitizer_chained_origin_depot.cpp",
            "sanitizer_common.cpp",
            "sanitizer_deadlock_detector1.cpp",
            "sanitizer_deadlock_detector2.cpp",
            "sanitizer_dl.cpp",
            "sanitizer_errno.cpp",
            "sanitizer_file.cpp",
            "sanitizer_flag_parser.cpp",
            "sanitizer_flags.cpp",
            "sanitizer_libc.cpp",
            "sanitizer_libignore.cpp",
            "sanitizer_mutex.cpp",
            "sanitizer_printf.cpp",
            "sanitizer_procmaps_common.cpp",
            "sanitizer_range.cpp",
            "sanitizer_stack_store.cpp",
            "sanitizer_stackdepot.cpp",
            if (lib.rootModuleTarget().cpu.arch.isSPARC())
                "sanitizer_stacktrace_sparc.cpp"
            else
                "sanitizer_stacktrace.cpp",
            "sanitizer_stacktrace_printer.cpp",
            "sanitizer_suppressions.cpp",
            "sanitizer_symbolizer.cpp",
            "sanitizer_symbolizer_libbacktrace.cpp",
            "sanitizer_symbolizer_markup.cpp",
            "sanitizer_symbolizer_report.cpp",
            "sanitizer_termination.cpp",
            "sanitizer_thread_arg_retval.cpp",
            "sanitizer_thread_registry.cpp",
            "sanitizer_tls_get_addr.cpp",
            "sanitizer_type_traits.cpp",
            // "symbolizer/sanitizer_symbolize.cpp", // need LLVM headers
            // "symbolizer/sanitizer_wrappers.cpp",
        },
        .flags = cxxflags,
    });
}

pub fn buildUBSan(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const dep = b.dependency("compiler-rt", .{});
    lib.root_module.sanitize_c = false;

    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("lib"));
    lib.addCSourceFiles(.{
        .root = dep.path("lib/ubsan"),
        .files = &.{
            "ubsan_diag.cpp",
            "ubsan_diag_standalone.cpp",
            "ubsan_flags.cpp",
            "ubsan_handlers.cpp",
            "ubsan_handlers_cxx.cpp",
            "ubsan_init.cpp",
            "ubsan_init_standalone.cpp",
            "ubsan_init_standalone_preinit.cpp",
            "ubsan_monitor.cpp",
            "ubsan_signals_standalone.cpp",
            "ubsan_type_hash.cpp",
            "ubsan_type_hash_itanium.cpp",
            "ubsan_type_hash_win.cpp",
            "ubsan_value.cpp",
            "ubsan_win_dll_thunk.cpp",
            "ubsan_win_dynamic_runtime_thunk.cpp",
            "ubsan_win_weak_interception.cpp",
        },
        .flags = cxxflags,
    });
    // lib.addCSourceFiles(.{
    //     .root = dep.path("lib/ubsan_minimal"),
    //     .files = &.{
    //         "ubsan_minimal_handlers.cpp",
    //     },
    //     .flags = cxxflags,
    // });
}

pub fn buildRTSan(b: *std.Build, lib: *std.Build.Step.Compile) void {
    const dep = b.dependency("compiler-rt", .{});
    lib.root_module.sanitize_c = false;
    lib.addIncludePath(dep.path("include"));
    lib.addIncludePath(dep.path("lib"));
    lib.addCSourceFiles(.{
        .root = dep.path("lib/rtsan"),
        .files = &.{
            "rtsan.cpp",
            "rtsan_context.cpp",
            "rtsan_interceptors.cpp",
            "rtsan_preinit.cpp",
            "rtsan_stack.cpp",
        },
        .flags = cxxflags,
    });
    if (lib.rootModuleTarget().abi != .msvc) {
        lib.linkLibCpp();
    } else {
        lib.linkLibC();
    }
    buildInterception(lib, dep);
    buildSanCommon(lib, dep);
}

const cxxflags = &.{
    "-std=c++17",
    "-Wall",
    "-Wextra",
};

// const src = &.{
//     "lib/cfi/cfi.cpp",
//     "lib/ctx_profile/CtxInstrProfiling.cpp",
//     "lib/ctx_profile/tests/CtxInstrProfilingTest.cpp",
//     "lib/ctx_profile/tests/driver.cpp",
//     "lib/dfsan/dfsan.cpp",
//     "lib/dfsan/dfsan_allocator.cpp",
//     "lib/dfsan/dfsan_chained_origin_depot.cpp",
//     "lib/dfsan/dfsan_custom.cpp",
//     "lib/dfsan/dfsan_interceptors.cpp",
//     "lib/dfsan/dfsan_new_delete.cpp",
//     "lib/dfsan/dfsan_thread.cpp",
//     "lib/fuzzer/FuzzerCrossOver.cpp",
//     "lib/fuzzer/FuzzerDataFlowTrace.cpp",
//     "lib/fuzzer/FuzzerDriver.cpp",
//     "lib/fuzzer/FuzzerExtFunctionsDlsym.cpp",
//     "lib/fuzzer/FuzzerExtFunctionsWeak.cpp",
//     "lib/fuzzer/FuzzerExtFunctionsWindows.cpp",
//     "lib/fuzzer/FuzzerExtraCounters.cpp",
//     "lib/fuzzer/FuzzerExtraCountersDarwin.cpp",
//     "lib/fuzzer/FuzzerExtraCountersWindows.cpp",
//     "lib/fuzzer/FuzzerFork.cpp",
//     "lib/fuzzer/FuzzerIO.cpp",
//     "lib/fuzzer/FuzzerIOPosix.cpp",
//     "lib/fuzzer/FuzzerIOWindows.cpp",
//     "lib/fuzzer/FuzzerInterceptors.cpp",
//     "lib/fuzzer/FuzzerLoop.cpp",
//     "lib/fuzzer/FuzzerMain.cpp",
//     "lib/fuzzer/FuzzerMerge.cpp",
//     "lib/fuzzer/FuzzerMutate.cpp",
//     "lib/fuzzer/FuzzerSHA1.cpp",
//     "lib/fuzzer/FuzzerTracePC.cpp",
//     "lib/fuzzer/FuzzerUtil.cpp",
//     "lib/fuzzer/FuzzerUtilDarwin.cpp",
//     "lib/fuzzer/FuzzerUtilFuchsia.cpp",
//     "lib/fuzzer/FuzzerUtilLinux.cpp",
//     "lib/fuzzer/FuzzerUtilPosix.cpp",
//     "lib/fuzzer/FuzzerUtilWindows.cpp",
//     "lib/fuzzer/afl/afl_driver.cpp",
//     "lib/fuzzer/dataflow/DataFlow.cpp",
//     "lib/fuzzer/dataflow/DataFlowCallbacks.cpp",
//     "lib/fuzzer/tests/FuzzedDataProviderUnittest.cpp",
//     "lib/fuzzer/tests/FuzzerUnittest.cpp",
//     "lib/gwp_asan/common.cpp",
//     "lib/gwp_asan/crash_handler.cpp",
//     "lib/gwp_asan/guarded_pool_allocator.cpp",
//     "lib/gwp_asan/optional/backtrace_fuchsia.cpp",
//     "lib/gwp_asan/optional/backtrace_linux_libc.cpp",
//     "lib/gwp_asan/optional/backtrace_sanitizer_common.cpp",
//     "lib/gwp_asan/optional/options_parser.cpp",
//     "lib/gwp_asan/optional/segv_handler_fuchsia.cpp",
//     "lib/gwp_asan/optional/segv_handler_posix.cpp",
//     "lib/gwp_asan/platform_specific/common_fuchsia.cpp",
//     "lib/gwp_asan/platform_specific/common_posix.cpp",
//     "lib/gwp_asan/platform_specific/guarded_pool_allocator_fuchsia.cpp",
//     "lib/gwp_asan/platform_specific/guarded_pool_allocator_posix.cpp",
//     "lib/gwp_asan/platform_specific/mutex_fuchsia.cpp",
//     "lib/gwp_asan/platform_specific/mutex_posix.cpp",
//     "lib/gwp_asan/platform_specific/utilities_fuchsia.cpp",
//     "lib/gwp_asan/platform_specific/utilities_posix.cpp",
//     "lib/gwp_asan/stack_trace_compressor.cpp",
//     "lib/gwp_asan/tests/alignment.cpp",
//     "lib/gwp_asan/tests/backtrace.cpp",
//     "lib/gwp_asan/tests/basic.cpp",
//     "lib/gwp_asan/tests/compression.cpp",
//     "lib/gwp_asan/tests/crash_handler_api.cpp",
//     "lib/gwp_asan/tests/driver.cpp",
//     "lib/gwp_asan/tests/enable_disable.cpp",
//     "lib/gwp_asan/tests/harness.cpp",
//     "lib/gwp_asan/tests/iterate.cpp",
//     "lib/gwp_asan/tests/late_init.cpp",
//     "lib/gwp_asan/tests/mutex_test.cpp",
//     "lib/gwp_asan/tests/never_allocated.cpp",
//     "lib/gwp_asan/tests/options.cpp",
//     "lib/gwp_asan/tests/platform_specific/printf_sanitizer_common.cpp",
//     "lib/gwp_asan/tests/recoverable.cpp",
//     "lib/gwp_asan/tests/slot_reuse.cpp",
//     "lib/gwp_asan/tests/thread_contention.cpp",
//     "lib/hwasan/hwasan.cpp",
//     "lib/hwasan/hwasan_allocation_functions.cpp",
//     "lib/hwasan/hwasan_allocator.cpp",
//     "lib/hwasan/hwasan_dynamic_shadow.cpp",
//     "lib/hwasan/hwasan_exceptions.cpp",
//     "lib/hwasan/hwasan_fuchsia.cpp",
//     "lib/hwasan/hwasan_globals.cpp",
//     "lib/hwasan/hwasan_interceptors.cpp",
//     "lib/hwasan/hwasan_linux.cpp",
//     "lib/hwasan/hwasan_memintrinsics.cpp",
//     "lib/hwasan/hwasan_new_delete.cpp",
//     "lib/hwasan/hwasan_poisoning.cpp",
//     "lib/hwasan/hwasan_preinit.cpp",
//     "lib/hwasan/hwasan_report.cpp",
//     "lib/hwasan/hwasan_thread.cpp",
//     "lib/hwasan/hwasan_thread_list.cpp",
//     "lib/hwasan/hwasan_type_test.cpp",

//     "lib/interception/tests/interception_linux_foreign_test.cpp",
//     "lib/interception/tests/interception_linux_test.cpp",
//     "lib/interception/tests/interception_test_main.cpp",
//     "lib/interception/tests/interception_win_test.cpp",

//     "lib/memprof/memprof_allocator.cpp",
//     "lib/memprof/memprof_descriptions.cpp",
//     "lib/memprof/memprof_flags.cpp",
//     "lib/memprof/memprof_interceptors.cpp",
//     "lib/memprof/memprof_interceptors_memintrinsics.cpp",
//     "lib/memprof/memprof_linux.cpp",
//     "lib/memprof/memprof_malloc_linux.cpp",
//     "lib/memprof/memprof_mibmap.cpp",
//     "lib/memprof/memprof_new_delete.cpp",
//     "lib/memprof/memprof_posix.cpp",
//     "lib/memprof/memprof_preinit.cpp",
//     "lib/memprof/memprof_rawprofile.cpp",
//     "lib/memprof/memprof_rtl.cpp",
//     "lib/memprof/memprof_shadow_setup.cpp",
//     "lib/memprof/memprof_stack.cpp",
//     "lib/memprof/memprof_stats.cpp",
//     "lib/memprof/memprof_thread.cpp",
//     "lib/memprof/tests/driver.cpp",
//     "lib/memprof/tests/rawprofile.cpp",
//     "lib/msan/msan.cpp",
//     "lib/msan/msan_allocator.cpp",
//     "lib/msan/msan_chained_origin_depot.cpp",
//     "lib/msan/msan_dl.cpp",
//     "lib/msan/msan_interceptors.cpp",
//     "lib/msan/msan_linux.cpp",
//     "lib/msan/msan_new_delete.cpp",
//     "lib/msan/msan_poisoning.cpp",
//     "lib/msan/msan_report.cpp",
//     "lib/msan/msan_thread.cpp",
//     "lib/msan/tests/msan_loadable.cpp",
//     "lib/msan/tests/msan_test.cpp",
//     "lib/msan/tests/msan_test_main.cpp",
//     "lib/nsan/nsan.cpp",
//     "lib/nsan/nsan_flags.cpp",
//     "lib/nsan/nsan_interceptors.cpp",
//     "lib/nsan/nsan_malloc_linux.cpp",
//     "lib/nsan/nsan_preinit.cpp",
//     "lib/nsan/nsan_stats.cpp",
//     "lib/nsan/nsan_suppressions.cpp",
//     "lib/nsan/tests/NSanUnitTest.cpp",
//     "lib/nsan/tests/nsan_unit_test_main.cpp",
//     "lib/orc/coff_platform.cpp",
//     "lib/orc/coff_platform.per_jd.cpp",
//     "lib/orc/debug.cpp",
//     "lib/orc/dlfcn_wrapper.cpp",
//     "lib/orc/elfnix_platform.cpp",
//     "lib/orc/extensible_rtti.cpp",
//     "lib/orc/log_error_to_stderr.cpp",
//     "lib/orc/macho_platform.cpp",
//     "lib/orc/run_program_wrapper.cpp",
//     "lib/orc/tests/tools/orc-rt-executor.cpp",
//     "lib/orc/tests/unit/adt_test.cpp",
//     "lib/orc/tests/unit/bitmask_enum_test.cpp",
//     "lib/orc/tests/unit/c_api_test.cpp",
//     "lib/orc/tests/unit/endian_test.cpp",
//     "lib/orc/tests/unit/error_test.cpp",
//     "lib/orc/tests/unit/executor_address_test.cpp",
//     "lib/orc/tests/unit/executor_symbol_def_test.cpp",
//     "lib/orc/tests/unit/extensible_rtti_test.cpp",
//     "lib/orc/tests/unit/interval_map_test.cpp",
//     "lib/orc/tests/unit/interval_set_test.cpp",
//     "lib/orc/tests/unit/orc_unit_test_main.cpp",
//     "lib/orc/tests/unit/simple_packed_serialization_test.cpp",
//     "lib/orc/tests/unit/string_pool_test.cpp",
//     "lib/orc/tests/unit/wrapper_function_utils_test.cpp",
//     "lib/profile/InstrProfilingRuntime.cpp",

//     "lib/safestack/safestack.cpp",

//     "lib/sanitizer_common/tests/malloc_stress_transfer_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_addrhashmap_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_allocator_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_allocator_testlib.cpp",
//     "lib/sanitizer_common/tests/sanitizer_array_ref_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_atomic_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_bitvector_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_bvgraph_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_chained_origin_depot_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_common_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_deadlock_detector_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_dense_map_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_flags_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_flat_map_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_format_interceptor_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_hash_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_ioctl_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_leb128_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_libc_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_linux_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_list_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_lzw_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_mac_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_module_uuid_size.cpp",
//     "lib/sanitizer_common/tests/sanitizer_mutex_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_nolibc_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_nolibc_test_main.cpp",
//     "lib/sanitizer_common/tests/sanitizer_posix_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_printf_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_procmaps_mac_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_procmaps_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_quarantine_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_range_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_ring_buffer_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_stack_store_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_stackdepot_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_stacktrace_printer_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_stacktrace_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_stoptheworld_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_stoptheworld_testlib.cpp",
//     "lib/sanitizer_common/tests/sanitizer_suppressions_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_symbolizer_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_test_main.cpp",
//     "lib/sanitizer_common/tests/sanitizer_thread_arg_retval_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_thread_registry_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_type_traits_test.cpp",
//     "lib/sanitizer_common/tests/sanitizer_vector_test.cpp",
//     "lib/sanitizer_common/tests/standalone_malloc_test.cpp",
//     "lib/scudo/standalone/benchmarks/malloc_benchmark.cpp",
//     "lib/scudo/standalone/checksum.cpp",
//     "lib/scudo/standalone/common.cpp",
//     "lib/scudo/standalone/condition_variable_linux.cpp",
//     "lib/scudo/standalone/crc32_hw.cpp",
//     "lib/scudo/standalone/flags.cpp",
//     "lib/scudo/standalone/flags_parser.cpp",
//     "lib/scudo/standalone/fuchsia.cpp",
//     "lib/scudo/standalone/fuzz/get_error_info_fuzzer.cpp",
//     "lib/scudo/standalone/linux.cpp",
//     "lib/scudo/standalone/mem_map.cpp",
//     "lib/scudo/standalone/mem_map_fuchsia.cpp",
//     "lib/scudo/standalone/mem_map_linux.cpp",
//     "lib/scudo/standalone/release.cpp",
//     "lib/scudo/standalone/report.cpp",
//     "lib/scudo/standalone/report_linux.cpp",
//     "lib/scudo/standalone/string_utils.cpp",
//     "lib/scudo/standalone/tests/allocator_config_test.cpp",
//     "lib/scudo/standalone/tests/atomic_test.cpp",
//     "lib/scudo/standalone/tests/bytemap_test.cpp",
//     "lib/scudo/standalone/tests/checksum_test.cpp",
//     "lib/scudo/standalone/tests/chunk_test.cpp",
//     "lib/scudo/standalone/tests/combined_test.cpp",
//     "lib/scudo/standalone/tests/common_test.cpp",
//     "lib/scudo/standalone/tests/condition_variable_test.cpp",
//     "lib/scudo/standalone/tests/flags_test.cpp",
//     "lib/scudo/standalone/tests/list_test.cpp",
//     "lib/scudo/standalone/tests/map_test.cpp",
//     "lib/scudo/standalone/tests/memtag_test.cpp",
//     "lib/scudo/standalone/tests/mutex_test.cpp",
//     "lib/scudo/standalone/tests/primary_test.cpp",
//     "lib/scudo/standalone/tests/quarantine_test.cpp",
//     "lib/scudo/standalone/tests/release_test.cpp",
//     "lib/scudo/standalone/tests/report_test.cpp",
//     "lib/scudo/standalone/tests/scudo_unit_test_main.cpp",
//     "lib/scudo/standalone/tests/secondary_test.cpp",
//     "lib/scudo/standalone/tests/size_class_map_test.cpp",
//     "lib/scudo/standalone/tests/stats_test.cpp",
//     "lib/scudo/standalone/tests/strings_test.cpp",
//     "lib/scudo/standalone/tests/timing_test.cpp",
//     "lib/scudo/standalone/tests/tsd_test.cpp",
//     "lib/scudo/standalone/tests/vector_test.cpp",
//     "lib/scudo/standalone/tests/wrappers_c_test.cpp",
//     "lib/scudo/standalone/tests/wrappers_cpp_test.cpp",
//     "lib/scudo/standalone/timing.cpp",
//     "lib/scudo/standalone/tools/compute_size_class_config.cpp",
//     "lib/scudo/standalone/trusty.cpp",
//     "lib/scudo/standalone/wrappers_c.cpp",
//     "lib/scudo/standalone/wrappers_c_bionic.cpp",
//     "lib/scudo/standalone/wrappers_cpp.cpp",
//     "lib/stats/stats.cpp",
//     "lib/stats/stats_client.cpp",
//     "lib/tsan/benchmarks/func_entry_exit.cpp",
//     "lib/tsan/benchmarks/mini_bench_local.cpp",
//     "lib/tsan/benchmarks/mini_bench_shared.cpp",
//     "lib/tsan/benchmarks/mop.cpp",
//     "lib/tsan/benchmarks/start_many_threads.cpp",
//     "lib/tsan/benchmarks/vts_many_threads_bench.cpp",
//     "lib/tsan/dd/dd_interceptors.cpp",
//     "lib/tsan/dd/dd_rtl.cpp",
//     "lib/tsan/go/tsan_go.cpp",
//     "lib/tsan/rtl/tsan_debugging.cpp",
//     "lib/tsan/rtl/tsan_external.cpp",
//     "lib/tsan/rtl/tsan_fd.cpp",
//     "lib/tsan/rtl/tsan_flags.cpp",
//     "lib/tsan/rtl/tsan_ignoreset.cpp",
//     "lib/tsan/rtl/tsan_interceptors_libdispatch.cpp",
//     "lib/tsan/rtl/tsan_interceptors_mac.cpp",
//     "lib/tsan/rtl/tsan_interceptors_mach_vm.cpp",
//     "lib/tsan/rtl/tsan_interceptors_memintrinsics.cpp",
//     "lib/tsan/rtl/tsan_interceptors_posix.cpp",
//     "lib/tsan/rtl/tsan_interface.cpp",
//     "lib/tsan/rtl/tsan_interface_ann.cpp",
//     "lib/tsan/rtl/tsan_interface_atomic.cpp",
//     "lib/tsan/rtl/tsan_interface_java.cpp",
//     "lib/tsan/rtl/tsan_malloc_mac.cpp",
//     "lib/tsan/rtl/tsan_md5.cpp",
//     "lib/tsan/rtl/tsan_mman.cpp",
//     "lib/tsan/rtl/tsan_mutexset.cpp",
//     "lib/tsan/rtl/tsan_new_delete.cpp",
//     "lib/tsan/rtl/tsan_platform_linux.cpp",
//     "lib/tsan/rtl/tsan_platform_mac.cpp",
//     "lib/tsan/rtl/tsan_platform_posix.cpp",
//     "lib/tsan/rtl/tsan_platform_windows.cpp",
//     "lib/tsan/rtl/tsan_preinit.cpp",
//     "lib/tsan/rtl/tsan_report.cpp",
//     "lib/tsan/rtl/tsan_rtl.cpp",
//     "lib/tsan/rtl/tsan_rtl_access.cpp",
//     "lib/tsan/rtl/tsan_rtl_mutex.cpp",
//     "lib/tsan/rtl/tsan_rtl_proc.cpp",
//     "lib/tsan/rtl/tsan_rtl_report.cpp",
//     "lib/tsan/rtl/tsan_rtl_thread.cpp",
//     "lib/tsan/rtl/tsan_stack_trace.cpp",
//     "lib/tsan/rtl/tsan_suppressions.cpp",
//     "lib/tsan/rtl/tsan_symbolize.cpp",
//     "lib/tsan/rtl/tsan_sync.cpp",
//     "lib/tsan/rtl/tsan_vector_clock.cpp",
//     "lib/tsan/tests/rtl/tsan_bench.cpp",
//     "lib/tsan/tests/rtl/tsan_mop.cpp",
//     "lib/tsan/tests/rtl/tsan_mutex.cpp",
//     "lib/tsan/tests/rtl/tsan_posix.cpp",
//     "lib/tsan/tests/rtl/tsan_string.cpp",
//     "lib/tsan/tests/rtl/tsan_test.cpp",
//     "lib/tsan/tests/rtl/tsan_test_util_posix.cpp",
//     "lib/tsan/tests/rtl/tsan_thread.cpp",
//     "lib/tsan/tests/unit/tsan_dense_alloc_test.cpp",
//     "lib/tsan/tests/unit/tsan_flags_test.cpp",
//     "lib/tsan/tests/unit/tsan_ilist_test.cpp",
//     "lib/tsan/tests/unit/tsan_mman_test.cpp",
//     "lib/tsan/tests/unit/tsan_mutexset_test.cpp",
//     "lib/tsan/tests/unit/tsan_shadow_test.cpp",
//     "lib/tsan/tests/unit/tsan_stack_test.cpp",
//     "lib/tsan/tests/unit/tsan_sync_test.cpp",
//     "lib/tsan/tests/unit/tsan_trace_test.cpp",
//     "lib/tsan/tests/unit/tsan_unit_test_main.cpp",
//     "lib/tsan/tests/unit/tsan_vector_clock_test.cpp",

//     "lib/xray/tests/unit/allocator_test.cpp",
//     "lib/xray/tests/unit/buffer_queue_test.cpp",
//     "lib/xray/tests/unit/fdr_controller_test.cpp",
//     "lib/xray/tests/unit/fdr_log_writer_test.cpp",
//     "lib/xray/tests/unit/function_call_trie_test.cpp",
//     "lib/xray/tests/unit/profile_collector_test.cpp",
//     "lib/xray/tests/unit/segmented_array_test.cpp",
//     "lib/xray/tests/unit/test_helpers.cpp",
//     "lib/xray/tests/unit/xray_unit_test_main.cpp",
//     "lib/xray/xray_AArch64.cpp",
//     "lib/xray/xray_arm.cpp",
//     "lib/xray/xray_basic_flags.cpp",
//     "lib/xray/xray_basic_logging.cpp",
//     "lib/xray/xray_buffer_queue.cpp",
//     "lib/xray/xray_fdr_flags.cpp",
//     "lib/xray/xray_fdr_logging.cpp",
//     "lib/xray/xray_flags.cpp",
//     "lib/xray/xray_hexagon.cpp",
//     "lib/xray/xray_init.cpp",
//     "lib/xray/xray_interface.cpp",
//     "lib/xray/xray_log_interface.cpp",
//     "lib/xray/xray_loongarch64.cpp",
//     "lib/xray/xray_mips.cpp",
//     "lib/xray/xray_mips64.cpp",
//     "lib/xray/xray_powerpc64.cpp",
//     "lib/xray/xray_profile_collector.cpp",
//     "lib/xray/xray_profiling.cpp",
//     "lib/xray/xray_profiling_flags.cpp",
//     "lib/xray/xray_trampoline_powerpc64.cpp",
//     "lib/xray/xray_utils.cpp",
//     "lib/xray/xray_x86_64.cpp",
// };
