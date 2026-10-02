cmake_minimum_required(VERSION 3.27)

project(fluencyminimize VERSION 0.1)

set(CMAKE_CXX_STANDARD 23)

add_library(fluencyminimize SHARED main.cpp ghost.cpp leaves.cpp toast.cpp)

find_package(PkgConfig REQUIRED)
pkg_check_modules(deps REQUIRED IMPORTED_TARGET hyprland libdrm libinput libudev pixman-1 wayland-server xkbcommon)
target_link_libraries(fluencyminimize PRIVATE rt PkgConfig::deps)
# unique symbols keep an unloaded build mapped and a reload shares its state
target_compile_options(fluencyminimize PRIVATE -fno-gnu-unique)
