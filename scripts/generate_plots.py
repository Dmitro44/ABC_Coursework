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

    # Regex to parse filenames with SMT status
    file_pattern = re.compile(r'results_(amd|intel)_(\d{8}_\d{6})_(single|multi)_(smt_on|smt_off)\.csv')

    for f_path in csv_files:
        basename = os.path.basename(f_path)
        match = file_pattern.match(basename)
        if match:
            vendor, timestamp, mode, smt = match.groups()
            if timestamp > latest_timestamp:
                latest_timestamp = timestamp
            file_info[f_path] = {'vendor': vendor, 'timestamp': timestamp, 'mode': mode, 'smt': smt}

    if not latest_timestamp:
        print("Could not find any result files with the expected naming convention.")
        print("Expected format: results_{vendor}_{timestamp}_{mode}_{smt_status}.csv")
        return

    print(f"Found latest results from timestamp: {latest_timestamp}")

    # --- 4. Identify latest files and load data ---
    latest_files = {}
    for f, info in file_info.items():
        if info['timestamp'] == latest_timestamp:
            key = (info['mode'], info['smt'])
            latest_files[key] = f

    required_keys = [
        ('single', 'smt_on'), ('single', 'smt_off'),
        ('multi', 'smt_on'), ('multi', 'smt_off')
    ]
    if not all(key in latest_files for key in required_keys):
        print(f"Error: Missing one or more result files for timestamp {latest_timestamp}.")
        missing = [key for key in required_keys if key not in latest_files]
        print(f"Missing data for: {missing}")
        return

    try:
        df_single_on = pd.read_csv(latest_files[('single', 'smt_on')])
        df_single_off = pd.read_csv(latest_files[('single', 'smt_off')])
        df_multi_on = pd.read_csv(latest_files[('multi', 'smt_on')])
        df_multi_off = pd.read_csv(latest_files[('multi', 'smt_off')])
        vendor = file_info[latest_files[('single', 'smt_on')]]['vendor']
    except Exception as e:
        print(f"Error reading CSV files: {e}")
        return

    print(f"Loaded single-threaded (SMT ON) data: {os.path.basename(latest_files[('single', 'smt_on')])}")
    print(f"Loaded single-threaded (SMT OFF) data: {os.path.basename(latest_files[('single', 'smt_off')])}")
    print(f"Loaded multi-threaded (SMT ON) data: {os.path.basename(latest_files[('multi', 'smt_on')])}")
    print(f"Loaded multi-threaded (SMT OFF) data: {os.path.basename(latest_files[('multi', 'smt_off')])}")

    # --- 5. Generate Plot ---
    plt.figure(figsize=(12, 8))

    plt.plot(df_single_on['Input_Size'], df_single_on['Time_ms'], marker='o', linestyle='-', label='Single-Threaded (SMT ON)')
    plt.plot(df_single_off['Input_Size'], df_single_off['Time_ms'], marker='o', linestyle='--', label='Single-Threaded (SMT OFF)')
    plt.plot(df_multi_on['Input_Size'], df_multi_on['Time_ms'], marker='s', linestyle='-', label='Multi-Threaded (SMT ON)')
    plt.plot(df_multi_off['Input_Size'], df_multi_off['Time_ms'], marker='s', linestyle='--', label='Multi-Threaded (SMT OFF)')

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
