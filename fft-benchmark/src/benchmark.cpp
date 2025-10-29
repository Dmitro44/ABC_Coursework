#include "benchmark.h"

#include <barrier>
#include <fstream>
#include <iostream>
#include <complex>
#include <random>
#include <chrono>

benchmark::benchmark(char filename[])
{
   ifstream input_file(filename);

   if (!input_file.is_open())
   {
      cerr << "Failed to open file " << filename << std::endl;
   }

   double number;

   while (input_file >> number)
   {
      input_data.push_back(number);
   }
}

benchmark::~benchmark()
{

}

void benchmark::run_single_threaded_benchmark(const string& vendor, const string& timestamp)
{
   string filename = "../../results/raw_results/results_" + vendor + "_" + timestamp + "_single.csv";

   ofstream results_file_stream(filename);

   if (!results_file_stream.is_open())
   {
      cerr << "Failed to create single results file" << filename << endl;
      return;
   }

   results_file_stream << "Threads,Time_ms" << endl;

   auto start_single = chrono::high_resolution_clock::now();
   run_fft_single_threaded();
   auto end_single = chrono::high_resolution_clock::now();
   chrono::duration<double, milli> duration_single = end_single - start_single;
   results_file_stream << "1," << duration_single.count() << endl;
   cout << "Single-threaded FFT took " << duration_single.count() << " ms." << std::endl;

   results_file_stream.close();
}

void benchmark::run_multithreaded_benchmark(const string& vendor, const string& timestamp)
{
   string filename = "../../results/raw_results/results_" + vendor + "_" + timestamp + "_multi.csv";

   ofstream results_file_stream(filename);

   if (!results_file_stream.is_open())
   {
      cerr << "Failed to create single results file" << filename << endl;
      return;
   }

   results_file_stream << "Threads,Time_ms" << endl;

   unsigned int num_cores = thread::hardware_concurrency();

   auto start_multi = chrono::high_resolution_clock::now();
   run_fft_multithreaded(num_cores);
   auto end_multi = chrono::high_resolution_clock::now();
   chrono::duration<double, milli> duration_multi = end_multi - start_multi;
   results_file_stream << num_cores << "," << duration_multi.count() << endl;
   cout << "Multi-threaded FFT with " << num_cores << " threads took " << duration_multi.count() << " ms." << std::endl;

   results_file_stream.close();
}

vector<complex<double>> benchmark::run_fft_single_threaded()
{
   vector<complex<double>> data_to_transform;
   for (const auto& real_part: input_data)
   {
      data_to_transform.emplace_back(real_part, 0.0);
   }

   fft_iterative(data_to_transform);

   return data_to_transform;
}

vector<complex<double>> benchmark::run_fft_multithreaded(unsigned int num_cores)
{
   vector<complex<double>> data_to_transform;
   for (const auto& real_part: input_data)
   {
      data_to_transform.emplace_back(real_part, 0.0);
   }

   fft_iterative_multithreaded(data_to_transform, num_cores);

   return data_to_transform;
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

void benchmark::print_data() const
{
   for (const double i : input_data)
   {
      cout << i << " ";
   }
}

void benchmark::write_to_file()
{
   ofstream output_file("../../results/raw-results/");

}

