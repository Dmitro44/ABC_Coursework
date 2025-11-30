#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <chrono>
#include <complex>
#include <random>
#include <algorithm> // For std::reverse

// OpenCL headers
#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

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

    // 1. Get platform and device
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

    // 2. Create context
    context = clCreateContext(NULL, 1, &device, NULL, NULL, &err);
    checkError(err, "clCreateContext");

    // 3. Create command queue
    queue = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &err);
    checkError(err, "clCreateCommandQueue");

    // 4. Load and compile kernel
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

        // 5. Create device buffers
        cl_mem d_data = clCreateBuffer(context, CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR, 
                                       sizeof(cl_float2) * N, h_data_permuted.data(), &err);
        checkError(err, "clCreateBuffer");

        // 6. Set kernel arguments that are constant across stages
        err = clSetKernelArg(kernel, 0, sizeof(cl_mem), &d_data);
        checkError(err, "clSetKernelArg 0");
        err = clSetKernelArg(kernel, 1, sizeof(cl_int), &N);
        checkError(err, "clSetKernelArg 1");

        // 7. Execute kernel for each stage
        size_t globalWorkSize[1] = { (size_t)N / 2 }; // Each work-item processes one butterfly
        size_t localWorkSize[1] = { 64 }; // Smaller local work size for broader compatibility

        // Ensure globalWorkSize is not smaller than localWorkSize for this simplified example
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

        // 8. Read results back (optional, for verification)
        // std::vector<cl_float2> d_results(N);
        // err = clEnqueueReadBuffer(queue, d_data, CL_TRUE, 0, sizeof(cl_float2) * N, d_results.data(), 0, NULL, NULL);
        // checkError(err, "clEnqueueReadBuffer");

        // 9. Clean up for this iteration
        clReleaseMemObject(d_data);
    }

    // 10. Clean up OpenCL resources
    clReleaseKernel(kernel);
    clReleaseProgram(program);
    clReleaseCommandQueue(queue);
    clReleaseContext(context);
    results_file_stream.close();

    std::cout << "GPU benchmark finished. Results saved to " << output_file_path << std::endl;

    return 0;
}
