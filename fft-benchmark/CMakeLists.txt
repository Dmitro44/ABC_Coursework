cmake_minimum_required(VERSION 3.14)
project(FFTBenchmark VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find OpenCL
find_package(OpenCL REQUIRED)

# =============
# INPUT DATA GENERATOR
# =============

add_executable(generate_input
    src/generate_input.cpp
)

# =============
# MAIN PROGRAM (CPU Benchmark)
# =============

add_executable(fft_benchmark
    src/main.cpp
    src/benchmark.cpp
)

target_include_directories(fft_benchmark PUBLIC src)

# =============
# GPU BENCHMARK (OpenCL)
# =============

add_executable(gpu_fft_benchmark
    src/gpu_benchmark.cpp
)

target_link_libraries(gpu_fft_benchmark OpenCL::OpenCL)

# Copy the OpenCL kernel file to the build directory and define its path for the executable
set(KERNEL_FILE_DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/fft_kernel.cl")
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/src/fft_kernel.cl"
    "${KERNEL_FILE_DESTINATION}"
    COPYONLY
)
target_compile_definitions(gpu_fft_benchmark PRIVATE KERNEL_FILE_PATH="${KERNEL_FILE_DESTINATION}")

