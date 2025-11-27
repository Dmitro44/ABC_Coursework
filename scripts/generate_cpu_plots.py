#!/usr/bin/env python3

import os
import argparse
import pandas as pd
import matplotlib.pyplot as plt
import re

def parse_mpstat_average(file_path):
    """
    Parses the 'Average:' section of an mpstat output file and returns a pandas DataFrame.
    """
    average_lines = []
    with open(file_path, 'r') as f:
        for line in f:
            if line.strip().startswith("Average:"):
                average_lines.append(line.strip())

    if not average_lines:
        raise ValueError("No 'Average:' section found in the mpstat output file.")

    # The first 'Average:' line is the header
    header_line = average_lines.pop(0)
    # Clean up header: remove "Average:" and split by space
    columns = re.split(r'\s+', header_line)[1:]

    data = []
    for line in average_lines:
        # Clean up data line: remove "Average:" and split by space
        parts = re.split(r'\s+', line)[1:]
        if len(parts) == len(columns):
            data.append(parts)

    if not data:
        raise ValueError("No average data found to parse.")

    df = pd.DataFrame(data, columns=columns)

    # Filter out the 'all' CPU line, we want per-core data
    df = df[df['CPU'] != 'all']

    # Convert relevant columns to numeric
    numeric_cols = ['%usr', '%nice', '%sys', '%iowait', '%irq', '%soft', '%steal', '%guest', '%gnice', '%idle']
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
    
    if 'CPU' in df.columns:
        df['CPU'] = pd.to_numeric(df['CPU'], errors='coerce')

    df = df.sort_values(by='CPU').reset_index(drop=True)
    
    # Create a DataFrame with all 16 CPU IDs (0 to 15)
    all_cpus = pd.DataFrame({'CPU': range(16)})

    # Merge the parsed data with the full CPU range
    # Use a left merge to keep all 16 CPUs, filling missing values with NaN
    df_full = pd.merge(all_cpus, df, on='CPU', how='left')

    # Fill NaN values in '%usr' (and other relevant columns) with 0
    # This handles CPUs that were not reported by mpstat (e.g., logical cores when SMT is off)
    df_full['%usr'] = df_full['%usr'].fillna(0)
    # Fill other numeric columns with 0 if they are not present for all CPUs
    for col in ['%nice', '%sys', '%iowait', '%irq', '%soft', '%steal', '%guest', '%gnice', '%idle']:
        if col in df_full.columns:
            df_full[col] = df_full[col].fillna(0)
        else: # If column doesn't exist after merge, add it with 0s
            df_full[col] = 0.0

    # Ensure CPU column is integer type
    df_full['CPU'] = df_full['CPU'].astype(int)

    return df_full

def generate_average_cpu_plot(file_path, plots_dir):
    """
    Reads an mpstat output file, parses the average stats, and generates a bar chart.
    """
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}")
        return

    print(f"Processing mpstat file for average utilization: {file_path}")

    try:
        df = parse_mpstat_average(file_path)
        
        if df.empty:
            print(f"Warning: No valid average data to plot from {file_path}")
            return

        plt.style.use('seaborn-v0_8-whitegrid')
        plt.figure(figsize=(14, 8))

        # Create the bar chart
        bar_container = plt.bar(df['CPU'], df['%usr'])

        plt.title(f"Average CPU User Utilization\n(Source: {os.path.basename(file_path)})")
        plt.xlabel("CPU Core Number")
        plt.ylabel("Average User Utilization (%)")
        
        # Set x-axis to have integer ticks for each CPU
        plt.xticks(df['CPU'])
        plt.ylim(0, 100) # Set y-axis limit to 100%

        # Add percentage labels on top of each bar
        plt.bar_label(bar_container, fmt='%.1f%%')

        plt.tight_layout()

        # --- Save Plot ---
        base_filename = os.path.basename(file_path)
        # Add a suffix to distinguish it from the time-series plot if we ever re-add it
        plot_filename = f"plot_avg_{os.path.splitext(base_filename)[0]}.png"
        output_path = os.path.join(plots_dir, plot_filename)

        plt.savefig(output_path, dpi=300, bbox_inches="tight")
        print(f"  -> Plot successfully saved to: {output_path}\n")
        plt.close()

    except Exception as e:
        print(f"An error occurred while processing {file_path}: {e}")

def main():
    """
    Main function to parse arguments and generate plots.
    """
    parser = argparse.ArgumentParser(
        description="Generate average CPU utilization bar charts from one or more mpstat output files."
    )
    parser.add_argument(
        "files",
        metavar="FILE",
        nargs="+",
        help="Path to one or more mpstat output files to be plotted."
    )
    args = parser.parse_args()

    # --- Define Paths ---
    base_dir = os.path.join(os.path.dirname(__file__), "..")
    plots_dir = os.path.join(base_dir, "results", "plots")
    os.makedirs(plots_dir, exist_ok=True)

    for file_path in args.files:
        generate_average_cpu_plot(file_path, plots_dir)

if __name__ == "__main__":
    main()