/// Reference:
/// https://github.com/CppCon/CppCon2024/blob/main/Presentations/LLVMs_Realtime_Safety_Revolution.pdf

#include <vector>

int process() [[clang::nonblocking]] {
  std::vector<int> v(16);
  return v[16];
}

int main() { return process(); }
