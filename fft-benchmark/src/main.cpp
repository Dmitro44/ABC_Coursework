#include "benchmark.h"
#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <iomanip>
#include <thread>

int main(int argc, char* argv[])
{
    string mode;
    unsigned int num_threads = 0;
    string output_file_path; // New variable for output file path

    for (int i = 1; i < argc; ++i)
    {
        string arg = argv[i];
        if (arg == "--mode" && i + 1 < argc)
        {
            mode = argv[++i];
        }
        else if (arg == "--threads" && i + 1 < argc)
        {
            try
            {
               num_threads = stoul(argv[++i]);
            } catch (const std::invalid_argument& ia)
            {
                cerr << "Error: Invalid number for --threads" << endl;
                return 1;
            }
        }
        else if (arg == "--output-file" && i + 1 < argc) // New argument parsing
        {
            output_file_path = argv[++i];
        }
    }

    if (mode.empty())
    {
        cerr << "Error: Please provide a mode with --mode [single|multi]" << endl;
        return 1;
    }

    if (output_file_path.empty()) // Check if output file path is provided
    {
        cerr << "Error: Please provide an output file path with --output-file" << endl;
        return 1;
    }

    benchmark bench;

    if (mode == "single")
    {
        bench.run_single_threaded_benchmark(output_file_path); // Pass output_file_path
    }
    else if (mode == "multi")
    {
        if (num_threads == 0)
        {
            num_threads = std::thread::hardware_concurrency();
        }
        bench.run_multithreaded_benchmark(output_file_path, num_threads); // Pass output_file_path and num_threads
    }

    return 0;
}
