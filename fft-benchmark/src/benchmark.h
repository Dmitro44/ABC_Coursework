#pragma once
#include <complex>
#include <thread>
#include <vector>

using namespace std;

class benchmark {
public:
    explicit benchmark(char filename[]);
    ~benchmark();

    void run_single_threaded_benchmark(const string& vendor, const string& timestamp);
    void run_multithreaded_benchmark(const string& vendor, const string& timestamp);

    vector<complex<double>> run_fft_single_threaded();
    vector<complex<double>> run_fft_multithreaded(unsigned int num_cores);
    static unsigned int reverse_bits(unsigned int n, unsigned int bits);

    void print_data() const;
    void write_to_file();

private:
    static void fft_iterative(vector<complex<double>>& data);
    static void fft_iterative_multithreaded(vector<complex<double>>& data, unsigned int num_threads);

    vector<double> input_data;
};
