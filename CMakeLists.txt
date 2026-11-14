# Build only the static libdeflate codec and the TinyCC adapter fallback.
# Native Goose builds include src/libdeflate.h inline in generated C instead.
cmake_minimum_required(VERSION 3.20)
project(goose_libdeflate LANGUAGES C)

set(LIBDEFLATE_BUILD_STATIC_LIB ON CACHE BOOL "" FORCE)
set(LIBDEFLATE_BUILD_SHARED_LIB OFF CACHE BOOL "" FORCE)
set(LIBDEFLATE_BUILD_GZIP OFF CACHE BOOL "" FORCE)
set(LIBDEFLATE_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LIBDEFLATE_INSTALL OFF CACHE BOOL "" FORCE)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_subdirectory(vendor/libdeflate EXCLUDE_FROM_ALL)

add_library(goose_libdeflate STATIC src/libdeflate.c)
target_link_libraries(goose_libdeflate PUBLIC libdeflate_static)
set_target_properties(goose_libdeflate PROPERTIES POSITION_INDEPENDENT_CODE ON)
