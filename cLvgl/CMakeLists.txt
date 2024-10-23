cmake_minimum_required(VERSION 3.10)
project(cmakecheck)

set(CMAKE_C_STANDARD 99) #C99 # lvgl officially support C99 and above
set(CMAKE_CXX_STANDARD 17) #C17
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/bin)

add_subdirectory(lvgl)
add_executable(cmakecheck src/main.c mouse_cursor_icon.c)

target_include_directories(lvgl PUBLIC ${PROJECT_SOURCE_DIR})
target_include_directories(lvgl PRIVATE ${SDL2_INCLUDE_DIRS})
target_include_directories(lvgl PRIVATE ${SDL2_IMAGE_INCLUDE_DIRS})
target_include_directories(lvgl PRIVATE ${LIBDRM_INCLUDE_DIRS})

target_link_libraries(cmakecheck PRIVATE lvgl) # Add '-static' if you want a standalone binary
target_link_libraries(cmakecheck PRIVATE lvgl::examples)
target_link_libraries(cmakecheck PRIVATE lvgl::demos)
target_link_libraries(cmakecheck PRIVATE lvgl::thorvg)
target_link_libraries(cmakecheck PRIVATE m)
target_link_libraries(cmakecheck PRIVATE pthread)


set(CMAKE_SYSTEM_NAME Linux)

set_target_properties(cmakecheck PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "bin"
    ARCHIVE_OUTPUT_DIRECTORY "lib"
    LIBRARY_OUTPUT_DIRECTORY "lib"
)