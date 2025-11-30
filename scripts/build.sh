#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- CPU Vendor Detection ---
echo "Detecting CPU vendor..."
VENDOR_ID_RAW=$(grep -m 1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
CPU_VENDOR="unknown"
OPT_FLAGS=""
CMAKE_EXTRA_FLAGS=""
if [[ "$VENDOR_ID_RAW" == "GenuineIntel" ]]; then
    echo "Intel CPU detected."
    CPU_VENDOR="intel"
    OPT_FLAGS="-march=native"
    CMAKE_EXTRA_FLAGS="-DOpenCL_LIBRARY=/usr/lib64/libOpenCL.so.1"
elif [[ "$VENDOR_ID_RAW" == "AuthenticAMD" ]]; then
    echo "AMD CPU detected."
    CPU_VENDOR="amd"
    OPT_FLAGS="-march=native"
else
    echo "Could not determine CPU vendor or vendor is not Intel/AMD. Using default flags."
fi

if [ -n "$OPT_FLAGS" ]; then
    echo "Using optimization flags: $OPT_FLAGS"
fi

# --- Build Configuration ---
BASE_DIR=$(dirname "$(dirname "$(readlink -f "$0")")")

BUILD_DIR="$BASE_DIR/fft-benchmark/cmake-build-release"
SOURCE_DIR="$BASE_DIR/fft-benchmark"

# --- Build Project ---
echo "Ensuring project is built..."
mkdir -p "$BUILD_DIR"

# Only re-configure if CMakeCache.txt is missing, to allow for incremental builds
if [ ! -f "$BUILD_DIR/CMakeCache.txt" ]; then
    echo "Configuring project with CMake for the first time..."
    cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS="$OPT_FLAGS" \
        $CMAKE_EXTRA_FLAGS
fi

echo "Building project (will skip if no changes)..."
cmake --build "$BUILD_DIR" --config Release -j $(nproc)
echo "Build complete."
