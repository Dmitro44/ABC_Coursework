#pragma once

#include <complex>
#include <string>
#include <vector>

using namespace std;

class benchmark {
public:
    benchmark();
    ~benchmark();

    void run_single_threaded_benchmark(const string& vendor, const string& timestamp, const string& smt);
    void run_multithreaded_benchmark(const string& vendor, const string& timestamp, const string& smt);

private:
    static void fft_iterative(vector<complex<double>>& data);
    static void fft_iterative_multithreaded(vector<complex<double>>& data, unsigned int num_threads);
    static unsigned int reverse_bits(unsigned int n, unsigned int bits);
};
