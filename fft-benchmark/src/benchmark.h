#pragma once
#include <complex>
#include <thread>
#include <vector>
#include <barrier>

using namespace std;

class benchmark {
public:
    explicit benchmark(char filename[]);
    ~benchmark();

    vector<complex<double>> run_fft_single_threaded();
    vector<complex<double>> run_fft_multithreaded(unsigned int num_cores);
    static unsigned int reverse_bits(unsigned int n, unsigned int bits);

    void print_data() const;

private:
    static void fft_iterative(vector<complex<double>>& data);
    static void fft_iterative_multithreaded(vector<complex<double>>& data, unsigned int num_threads);

    vector<double> input_data;
};
