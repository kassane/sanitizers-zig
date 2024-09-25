/// Based on vec_test.cc

extern "C" {
void ffi_zigarray();
void ffi_zig_openfile();
}

void zig_main() [[clang::nonblocking]] {
  ffi_zigarray();
  ffi_zig_openfile();
}

int main() {
  zig_main();
  return 0;
}
