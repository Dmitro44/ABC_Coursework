#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Thread Configuration ---
# Use the first script argument as thread count, or default to all available cores
NUM_THREADS=${1:-$(nproc)}
echo "Multi-threaded benchmark will run with $NUM_THREADS threads."

# --- CPU Vendor Detection ---
echo "Detecting CPU vendor..."
VENDOR_ID_RAW=$(grep -m 1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
CPU_VENDOR="unknown"
OPT_FLAGS=""
if [[ "$VENDOR_ID_RAW" == "GenuineIntel" ]]; then
    echo "Intel CPU detected."
    CPU_VENDOR="intel"
    OPT_FLAGS="-march=native"
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

# --- SMT Detection ---
echo "Detecting SMT status..."
SMT_STATUS="smt_unknown"
if [ -f /sys/devices/system/cpu/smt/control ]; then
    if grep -q "on" /sys/devices/system/cpu/smt/control; then
        SMT_STATUS="smt_on"
    elif grep -q "off" /sys/devices/system/cpu/smt/control; then
        SMT_STATUS="smt_off"
    fi
fi
echo "SMT status: $SMT_STATUS"


# --- Build Configuration ---
BUILD_DIR="fft-benchmark/cmake-build-release"
SOURCE_DIR="fft-benchmark"
EXECUTABLE_PATH="$BUILD_DIR/fft_benchmark"

# --- Results Configuration ---
PERF_RESULTS_DIR="results/perf_results"
TIMESTAMP=$(date +"%d%m%Y_%H%M%S")
PERF_EVENTS="cycles,instructions,cache-references,cache-misses,branch-instructions,branch-misses,dTLB-load-misses"

# --- Build Project ---
echo "Configuring project with CMake..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$PERF_RESULTS_DIR"

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_FLAGS="$OPT_FLAGS"

echo "Building project..."
cmake --build "$BUILD_DIR" --config Release -j $(nproc)
echo "Build complete."

# --- Run Benchmarks with Perf ---

# 1. Single-threaded benchmark
echo "----------------------------------------"
echo "Running single-threaded benchmark with perf..."
PERF_SINGLE_FILE="${PERF_RESULTS_DIR}/perf_${CPU_VENDOR}_${TIMESTAMP}_single_${SMT_STATUS}.csv"
echo "Perf results will be saved to: $PERF_SINGLE_FILE"

perf stat -e "$PERF_EVENTS" -o "$PERF_SINGLE_FILE" -x, \
    "$EXECUTABLE_PATH" --mode single

echo "Single-threaded benchmark finished."
echo "----------------------------------------"

# 2. Multi-threaded benchmark
echo "Running multi-threaded benchmark with perf ($NUM_THREADS threads)..."
PERF_MULTI_FILE="${PERF_RESULTS_DIR}/perf_${CPU_VENDOR}_${TIMESTAMP}_multi_${NUM_THREADS}threads_${SMT_STATUS}.csv"
echo "Perf results will be saved to: $PERF_MULTI_FILE"

perf stat -e "$PERF_EVENTS" -o "$PERF_MULTI_FILE" -x, \
    "$EXECUTABLE_PATH" --mode multi --threads "$NUM_THREADS"

echo "Multi-threaded benchmark finished."
echo "----------------------------------------"

echo "All benchmarks finished."
