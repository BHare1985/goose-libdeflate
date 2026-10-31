/* libdeflate has an arm/cpu_features.c and an x86/cpu_features.c. Goose names
   each object after its source file, so the two would collide; compiling them
   through these wrappers gives them different names. */
#include "../vendor/libdeflate/lib/arm/cpu_features.c"
