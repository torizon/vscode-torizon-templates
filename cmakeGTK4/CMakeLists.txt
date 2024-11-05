cmake_minimum_required(VERSION 3.0.0)

project(__change__ VERSION 1.0 LANGUAGES CXX C)

# Use the package PkgConfig to detect GTK+ headers/library files
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK4 REQUIRED gtk4)

# Setup CMake to use GTK+, tell the compiler where to look for headers
# and to the linker where to look for libraries
include_directories(${GTK4_INCLUDE_DIRS})
link_directories(${GTK4_LIBRARY_DIRS})
# Add other flags to the compiler
add_definitions(${GTK4_CFLAGS_OTHER})

add_executable(__change__ src/main.cpp)
target_link_libraries(__change__ ${GTK4_LIBRARIES})

set(CMAKE_SYSTEM_NAME Linux)

set_target_properties(__change__ PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "bin"
    ARCHIVE_OUTPUT_DIRECTORY "lib"
    LIBRARY_OUTPUT_DIRECTORY "lib"
)
