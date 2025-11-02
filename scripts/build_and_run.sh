#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- CPU Vendor Detection ---
echo "Detecting CPU vendor..."
VENDOR_ID=$(grep -m 1 "vendor_id" /proc/cpuinfo | awk '{print $3}')

OPT_FLAGS=""
if [[ "$VENDOR_ID" == "GenuineIntel" ]]; then
    echo "Intel CPU detected."
    # -march=native enables optimizations for the host CPU.
    OPT_FLAGS="-march=native"
elif [[ "$VENDOR_ID" == "AuthenticAMD" ]]; then
    echo "AMD CPU detected."
    # -march=native is also effective for AMD CPUs.
    OPT_FLAGS="-march=native"
else
    echo "Could not determine CPU vendor or vendor is not Intel/AMD. Using default flags."
fi

if [ -n "$OPT_FLAGS" ]; then
    echo "Using optimization flags: $OPT_FLAGS"
fi

# --- Build Configuration ---
BUILD_DIR="fft-benchmark/cmake-build-release"
SOURCE_DIR="fft-benchmark"
EXECUTABLE_NAME="fft_benchmark"

# --- Build Project ---
echo "Configuring project with CMake..."
# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Run CMake
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_FLAGS="$OPT_FLAGS"

echo "Building project..."
cmake --build "$BUILD_DIR" --config Release -j $(nproc)

# --- Run Benchmark ---
echo "Build complete. Running benchmark..."
"$BUILD_DIR/$EXECUTABLE_NAME"

echo "Benchmark finished."
