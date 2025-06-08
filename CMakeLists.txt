cmake_minimum_required(VERSION 3.20)
project(vtune_demo LANGUAGES CXX)

# Produce a position-independent executable, with symbols, no frame-ptr stripping.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_BUILD_TYPE Release)                 # -O3 by default

add_executable(prime_counter main.cpp)
target_compile_options(prime_counter PRIVATE -g -fno-omit-frame-pointer)
