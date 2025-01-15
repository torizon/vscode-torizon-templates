cmake_minimum_required(VERSION 3.10)
project(lvgl_example C)

# Uncomment if the program needs debugging
#set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O0 -ggdb")

set(CMAKE_C_STANDARD 99) # LVGL officially supports C99 and above
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(EXECUTABLE_OUTPUT_PATH ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(lib/lvgl)

target_include_directories(lvgl PUBLIC lib/ src/)

add_executable(main src/main.c)
target_link_libraries(main lvgl lvgl::examples lvgl::demos lvgl::thorvg m)

add_custom_target (run COMMAND ${EXECUTABLE_OUTPUT_PATH}/main DEPENDS main)


