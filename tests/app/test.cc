/// Based on vec_test.cc

extern "C" {
void ffi_zigarray();
void ffi_zig_openfile();
void dump_stack_trace();
void setup_debug_handlers();
}

void zig_main() [[clang::nonblocking]] {
  ffi_zigarray();
  ffi_zig_openfile();
}

int main() {
#if defined(__linux__) || defined(__APPLE__)
  setup_debug_handlers();
#endif
  zig_main();
  return 0;
}
