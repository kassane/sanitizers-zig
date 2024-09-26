# LLVM Sanitizers for Zig

## Description

This is a collection of sanitizers for Zig. It is a work in progress.


## Requirements

- [Zig](https://ziglang.org/download/) v0.13.0 or master

## Add

- [x] AddressSanitizer
- [ ] MemorySanitizer
- [x] UndefinedBehaviorSanitizer
- [x] LeakSanitizer
- [x] RealtimeSanitizer (LLVM 20)

## Supported Platforms

- [x] Linux (GNU|Musl)
- [ ] Windows
- [ ] macOS


## Experimental Real-time Sanitizer (LLVM 20)

> [!NOTE]
> This is an experimental feature and is not yet ready for production use.
> Currently, zig master version is LLVM 19. My tests use zig-fork w/ LLVM 20.

```bash
$ zig build rtsan -Dtests
Real-time violation: intercepted call to real-time unsafe function `malloc` in real-time context! Stack trace:
    #0 0x00000102e659  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102e659)
    #1 0x00000102bf80  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102bf80)
    #2 0x00000102bef5  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102bef5)
    #3 0x00000102c23c  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102c23c)
    #4 0x00000102cdc1  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102cdc1)
    #5 0x0000010891f7  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x10891f7)
    #6 0x00000102b824  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102b824)
    #7 0x00000102b7a2  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102b7a2)
    #8 0x00000102b713  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102b713)
    #9 0x00000102b42c  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102b42c)
    #10 0x00000102b10e  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102b10e)
    #11 0x00000102aeaa  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102aeaa)
    #12 0x00000102adc8  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102adc8)
    #13 0x00000102ae25  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102ae25)
    #14 0x77feed58de07  (/usr/lib/libc.so.6+0x25e07) (BuildId: 98b3d8e0b8c534c769cb871c438b4f8f3a8e4bf3)
    #15 0x77feed58decb  (/usr/lib/libc.so.6+0x25ecb) (BuildId: 98b3d8e0b8c534c769cb871c438b4f8f3a8e4bf3)
    #16 0x00000102ad74  (/home/kassane/sanitizers-llvm/.zig-cache/o/18b7cbe81f65f9f9049547f69b71a77e/test-rtsan+0x102ad74)

rtsan
└─ run test-rtsan failure
error: the following command exited with error code 1:
```

### References

- official-doc: https://clang.llvm.org/docs/RealtimeSanitizer.html
- base: https://github.com/realtime-sanitizer/rtsan