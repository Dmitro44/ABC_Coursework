import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import re


def generate_plots():
    """
    Finds the latest benchmark results, plots them, and saves the plot to a file.
    """
    # --- 1. Define Paths ---
    # The script is in 'scripts/', so we go up one level to the project root.
    base_dir = os.path.join(os.path.dirname(__file__), "..")
    results_root_dir = os.path.join(base_dir, "results", "raw_results")
    plots_dir = os.path.join(base_dir, "results", "plots")

    print(f"Searching for result directories in: {results_root_dir}")

    # --- 2. Find the latest timestamped directory ---
    # Directories are expected to be named with timestamps (e.g., "20251119_153000")
    all_result_dirs = [
        d
        for d in os.listdir(results_root_dir)
        if os.path.isdir(os.path.join(results_root_dir, d))
    ]
    all_result_dirs.sort(reverse=True)  # Sort to get the latest timestamp first

    if not all_result_dirs:
        print(
            "No timestamped result directories found. Please run the benchmark first."
        )
        return

    latest_result_dir_name = all_result_dirs[0]
    latest_result_dir_path = os.path.join(results_root_dir, latest_result_dir_name)
    print(f"Found latest results in directory: {latest_result_dir_path}")

    # --- 3. Find all CSV files within the latest directory ---
    csv_files = glob.glob(os.path.join(latest_result_dir_path, "*.csv"))

    if not csv_files:
        print(f"No CSV files found in {latest_result_dir_path}.")
        return

    # --- 4. Load data and prepare for plotting ---
    data_frames = []
    cpu_vendor = "unknown"  # Will be determined from the first file

    # Regex to parse filenames: {vendor}_{mode}[_{threads}threads]_{smt_status}.csv
    file_pattern = re.compile(
        r"(amd|intel)_(single|multi)(?:_(\d+)threads)?_(smt_on|smt_off)\.csv"
    )

    for f_path in csv_files:
        basename = os.path.basename(f_path)
        match = file_pattern.match(basename)
        if match:
            vendor, mode, threads_str, smt = match.groups()
            if cpu_vendor == "unknown":  # Set vendor from the first file
                cpu_vendor = vendor

            label = ""
            if mode == "single":
                label = f"Single-Threaded (SMT {smt.split('_')[1].upper()})"
            elif mode == "multi" and threads_str:
                label = f"Multi-Threaded ({threads_str} threads, SMT {smt.split('_')[1].upper()})"

            try:
                df = pd.read_csv(f_path)
                data_frames.append(
                    {
                        "df": df,
                        "label": label,
                        "mode": mode,
                        "threads": threads_str,
                        "smt": smt,
                    }
                )
            except Exception as e:
                print(f"Error reading {f_path}: {e}")
        else:
            print(f"Skipping file with unexpected name format: {basename}")

    if not data_frames:
        print("No valid data files found for plotting.")
        return

    # Sort data_frames for consistent plotting order (e.g., single SMT on, single SMT off, multi SMT on, multi SMT off)
    # This is a simple sort, can be made more sophisticated if needed
    data_frames.sort(
        key=lambda x: (x["mode"], x["threads"] if x["threads"] else "", x["smt"])
    )

    # --- 5. Generate Plot ---

    plt.figure(figsize=(12, 8))

    all_input_sizes = []  # To store input sizes for custom ticks

    for item in data_frames:
        linestyle = "-" if item["smt"] == "smt_on" else "--"

        marker = "o" if item["mode"] == "single" else "s"

        # Plot Y-axis in milliseconds (reverted from microseconds)

        plt.plot(
            item["df"]["Input_Size"],
            item["df"]["Time_ms"],
            marker=marker,
            linestyle=linestyle,
            label=item["label"],
        )

        if not all_input_sizes:
            all_input_sizes = item["df"]["Input_Size"].tolist()

    plt.xscale("log", base=2)

    plt.yscale("log")

    plt.title(
        f"FFT Benchmark Performance ({cpu_vendor.upper()} CPU - {latest_result_dir_name})"
    )

    plt.xlabel("Input Size (N)")

    plt.ylabel("Execution Time (milliseconds)")  # Reverted Y-axis label

    plt.legend()

    plt.grid(True, which="both", ls="--")

    # Set custom ticks for the X-axis to match the input sizes

    if all_input_sizes:
        # Show a subset of ticks to prevent overcrowding (e.g., every other value)

        tick_subset = all_input_sizes[::2]

        plt.xticks(
            tick_subset, labels=[str(s) for s in tick_subset], rotation=45, ha="right"
        )

    # Use ScalarFormatter for the y-axis to avoid scientific notation

    from matplotlib.ticker import ScalarFormatter

    plt.gca().yaxis.set_major_formatter(ScalarFormatter())

    # Clear x-axis minor ticks as we have set major ticks manually

    plt.gca().xaxis.set_minor_formatter(plt.NullFormatter())

    # --- 6. Save Plot ---
    os.makedirs(plots_dir, exist_ok=True)
    output_filename = f"plot_{cpu_vendor}_{latest_result_dir_name}.png"
    output_path = os.path.join(plots_dir, output_filename)

    try:
        plt.savefig(output_path, dpi=300, bbox_inches="tight")
        print(f"\nPlot successfully saved to: {output_path}")
    except Exception as e:
        print(f"\nError saving plot: {e}")


if __name__ == "__main__":
    generate_plots()
