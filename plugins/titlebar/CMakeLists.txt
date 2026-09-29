cmake_minimum_required(VERSION 3.27)

project(fluencytitlebar
    DESCRIPTION "fluencytitlebar plugin for Hyprland"
    VERSION 0.1
)

set(CMAKE_CXX_STANDARD 23)

file(GLOB_RECURSE SRC "*.cpp")

add_library(fluencytitlebar SHARED ${SRC})

find_package(PkgConfig REQUIRED)
pkg_check_modules(deps REQUIRED IMPORTED_TARGET
    hyprland
    libdrm
    libinput
    libudev
    pixman-1
    wayland-server
    xkbcommon
    hyprgraphics
    cairo
)
target_link_libraries(fluencytitlebar PRIVATE rt PkgConfig::deps)
# unique symbols keep an unloaded build mapped and a reload shares its state
target_compile_options(fluencytitlebar PRIVATE -fno-gnu-unique)

install(TARGETS fluencytitlebar)
