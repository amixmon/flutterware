cmake_minimum_required(VERSION 3.22.1)
project(flutterware_native_launchers C)

add_library(flutterware_execname SHARED execname_shim.c)

target_compile_options(flutterware_execname PRIVATE
    -Wall
    -Wextra
    -Werror
    -fvisibility=hidden
)

target_link_libraries(flutterware_execname PRIVATE dl)
