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

    # Regex to parse filenames with SMT status and optional thread count
    file_pattern = re.compile(r'results_(amd|intel)_(\d{8}_\d{6})_(single|multi)(?:_(\d+)threads)?_(smt_on|smt_off)\.csv')

    for f_path in csv_files:
        basename = os.path.basename(f_path)
        match = file_pattern.match(basename)
        if match:
            vendor, timestamp, mode, threads_str, smt = match.groups()
            if timestamp > latest_timestamp:
                latest_timestamp = timestamp
            file_info[f_path] = {'vendor': vendor, 'timestamp': timestamp, 'mode': mode, 'threads_str': threads_str, 'smt': smt}

    if not latest_timestamp:
        print("Could not find any result files with the expected naming convention.")
        print("Expected format: results_{vendor}_{timestamp}_{mode}[_{threads}threads]_{smt_status}.csv")
        return

    print(f"Found latest results from timestamp: {latest_timestamp}")

    # --- 4. Identify latest files and load data ---
    latest_files_by_key = {}
    selected_multi_threads_str = None

    # First, find all unique threads_str for multi-threaded files at the latest_timestamp
    multi_threads_strs = set()
    for f, info in file_info.items():
        if info['timestamp'] == latest_timestamp and info['mode'] == 'multi' and info['threads_str']:
            multi_threads_strs.add(info['threads_str'])

    if multi_threads_strs:
        # For simplicity, pick the first one if multiple thread counts exist for the same timestamp.
        selected_multi_threads_str = sorted(list(multi_threads_strs))[0]
    else:
        print(f"Warning: No multi-threaded files found for timestamp {latest_timestamp}. Multi-threaded plots will be skipped.")

    # Now populate latest_files_by_key
    for f, info in file_info.items():
        if info['timestamp'] == latest_timestamp:
            if info['mode'] == 'single':
                key = (info['mode'], None, info['smt']) # threads_str is None for single
                latest_files_by_key[key] = f
            elif info['mode'] == 'multi' and info['threads_str'] == selected_multi_threads_str:
                key = (info['mode'], info['threads_str'], info['smt'])
                latest_files_by_key[key] = f

    required_keys = [
        ('single', None, 'smt_on'), ('single', None, 'smt_off')
    ]
    if selected_multi_threads_str:
        required_keys.extend([
            ('multi', selected_multi_threads_str, 'smt_on'),
            ('multi', selected_multi_threads_str, 'smt_off')
        ])

    # Check if all required files are present
    if not all(key in latest_files_by_key for key in required_keys):
        print(f"Error: Missing one or more result files for timestamp {latest_timestamp}.")
        missing = [key for key in required_keys if key not in latest_files_by_key]
        print(f"Missing data for: {missing}")
        return

    try:
        df_single_on = pd.read_csv(latest_files_by_key[('single', None, 'smt_on')])
        df_single_off = pd.read_csv(latest_files_by_key[('single', None, 'smt_off')])
        vendor = file_info[latest_files_by_key[('single', None, 'smt_on')]]['vendor']

        df_multi_on = None
        df_multi_off = None
        if selected_multi_threads_str:
            df_multi_on = pd.read_csv(latest_files_by_key[('multi', selected_multi_threads_str, 'smt_on')])
            df_multi_off = pd.read_csv(latest_files_by_key[('multi', selected_multi_threads_str, 'smt_off')])

    except Exception as e:
        print(f"Error reading CSV files: {e}")
        return

    print(f"Loaded single-threaded (SMT ON) data: {os.path.basename(latest_files_by_key[('single', None, 'smt_on')])}")
    print(f"Loaded single-threaded (SMT OFF) data: {os.path.basename(latest_files_by_key[('single', None, 'smt_off')])}")
    if selected_multi_threads_str:
        print(f"Loaded multi-threaded ({selected_multi_threads_str}, SMT ON) data: {os.path.basename(latest_files_by_key[('multi', selected_multi_threads_str, 'smt_on')])}")
        print(f"Loaded multi-threaded ({selected_multi_threads_str}, SMT OFF) data: {os.path.basename(latest_files_by_key[('multi', selected_multi_threads_str, 'smt_off')])}")

    # --- 5. Generate Plot ---
    plt.figure(figsize=(12, 8))

    plt.plot(df_single_on['Input_Size'], df_single_on['Time_ms'], marker='o', linestyle='-', label='Single-Threaded (SMT ON)')
    plt.plot(df_single_off['Input_Size'], df_single_off['Time_ms'], marker='o', linestyle='--', label='Single-Threaded (SMT OFF)')
    if selected_multi_threads_str and df_multi_on is not None and df_multi_off is not None:
        plt.plot(df_multi_on['Input_Size'], df_multi_on['Time_ms'], marker='s', linestyle='-', label=f'Multi-Threaded ({selected_multi_threads_str}, SMT ON)')
        plt.plot(df_multi_off['Input_Size'], df_multi_off['Time_ms'], marker='s', linestyle='--', label=f'Multi-Threaded ({selected_multi_threads_str}, SMT OFF)')

    plt.xscale('log', base=2)
    plt.yscale('log')

    plot_title_threads_part = f" - {selected_multi_threads_str}" if selected_multi_threads_str else ""
    plt.title(f'FFT Benchmark Performance ({vendor.upper()} CPU - {latest_timestamp}{plot_title_threads_part})')
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
    output_filename = f'plot_{vendor}_{latest_timestamp}{plot_title_threads_part.replace(" ", "")}.png'
    output_path = os.path.join(plots_dir, output_filename)

    try:
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        print(f"\nPlot successfully saved to: {output_path}")
    except Exception as e:
        print(f"\nError saving plot: {e}")

if __name__ == '__main__':
    generate_plots()
