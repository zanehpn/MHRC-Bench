#include <cstdint>
#include <cstddef>
#include <cstring>

void* my_memset(void* dest, int byte, size_t len)
{
  if ((((uintptr_t)dest | len) & (sizeof(uintptr_t)-1)) == 0) {
<TARGET>
    word |= word << 8;
    word |= word << 16;
    word |= word << 16 << 16;

    uintptr_t *d = (uintptr_t*)dest;
    while (d < (uintptr_t*)((char*)dest + len))
      *d++ = word;
  } else {
    char *d = (char*)dest;
    while (d < (char*)dest + len)
      *d++ = byte;
  }
  return dest;
}
