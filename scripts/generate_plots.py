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
    base_dir = os.path.join(os.path.dirname(__file__), '..')
    results_dir = os.path.join(base_dir, 'results', 'raw_results')
    plots_dir = os.path.join(base_dir, 'results', 'plots')

    print(f"Searching for result files in: {results_dir}")

    # --- 2. Find all result files ---
    csv_files = glob.glob(os.path.join(results_dir, '*.csv'))

    if not csv_files:
        print("No CSV result files found. Please run the benchmark first.")
        return

    # --- 3. Find the latest timestamp and corresponding files ---
    latest_timestamp = ""
    file_info = {}

    # Regex to parse filenames
    file_pattern = re.compile(r'results_(amd|intel)_(\d{8}_\d{6})_(single|multi)\.csv')

    for f_path in csv_files:
        basename = os.path.basename(f_path)
        match = file_pattern.match(basename)
        if match:
            vendor, timestamp, mode = match.groups()
            if timestamp > latest_timestamp:
                latest_timestamp = timestamp
            file_info[f_path] = {'vendor': vendor, 'timestamp': timestamp, 'mode': mode}

    if not latest_timestamp:
        print("Could not find any result files with the expected naming convention.")
        print("Expected format: results_{vendor}_{timestamp}_{mode}.csv")
        return

    print(f"Found latest results from timestamp: {latest_timestamp}")

    # --- 4. Identify latest files and load data ---
    latest_files = {info['mode']: f for f, info in file_info.items() if info['timestamp'] == latest_timestamp}

    if 'single' not in latest_files or 'multi' not in latest_files:
        print(f"Error: Missing single or multi-threaded result file for timestamp {latest_timestamp}.")
        return

    try:
        df_single = pd.read_csv(latest_files['single'])
        df_multi = pd.read_csv(latest_files['multi'])
        vendor = file_info[latest_files['single']]['vendor']
    except Exception as e:
        print(f"Error reading CSV files: {e}")
        return

    print(f"Loaded single-threaded data: {os.path.basename(latest_files['single'])}")
    print(f"Loaded multi-threaded data: {os.path.basename(latest_files['multi'])}")

    # --- 5. Generate Plot ---
    plt.figure(figsize=(12, 8))

    plt.plot(df_single['Input_Size'], df_single['Time_ms'], marker='o', linestyle='-', label='Single-Threaded')
    plt.plot(df_multi['Input_Size'], df_multi['Time_ms'], marker='s', linestyle='-', label='Multi-Threaded')

    plt.xscale('log', base=2)
    plt.yscale('log')

    plt.title(f'FFT Benchmark Performance ({vendor.upper()} CPU - {latest_timestamp})')
    plt.xlabel('Input Size (N)')
    plt.ylabel('Execution Time (milliseconds)')

    plt.legend()
    plt.grid(True, which="both", ls="--")

    # Use ScalarFormatter to avoid scientific notation on axes
    from matplotlib.ticker import ScalarFormatter
    for axis in [plt.gca().xaxis, plt.gca().yaxis]:
        axis.set_major_formatter(ScalarFormatter())

    # --- 6. Save Plot ---
    os.makedirs(plots_dir, exist_ok=True)
    output_filename = f'plot_{vendor}_{latest_timestamp}.png'
    output_path = os.path.join(plots_dir, output_filename)

    try:
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"\nPlot successfully saved to: {output_path}")
    except Exception as e:
        print(f"\nError saving plot: {e}")

if __name__ == '__main__':
    generate_plots()
