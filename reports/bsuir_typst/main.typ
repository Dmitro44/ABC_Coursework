#include("course_title.typ")

#import "stp/stp.typ"
#show: stp.STP2024


#pagebreak()

#counter(page).update(4)

#outline()
#outline(title:none,target:label("appendix"))

#pagebreak()

#include("introduction.typ")

#include("first_section.typ")

#include("second_section.typ")

#include("third_section.typ")

#include("fourth_section.typ")

#include("fifth_section.typ")

#include("conclusion.typ")

#bibliography("bibliography.bib")

#stp.appendix(type:[обязательное], title:[Справка о проверке на заимствования], [

  #figure(
    image("img/antiplagiat.png"),
    caption: [Справка о проверке на заимствования]
  )

])


#stp.appendix(type:[обязательное], title:[Листинг программного кода], [

```
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
const std::vector<int> INPUT_SIZES = {
    32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384,
    32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216,
    33554432
};

benchmark::benchmark() = default;

benchmark::~benchmark() = default;

void benchmark::run_single_threaded_benchmark(const string& output_file_path)
{
    ofstream results_file_stream(output_file_path);

    if (!results_file_stream.is_open())
    {
        cerr << "Failed to create single results file: " << output_file_path << endl;
        return;
    }

    results_file_stream << "Input_Size,Time_ms" << endl;
    cout << "Running single-threaded benchmark..." << endl;

    for (int size : INPUT_SIZES)
    {
        // Generate random data
        vector<complex<double>> data;
        data.reserve(size);
        std::mt19937 gen(1234); // Fixed seed for reproducibility
        std::uniform_real_distribution<> dis(-1000.0, 1000.0);
        for (int i = 0; i < size; ++i)
        {
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
    cout << "Single-threaded benchmark finished. Results saved to " << output_file_path << endl;
}

void benchmark::run_multithreaded_benchmark(const string& output_file_path, unsigned int num_threads)
{
    ofstream results_file_stream(output_file_path);

    if (!results_file_stream.is_open())
    {
        cerr << "Failed to create multi results file: " << output_file_path << endl;
        return;
    }

    results_file_stream << "Input_Size,Time_ms" << endl;
    cout << "Running multi-threaded benchmark with " << num_threads << " threads..." << endl;

    for (int size : INPUT_SIZES)
    {
        // Generate random data
        vector<complex<double>> data;
        data.reserve(size);
        std::mt19937 gen(1234); // Fixed seed for reproducibility
        std::uniform_real_distribution<> dis(-1000.0, 1000.0);
        for (int i = 0; i < size; ++i)
        {
            data.emplace_back(dis(gen), 0.0);
        }

        // Run and measure
        auto start = chrono::high_resolution_clock::now();
        fft_iterative_multithreaded(data, num_threads);
        auto end = chrono::high_resolution_clock::now();
        chrono::duration<double, milli> duration = end - start;

        results_file_stream << size << "," << duration.count() << endl;
        cout << "  Input size " << size << ": " << duration.count() << " ms" << endl;
    }

    results_file_stream.close();
    cout << "Multi-threaded benchmark finished. Results saved to " << output_file_path << endl;
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
            for (int j = 0; j < m / 2; ++j)
            {
                complex<double> t = w * data[k + j + m / 2];
                complex<double> u = data[k + j];
                data[k + j] = u + t;
                data[k + j + m / 2] = u - t;
                w *= wm;
            }
        }
    }
}

void benchmark::fft_iterative_multithreaded(vector<complex<double>>& data, unsigned int num_threads)
{
    const size_t N = data.size();
    if (N < 2) return;
    int logN = 0;
    while ((1 << logN) < N) ++logN;

    auto worker = [&](unsigned int thread_id, std::barrier<>& sync_point)
    {
        // 1. Parallel Bit-Reversal
        // Each thread handles a chunk of the array.
        const size_t chunk_size = (N + num_threads - 1) / num_threads;
        const size_t start_index = thread_id * chunk_size;
        const size_t end_index = std::min(start_index + chunk_size, N);

        for (size_t i = start_index; i < end_index; ++i)
        {
            unsigned int reversed_i = reverse_bits(i, logN);
            if (i < reversed_i)
            {
                swap(data[i], data[reversed_i]);
            }
        }

        sync_point.arrive_and_wait();

        // 2. Parallel FFT Stages
        for (int s = 1; s <= logN; ++s)
        {
            const int m = (1 << s);
            const complex<double> wm = polar(1.0, -2 * M_PI / m);
            const int num_groups = N / m;

            if (num_groups >= num_threads)
            {
                // Strategy 1: Coarse-grained parallelism for early stages
                for (int group_idx = thread_id; group_idx < num_groups; group_idx += num_threads)
                {
                    const int k = group_idx * m;
                    complex<double> w(1.0, 0);
                    for (int j = 0; j < m / 2; ++j)
                    {
                        complex<double> t = w * data[k + j + m / 2];
                        complex<double> u = data[k + j];
                        data[k + j] = u + t;
                        data[k + j + m / 2] = u - t;
                        w *= wm;
                    }
                }
            }
            else
            {
                // Strategy 2: Fine-grained parallelism for later stages
                const int threads_per_group = num_threads / num_groups;
                const int my_group = thread_id / threads_per_group;
                const int my_local_thread_id = thread_id % threads_per_group;

                if (my_group < num_groups)
                {
                    const int k = my_group * m;
                    const int butterflies_in_group = m / 2;
                    const int work_per_local_thread =
                        (butterflies_in_group + threads_per_group - 1) / threads_per_group;
                    const int start_j = my_local_thread_id * work_per_local_thread;
                    const int end_j = std::min(start_j + work_per_local_thread, butterflies_in_group);

                    complex<double> w = pow(wm, start_j);
                    for (int j = start_j; j < end_j; ++j)
                    {
                        complex<double> t = w * data[k + j + m / 2];
                        complex<double> u = data[k + j];
                        data[k + j] = u + t;
                        data[k + j + m / 2] = u - t;
                        w *= wm;
                    }
                }
            }

            sync_point.arrive_and_wait();
        }
    };

    // Run threads
    vector<thread> threads;
    barrier sync_point(num_threads);
    for (unsigned int i = 0; i < num_threads; ++i)
    {
        threads.emplace_back(worker, i, std::ref(sync_point));
    }

    // Wait for all threads
    for (auto& thread : threads)
    {
        thread.join();
    }
}


#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <chrono>
#include <complex>
#include <random>
#include <algorithm> // For std::reverse

// OpenCL headers
#include <CL/cl.h>

#ifndef KERNEL_FILE_PATH
#define KERNEL_FILE_PATH "fft_kernel.cl" // Fallback for non-CMake builds
#endif

// Helper function to check OpenCL errors
void checkError(cl_int err, const char* name) {
    if (err != CL_SUCCESS) {
        std::cerr << "ERROR: " << name << " (" << err << ")" << std::endl;
        exit(EXIT_FAILURE);
    }
}

// Function to load OpenCL kernel source code from file
std::string loadKernelSource(const char* filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "ERROR: Could not open kernel file " << filename << std::endl;
        exit(EXIT_FAILURE);
    }
    std::string source((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    return source;
}

// Function to reverse bits (for bit-reversal permutation)
unsigned int reverse_bits(unsigned int n, unsigned int bits) {
    unsigned int reversed = 0;
    for (unsigned int i = 0; i < bits; ++i) {
        reversed <<= 1;
        reversed |= (n & 1);
        n >>= 1;
    }
    return reversed;
}

int main(int argc, char* argv[]) {
    std::string output_file_path;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--output-file" && i + 1 < argc) {
            output_file_path = argv[++i];
        }
    }

    if (output_file_path.empty()) {
        std::cerr << "Error: Please provide an output file path with --output-file" << std::endl;
        return 1;
    }

    std::ofstream results_file_stream(output_file_path);
    if (!results_file_stream.is_open()) {
        std::cerr << "Failed to create results file: " << output_file_path << std::endl;
        return 1;
    }

    results_file_stream << "Input_Size,Time_ms" << std::endl;
    // Define input sizes to be benchmarked (same as CPU for comparison)
    const std::vector<int> INPUT_SIZES = {
        32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384,
        32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216
    };

    cl_int err;
    cl_platform_id platform;
    cl_device_id device;
    cl_context context;
    cl_command_queue queue;
    cl_program program;
    cl_kernel kernel;

    err = clGetPlatformIDs(1, &platform, NULL);
    checkError(err, "clGetPlatformIDs");

    err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_GPU, 1, &device, NULL);
    if (err == CL_DEVICE_NOT_FOUND) {
        std::cout << "No GPU found, trying CPU..." << std::endl;
        err = clGetDeviceIDs(platform, CL_DEVICE_TYPE_CPU, 1, &device, NULL);
        checkError(err, "clGetDeviceIDs (CPU)");
    } else {
        checkError(err, "clGetDeviceIDs (GPU)");
    }

    char deviceName[128];
    clGetDeviceInfo(device, CL_DEVICE_NAME, sizeof(deviceName), deviceName, NULL);
    std::cout << "Using device: " << deviceName << std::endl;

    context = clCreateContext(NULL, 1, &device, NULL, NULL, &err);
    checkError(err, "clCreateContext");

    queue = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &err);
    checkError(err, "clCreateCommandQueue");

    std::string kernelSource = loadKernelSource(KERNEL_FILE_PATH);
    const char* kernelSourcePtr = kernelSource.c_str();
    program = clCreateProgramWithSource(context, 1, &kernelSourcePtr, NULL, &err);
    checkError(err, "clCreateProgramWithSource");

    err = clBuildProgram(program, 1, &device, NULL, NULL, NULL);
    if (err != CL_SUCCESS) {
        size_t logSize;
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &logSize);
        std::vector<char> buildLog(logSize);
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, logSize, buildLog.data(), NULL);
        std::cerr << "ERROR: OpenCL Build Log:\n" << buildLog.data() << std::endl;
        checkError(err, "clBuildProgram"); // This will exit
    }

    kernel = clCreateKernel(program, "fft_kernel", &err);
    checkError(err, "clCreateKernel");

    std::cout << "Running GPU benchmark..." << std::endl;

    for (int N : INPUT_SIZES) {
        // Generate random data (real part only for now, complex part 0)
        std::vector<cl_float2> h_data(N); // Host data
        std::mt19937 gen(1234); // Fixed seed for reproducibility
        std::uniform_real_distribution<> dis(-1000.0, 1000.0);
        for (int i = 0; i < N; ++i) {
            h_data[i] = { (cl_float)dis(gen), 0.0f };
        }

        // Perform bit-reversal permutation on host (or could be a separate kernel)
        int logN = 0;
        while ((1 << logN) < N) ++logN; // N must be a power of 2 for this FFT

        std::vector<cl_float2> h_data_permuted = h_data; // Copy for permutation
        for (int i = 0; i < N; ++i) {
            unsigned int reversed_i = reverse_bits(i, logN);
            if (i < reversed_i) {
                std::swap(h_data_permuted[i], h_data_permuted[reversed_i]);
            }
        }

        cl_mem d_data = clCreateBuffer(context, CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR, 
                                       sizeof(cl_float2) * N, h_data_permuted.data(), &err);
        checkError(err, "clCreateBuffer");

        err = clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_data);
        checkError(err, "clSetKernelArg 0");
        err = clSetKernelArg(kernel, 1, sizeof(cl_int), &N);
        checkError(err, "clSetKernelArg 1");

        size_t globalWorkSize[1] = { (size_t)N / 2 }; // Each work-item processes one butterfly
        size_t localWorkSize[1] = { 64 }; // Smaller local work size for broader compatibility

        if (globalWorkSize[0] < localWorkSize[0]) {
            localWorkSize[0] = globalWorkSize[0];
        }

        double total_kernel_duration_ms = 0;
        auto start_host = std::chrono::high_resolution_clock::now();

        for (int stage = 1; stage <= logN; ++stage) {
            err = clSetKernelArg(kernel, 2, sizeof(cl_int), &stage);
            checkError(err, "clSetKernelArg 2 (stage)");

            cl_event event;
            err = clEnqueueNDRangeKernel(queue, kernel, 1, NULL, globalWorkSize, localWorkSize, 0, NULL, &event);
            checkError(err, "clEnqueueNDRangeKernel");

            err = clWaitForEvents(1, &event);
            checkError(err, "clWaitForEvents");

            // Get kernel execution time from event profiling
            cl_ulong time_start, time_end;
            clGetEventProfilingInfo(event, CL_PROFILING_COMMAND_START, sizeof(cl_ulong), &time_start, NULL);
            clGetEventProfilingInfo(event, CL_PROFILING_COMMAND_END, sizeof(cl_ulong), &time_end, NULL);
            total_kernel_duration_ms += (time_end - time_start) / 1000000.0;
            clReleaseEvent(event);
        }
        auto end_host = std::chrono::high_resolution_clock::now();

        results_file_stream << N << "," << total_kernel_duration_ms << std::endl;
        std::cout << "  Input size " << N << ": Kernel " << total_kernel_duration_ms << " ms" << std::endl;

        // std::vector<cl_float2> d_results(N);
        // err = clEnqueueReadBuffer(queue, d_data, CL_TRUE, 0, sizeof(cl_float2) * N, d_results.data(), 0, NULL, NULL);
        // checkError(err, "clEnqueueReadBuffer");

        clReleaseMemObject(d_data);
    }

    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseCommandQueue(queue);
    clReleaseContext(context);
    results_file_stream.close();

    std::cout << "GPU benchmark finished. Results saved to " << output_file_path << std::endl;

    return 0;
}


// fft_kernel.cl

// Function to multiply two complex numbers (a + bi) * (c + di) = (ac - bd) + (ad + bc)i
float2 complex_mul(float2 a, float2 b) {
    return (float2)(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// Function to compute the twiddle factor (e^(-2*PI*k/N))
float2 twiddle_factor(int k, int N) {
    float angle = -2.0f * M_PI_F * (float)k / (float)N;
    return (float2)(cos(angle), sin(angle));
}

__kernel void fft_kernel(
    __global float2* data, // Input/output array of complex numbers
    int N,                 // Total size of the FFT
    int stage              // Current stage (s from 1 to logN)
) {
    int gid = get_global_id(0);

    // Boundary check to ensure we don't go out of bounds
    if (gid >= N / 2) {
        return;
    }

    // m = 2^stage 
    int m = 1 << stage;
    int m_half = m / 2;

    // Derive 'j' (index within the butterfly group) and 'k' (start of the current m-sized block)
    // from the global ID.
    // There are N/2 total butterflies in a stage.
    // gid ranges from 0 to N/2 - 1.
    int j = gid % m_half;
    int k_group_start = (gid / m_half) * m;

    // Calculate the twiddle factor for this specific butterfly
    // w = e^(-2*PI*j/m)
    float2 w = twiddle_factor(j, m);

    // Perform the butterfly operation
    float2 u = data[k_group_start + j];
    float2 t = complex_mul(w, data[k_group_start + j + m_half]);

    data[k_group_start + j] = u + t;
    data[k_group_start + j + m_half] = u - t;
}
```

])

#stp.appendix(type:[обязательное], title:[Функциональная схема алгоритма,\ реализующая программное средство], [


])

#stp.appendix(type:[обязательное], title:[Блок схема алгоритма,\ реализующего программное средство], [

#counter(page).update(48)

])

#stp.appendix(type:[обязательное], title:[Графики сравнения \ производительности процессоров], [

#counter(page).update(49)

])

#stp.appendix(type:[обязательное], title:[Графическое представления нагрузки \ на ядра процессоров], [

#counter(page).update(52)

])

#stp.appendix(type:[обязательное], title:[Ведомость курсового проекта], [

#counter(page).update(56)

])
