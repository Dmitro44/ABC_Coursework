#include "benchmark.h"
#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <iomanip>

// Function to get CPU vendor from /proc/cpuinfo
string get_cpu_vendor()
{
    ifstream cpu_info("/proc/cpuinfo");
    string line;
    if (cpu_info.is_open())
    {
        while (getline(cpu_info, line))
        {
            if (line.find("vendor_id") != string::npos)
            {
                if (line.find("AuthenticAMD") != string::npos)
                {
                    return "amd";
                }
                if (line.find("GenuineIntel") != string::npos)
                {
                    return "intel";
                }
            }
        }
    }
    return "unknown";
}

string get_smt_status()
{
    ifstream smt_info("/sys/devices/system/cpu/smt/control");
    string line;
    if (smt_info.is_open())
    {
        while (getline(smt_info, line))
        {
            if (line.find("on") != string::npos)
            {
                return "smt_on";
            }

            if (line.find("off") != string::npos)
            {
                return "smt_off";
            }
        }
    }
    return "unknown";
}

int main()
{
    // 1. Get CPU vendor
    string cpu_vendor = get_cpu_vendor();

    // 2. Get current time
    auto now = chrono::system_clock::now();
    auto in_time_t = chrono::system_clock::to_time_t(now);
    stringstream ss;
    ss << put_time(std::localtime(&in_time_t), "%d%m%Y_%H%M%S");
    string timestamp = ss.str();

    // 3. Get SMT status
    string smt_status = get_smt_status();

    benchmark bench;

    bench.run_single_threaded_benchmark(cpu_vendor, timestamp, smt_status);

    bench.run_multithreaded_benchmark(cpu_vendor, timestamp, smt_status);

    return 0;
}
