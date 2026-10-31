# The native part of the package: libdeflate (vendor/libdeflate) and
# goose_libdeflate, the small C layer in src/ that deflate.goose calls. The
# Goose compiler builds this when a program imports the package. libdeflate is
# built by its own CMake project, so its compiler and assembler checks run
# here as they would upstream.

cmake_minimum_required(VERSION 3.10)
project(goose_libdeflate_package C)

# We only want the static library, not the shared one, the gzip program or the
# tests.
set(LIBDEFLATE_BUILD_STATIC_LIB ON CACHE BOOL "" FORCE)
set(LIBDEFLATE_BUILD_SHARED_LIB OFF CACHE BOOL "" FORCE)
set(LIBDEFLATE_BUILD_GZIP OFF CACHE BOOL "" FORCE)
set(LIBDEFLATE_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LIBDEFLATE_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory(vendor/libdeflate libdeflate EXCLUDE_FROM_ALL)
# libdeflate would use the debug C runtime in a debug build, but the rest of a
# Goose program links the release one.
set_target_properties(libdeflate_static PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreaded")

add_library(goose_libdeflate STATIC
    src/goose_libdeflate.h
    src/goose_libdeflate.c
)
target_link_libraries(goose_libdeflate PUBLIC libdeflate::libdeflate_static)
set_target_properties(goose_libdeflate PROPERTIES C_STANDARD 99 C_STANDARD_REQUIRED ON
                      INTERPROCEDURAL_OPTIMIZATION OFF
                      MSVC_RUNTIME_LIBRARY "MultiThreaded")
if(MSVC)
    target_compile_options(goose_libdeflate PRIVATE /W4 /utf-8)
else()
    target_compile_options(goose_libdeflate PRIVATE -Wall -Wextra -Wpedantic)
endif()
