/*
 * TinyCC cannot compile the native inline adapters in libdeflate.h.
 * Emit ordinary external functions from that same header for the JIT backend.
 * Goose's generated C defines these packed slice types itself.
 */
#include <stdint.h>

#pragma pack(push, 1)
typedef struct { uint8_t *data; int64_t len; } sl_u8;
typedef struct { int64_t *data; int64_t len; } sl_i64;
#pragma pack(pop)

#define GLD_INLINE
#include "libdeflate.h"
