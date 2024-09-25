/// Reference:
/// https://github.com/CppCon/CppCon2024/blob/main/Presentations/LLVMs_Realtime_Safety_Revolution.pdf

// #include <vector>

extern "C" {
void ffi_zigarray();
void ffi_zig_openfile();
}

// int process(int) [[clang::nonblocking]] {
//   std::vector<int> v(16);
//   return v[16];
// }

void zig_main() [[clang::nonblocking]] {
  ffi_zigarray();
  ffi_zig_openfile();
}

int main() {
  zig_main();
  return 0;
}
