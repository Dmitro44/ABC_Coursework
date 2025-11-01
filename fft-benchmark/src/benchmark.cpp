#include "benchmark.h"

#include <barrier>
#include <chrono>
#include <complex>
#include <fstream>
#include <iostream>
#include <random>
#include <thread>
#include <vector>

// Define the input sizes to be benchmarked
const std::vector<int> INPUT_SIZES = {32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384,
                                       32768, 65536, 131072, 262144, 524288, 1048576};

benchmark::benchmark() = default;

benchmark::~benchmark() = default;

void benchmark::run_single_threaded_benchmark(const string &vendor, const string &timestamp) {
  string filename = "../../results/raw_results/results_" + vendor + "_" + timestamp + "_single.csv";
  ofstream results_file_stream(filename);

  if (!results_file_stream.is_open()) {
    cerr << "Failed to create single results file: " << filename << endl;
    return;
  }

  results_file_stream << "Input_Size,Time_ms" << endl;
  cout << "Running single-threaded benchmark..." << endl;

  for (int size : INPUT_SIZES) {
    // Generate random data
    vector<complex<double>> data;
    data.reserve(size);
    std::mt19937 gen(1234); // Fixed seed for reproducibility
    std::uniform_real_distribution<> dis(-1000.0, 1000.0);
    for (int i = 0; i < size; ++i) {
      data.emplace_back(dis(gen), 0.0);
    }

    // Run and measure
    auto start = chrono::high_resolution_clock::now();
    fft_iterative(data);
    auto end = chrono::high_resolution_clock::now();
    chrono::duration<double, milli> duration = end - start;

    results_file_stream << size << "," << duration.count() << endl;
    cout << "  Input size " << size << ": " << duration.count() << " ms"
         << endl;
  }

  results_file_stream.close();
  cout << "Single-threaded benchmark finished. Results saved to " << filename << endl;
}

void benchmark::run_multithreaded_benchmark(const string &vendor, const string &timestamp) {
  string filename = "../../results/raw_results/results_" + vendor + "_" + timestamp + "_multi.csv";
  ofstream results_file_stream(filename);

  if (!results_file_stream.is_open()) {
    cerr << "Failed to create multi results file: " << filename << endl;
    return;
  }

  unsigned int num_cores = thread::hardware_concurrency();
  results_file_stream << "Input_Size,Time_ms" << endl;
  cout << "Running multi-threaded benchmark with " << num_cores << " threads..." << endl;

  for (int size : INPUT_SIZES) {
    // Generate random data
    vector<complex<double>> data;
    data.reserve(size);
    std::mt19937 gen(1234); // Fixed seed for reproducibility
    std::uniform_real_distribution<> dis(-1000.0, 1000.0);
    for (int i = 0; i < size; ++i) {
      data.emplace_back(dis(gen), 0.0);
    }

    // Run and measure
    auto start = chrono::high_resolution_clock::now();
    fft_iterative_multithreaded(data, num_cores);
    auto end = chrono::high_resolution_clock::now();
    chrono::duration<double, milli> duration = end - start;

    results_file_stream << size << "," << duration.count() << endl;
    cout << "  Input size " << size << ": " << duration.count() << " ms" << endl;
  }

  results_file_stream.close();
  cout << "Multi-threaded benchmark finished. Results saved to " << filename << endl;
}


unsigned int benchmark::reverse_bits(unsigned int n, unsigned int bits)
{
   unsigned int reversed = 0;
   for (unsigned int i = 0; i < bits; ++i)
   {
      reversed <<= 1;
      reversed |= (n & 1);
      n >>= 1;
   }
   return reversed;
}

void benchmark::fft_iterative(vector<complex<double>>& data)
{
   const size_t N = data.size();
   int logN = 0;
   while ((1 << logN) < N) ++logN;

   for (int i = 0; i < N; ++i)
   {
      unsigned int reversed_i = reverse_bits(i, logN);
      if (i < reversed_i)
      {
         swap(data[i], data[reversed_i]);
      }
   }

   for (int s = 1; s <= logN; ++s)
   {
      int m = (1 << s);
      complex<double> wm = polar(1.0, -2 * M_PI / m);
      for (int k = 0; k < N; k += m)
      {
         complex<double> w(1.0, 0);
         for (int j = 0; j < m/2; ++j)
         {
            complex<double> t = w * data[k + j + m/2];
            complex<double> u = data[k + j];
            data[k + j] = u + t;
            data[k + j + m/2] = u - t;
            w *= wm;
         }
      }
   }
}

void benchmark::fft_iterative_multithreaded(vector<complex<double>>& data, unsigned int num_threads)
{
   const size_t N = data.size();
   int logN = 0;
   while ((1 << logN) < N) ++logN;

   for (int i = 0; i < N; ++i)
   {
      unsigned int reversed_i = reverse_bits(i, logN);
      if (i < reversed_i)
      {
         swap(data[i], data[reversed_i]);
      }
   }

   barrier sync_point(num_threads);

   auto worker = [&](unsigned int thread_id)
   {
      for (int s = 1; s <= logN; ++s)
      {
         const int m = (1 << s);
         const int num_groups = N / m;

         const int groups_per_thread = (num_groups + num_threads - 1) / num_threads;
         const int start_group = thread_id * groups_per_thread;
         const int end_group = std::min(start_group + groups_per_thread, num_groups);

         const complex<double> wm = polar(1.0, -2 * M_PI / m);

         for (int group_idx = start_group; group_idx < end_group; ++group_idx)
         {
            const int k = group_idx * m;
            complex<double> w(1.0, 0);
            for (int j = 0; j < m/2; ++j)
            {
               complex<double> t = w * data[k + j + m/2];
               complex<double> u = data[k + j];
               data[k + j] = u + t;
               data[k + j + m/2] = u - t;
               w *= wm;
            }
         }

         sync_point.arrive_and_wait();
      }
   };

   // Run threads
   vector<thread> threads;
   for (unsigned int i = 0; i < num_threads; ++i)
   {
      threads.emplace_back(worker, i);
   }

   // Wait for all threads
   for (auto& thread : threads)
   {
      thread.join();
   }
}
