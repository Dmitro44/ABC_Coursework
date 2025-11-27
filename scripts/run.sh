#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Thread Configuration ---
# The first argument is a space-separated string of thread counts to test, e.g., "2 4 8 16"
THREAD_LIST=${1:-""}

# --- CPU Vendor Detection ---
VENDOR_ID_RAW=$(grep -m 1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
CPU_VENDOR="unknown"
if [[ "$VENDOR_ID_RAW" == "GenuineIntel" ]]; then
    CPU_VENDOR="intel"
elif [[ "$VENDOR_ID_RAW" == "AuthenticAMD" ]]; then
    CPU_VENDOR="amd"
fi

# --- mpstat installation check ---
if ! command -v mpstat &> /dev/null; then
    echo "Warning: 'mpstat' is not installed. CPU load will not be monitored."
    echo "To install it, run: sudo apt-get install sysstat (on Debian/Ubuntu) or sudo pacman -S sysstat (on Arch)"
    MPSTAT_ENABLED=false
else
    MPSTAT_ENABLED=true
fi

# --- Build Configuration ---
BASE_DIR=$(dirname "$(dirname "$(readlink -f "$0")")")

BUILD_DIR="$BASE_DIR/fft-benchmark/cmake-build-release"
EXECUTABLE_PATH="$BUILD_DIR/fft_benchmark"
GPU_EXECUTABLE_PATH="$BUILD_DIR/gpu_fft_benchmark"

# --- Results Configuration ---
TIMESTAMP=$(date +"%d%m%Y_%H%M%S")
RAW_OUTPUT_ROOT_DIR="$BASE_DIR/results/raw_results/${TIMESTAMP}_${CPU_VENDOR}"
PERF_OUTPUT_ROOT_DIR="$BASE_DIR/results/perf_results/${TIMESTAMP}_${CPU_VENDOR}"
PERF_EVENTS="cycles,instructions,cache-references,cache-misses,branch-instructions,branch-misses"

# --- Run Benchmarks ---

# Create the output directories for this run
mkdir -p "$RAW_OUTPUT_ROOT_DIR"
mkdir -p "$PERF_OUTPUT_ROOT_DIR"
echo "Raw results for this run will be saved to: $RAW_OUTPUT_ROOT_DIR"
echo "Perf results for this run will be saved to: $PERF_OUTPUT_ROOT_DIR"

# Function to run a set of benchmarks for a given SMT state
run_benchmark_set() {
    local SMT_STATE=$1
    local CURRENT_NPROC=$(nproc)
    echo "----------------------------------------"
    echo "Running benchmarks with SMT: $SMT_STATE (Available logical cores: $CURRENT_NPROC)"

    # Single-threaded benchmark (always runs)
    echo "Running single-threaded benchmark..."
    if [ "$MPSTAT_ENABLED" = true ]; then
        local MPSTAT_FILE_SINGLE="$RAW_OUTPUT_ROOT_DIR/mpstat_${CPU_VENDOR}_single_${SMT_STATE}.txt"
        echo "  -> Starting mpstat, logging to $MPSTAT_FILE_SINGLE"
        mpstat -P ALL 1 > "$MPSTAT_FILE_SINGLE" 2>&1 &
        MPSTAT_PID=$!
    fi

    local RAW_FILE_SINGLE="$RAW_OUTPUT_ROOT_DIR/${CPU_VENDOR}_single_${SMT_STATE}.csv"
    local PERF_FILE_SINGLE="$PERF_OUTPUT_ROOT_DIR/perf_${CPU_VENDOR}_single_${SMT_STATE}.csv"
    perf stat -e "$PERF_EVENTS" -o "$PERF_FILE_SINGLE" -x, \
        "$EXECUTABLE_PATH" --mode single --output-file "$RAW_FILE_SINGLE"

    if [ "$MPSTAT_ENABLED" = true ] && [ -n "$MPSTAT_PID" ]; then
        echo "  -> Stopping mpstat (PID: $MPSTAT_PID)"
        kill "$MPSTAT_PID"
        unset MPSTAT_PID
        sleep 1 # Give a moment for the process to terminate
    fi

    # Multi-threaded benchmarks (run if a thread list was provided)
    if [ -n "$THREAD_LIST" ]; then
        echo "Running multi-threaded benchmarks for thread counts: $THREAD_LIST"
        for NUM_THREADS in $THREAD_LIST; do
            if [ "$NUM_THREADS" -gt "$CURRENT_NPROC" ]; then
                echo "--- Skipping $NUM_THREADS threads (requested > available $CURRENT_NPROC cores) ---"
                continue
            fi
            echo "--- Running for $NUM_THREADS threads ---"

            if [ "$MPSTAT_ENABLED" = true ]; then
                local MPSTAT_FILE_MULTI="$RAW_OUTPUT_ROOT_DIR/mpstat_${CPU_VENDOR}_multi_${NUM_THREADS}threads_${SMT_STATE}.txt"
                echo "  -> Starting mpstat, logging to $MPSTAT_FILE_MULTI"
                mpstat -P ALL 1 > "$MPSTAT_FILE_MULTI" 2>&1 &
                MPSTAT_PID=$!
            fi

            local RAW_FILE_MULTI="$RAW_OUTPUT_ROOT_DIR/${CPU_VENDOR}_multi_${NUM_THREADS}threads_${SMT_STATE}.csv"
            local PERF_FILE_MULTI="$PERF_OUTPUT_ROOT_DIR/perf_${CPU_VENDOR}_multi_${NUM_THREADS}threads_${SMT_STATE}.csv"
            perf stat -e "$PERF_EVENTS" -o "$PERF_FILE_MULTI" -x, \
                "$EXECUTABLE_PATH" --mode multi --threads "$NUM_THREADS" --output-file "$RAW_FILE_MULTI"

            if [ "$MPSTAT_ENABLED" = true ] && [ -n "$MPSTAT_PID" ]; then
                echo "  -> Stopping mpstat (PID: $MPSTAT_PID)"
                kill "$MPSTAT_PID"
                unset MPSTAT_PID
                sleep 1 # Give a moment for the process to terminate
            fi
        done
    else
        echo "No thread list provided, skipping multi-threaded benchmarks."
    fi
}

# --- Run with SMT ON ---
echo "Ensuring SMT is ON for benchmarks..."
sudo sh -c "echo on > /sys/devices/system/cpu/smt/control"
run_benchmark_set "smt_on"

# --- Run with SMT OFF ---
echo "Disabling SMT for benchmarks..."
sudo sh -c "echo off > /sys/devices/system/cpu/smt/control"
run_benchmark_set "smt_off"

# --- Re-enable SMT ---
echo "Re-enabling SMT..."
sudo sh -c "echo on > /sys/devices/system/cpu/smt/control"

# --- Run GPU Benchmark ---
echo "----------------------------------------"
echo "Running GPU benchmark..."
RAW_FILE_GPU="$RAW_OUTPUT_ROOT_DIR/${CPU_VENDOR}_gpu.csv"
"$GPU_EXECUTABLE_PATH" --output-file "$RAW_FILE_GPU"

echo "All benchmarks finished."
