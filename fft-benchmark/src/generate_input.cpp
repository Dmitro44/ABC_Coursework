#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <random>
#include <iomanip>

// Function to check if a number is a power of two
bool is_power_of_two(long long n)
{
    return (n > 0) && ((n & (n - 1)) == 0);
}

int main(int argc, char* argv[])
{
    if (argc != 3)
    {
        std::cerr << "Usage: " << argv[0] << " <num_samples> <output_file>" << std::endl;
        return 1;
    }

    long long num_samples;
    try
    {
        num_samples = std::stoll(argv[1]);
        if (num_samples <= 0)
        {
            std::cerr << "Error: Number of samples must be a positive integer." << std::endl;
            return 1;
        }
    }
    catch (const std::invalid_argument& e)
    {
        std::cerr << "Error: Invalid number of samples. Please provide an integer." << std::endl;
        return 1;
    }
    catch (const std::out_of_range& e)
    {
        std::cerr << "Error: Number of samples is out of range." << std::endl;
        return 1;
    }

    std::string output_file = argv[2];

    if (!is_power_of_two(num_samples))
    {
        std::cout << "Warning: " << num_samples <<
            " is not a power of 2. FFT algorithms are most efficient with input sizes that are powers of 2." <<
            std::endl;
    }

    std::ofstream out_stream(output_file);
    if (!out_stream.is_open())
    {
        std::cerr << "Error: Failed to open output file '" << output_file << "'" << std::endl;
        return 1;
    }

    // Use a high-quality random number generator
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<> dis(0.0, 1.0);

    out_stream << std::fixed << std::setprecision(10);

    for (long long i = 0; i < num_samples; ++i)
    {
        out_stream << dis(gen) << "\n";
    }

    std::cout << "Successfully generated " << num_samples << " samples in '" << output_file << "'" << std::endl;

    return 0;
}
