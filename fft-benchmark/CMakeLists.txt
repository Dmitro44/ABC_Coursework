cmake_minimum_required(VERSION 3.14)
project(FFTBenchmark VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


add_executable(fft_benchmark 
    src/main.cpp
    src/benchmark.cpp
)

# =============
# MAIN PROGRAM
# =============

target_include_directories(fft_benchmark PUBLIC src)


# =============
# UNIT TESTS
# =============


enable_testing()

include(FetchContent)

FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/52eb8108c5bdec04579160ae17225d66034bd723.zip
)

FetchContent_MakeAvailable(googletest)

add_executable(run_tests 
    tests/fft_test.cpp
    src/benchmark.cpp
)

target_link_libraries(run_tests PRIVATE gtest_main)


include(GoogleTest)
gtest_discover_tests(run_tests)
