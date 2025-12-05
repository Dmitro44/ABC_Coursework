#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
set -x

# --- Core Configuration ---
# The first argument is a space-separated string of physical core counts to test, e.g., "2 4 6 8"
# Defaults to a common set if not provided.
CORE_LIST=${1:-""}

# --- CPU Vendor Detection ---
VENDOR_ID_RAW=$(grep -m 1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
CPU_VENDOR="unknown"
if [[ "$VENDOR_ID_RAW" == "GenuineIntel" ]]; then
    CPU_VENDOR="intel"
elif [[ "$VENDOR_ID_RAW" == "AuthenticAMD" ]]; then
    CPU_VENDOR="amd"
fi

# --- mpstat installation check ---
if ! command -v mpstat &>/dev/null; then
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
        mpstat -P ALL 1 >"$MPSTAT_FILE_SINGLE" 2>&1 &
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

    # Multi-threaded benchmarks based on core counts
    if [ -n "$CORE_LIST" ]; then
        echo "Running multi-threaded benchmarks for core counts: $CORE_LIST"
        for NUM_CORES in $CORE_LIST; do
            local NUM_THREADS
            if [ "$SMT_STATE" == "smt_on" ]; then
                if [ "$CPU_VENDOR" == "intel" ]; then
                    # Custom logic for user's specific Intel CPU
                    if [ "$NUM_CORES" -le 6 ]; then
                        # For 6 cores or less, use 2 threads per core
                        NUM_THREADS=$((NUM_CORES * 2))
                    else
                        # For more than 6 cores, use 1.5 threads per core (e.g., 8 cores -> 12 threads)
                        NUM_THREADS=$((NUM_CORES + NUM_CORES / 2))
                    fi
                else
                    # Standard logic for AMD (and non-hybrid CPUs)
                    NUM_THREADS=$((NUM_CORES * 2))
                fi
            else # smt_off
                # With SMT/HT disabled, it's always 1 thread per core
                NUM_THREADS=$NUM_CORES
            fi

            if [ "$NUM_THREADS" -gt "$CURRENT_NPROC" ]; then
                echo "--- Skipping $NUM_CORES cores ($NUM_THREADS threads requested > $CURRENT_NPROC available) ---"
                continue
            fi
            echo "--- Running on $NUM_CORES cores ($NUM_THREADS threads) ---"

            if [ "$MPSTAT_ENABLED" = true ]; then
                local MPSTAT_FILE_MULTI="$RAW_OUTPUT_ROOT_DIR/mpstat_${CPU_VENDOR}_multi_${NUM_CORES}cores_${SMT_STATE}.txt"
                echo "  -> Starting mpstat, logging to $MPSTAT_FILE_MULTI"
                mpstat -P ALL 1 >"$MPSTAT_FILE_MULTI" 2>&1 &
                MPSTAT_PID=$!
            fi

            local RAW_FILE_MULTI="$RAW_OUTPUT_ROOT_DIR/${CPU_VENDOR}_multi_${NUM_CORES}cores_${SMT_STATE}.csv"
            local PERF_FILE_MULTI="$PERF_OUTPUT_ROOT_DIR/perf_${CPU_VENDOR}_multi_${NUM_CORES}cores_${SMT_STATE}.csv"

            # Build CPU affinity list
            local CPU_LIST
            if [ "$SMT_STATE" == "smt_on" ]; then
                # SMT ON: use consecutive CPUs 0,1,2,...
                CPU_LIST="0-$((NUM_THREADS - 1))"
            else
                # SMT OFF: different topology depending on vendor
                if [ "$CPU_VENDOR" == "intel" ]; then
                    # Intel hybrid: P-cores at 0,2,4,6,8 (even), E-cores at 9,10,11,...
                    # When SMT off, available CPUs are: 0,2,4,6,8,9,10,11,...
                    local INTEL_CPUS=""
                    local p_core_idx=0
                    local e_core_idx=0
                    for ((i = 0; i < NUM_THREADS; i++)); do
                        [ -n "$INTEL_CPUS" ] && INTEL_CPUS+=","
                        # First, use up to 4 P-cores (0, 2, 4, 6)
                        if [ $p_core_idx -lt 4 ]; then
                            INTEL_CPUS+="$((p_core_idx * 2))"
                            ((p_core_idx++))
                        # Then, use E-cores (8, 9, 10, 11, ...)
                        else
                            INTEL_CPUS+="$((8 + e_core_idx))"
                            ((e_core_idx++))
                        fi
                    done
                    CPU_LIST="$INTEL_CPUS"
                else
                    # AMD: only even CPUs are available (0,2,4,6,...)
                    local EVEN_CPUS=""
                    for ((i = 0; i < NUM_THREADS; i++)); do
                        [ -n "$EVEN_CPUS" ] && EVEN_CPUS+=","
                        EVEN_CPUS+="$((i * 2))"
                    done
                    CPU_LIST="$EVEN_CPUS"
                fi
            fi

            perf stat -e "$PERF_EVENTS" -o "$PERF_FILE_MULTI" -x, \
                taskset -c "$CPU_LIST" "$EXECUTABLE_PATH" --mode multi --threads "$NUM_THREADS" --output-file "$RAW_FILE_MULTI"

            if [ "$MPSTAT_ENABLED" = true ] && [ -n "$MPSTAT_PID" ]; then
                echo "  -> Stopping mpstat (PID: $MPSTAT_PID)"
                kill "$MPSTAT_PID"
                unset MPSTAT_PID
                sleep 1 # Give a moment for the process to terminate
            fi
        done
    else
        echo "No core list provided, skipping multi-threaded benchmarks."
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
