#include <gtest/gtest.h>
#include "../src/benchmark.h"

TEST(SinglethreadedFftResultShouldBeCorrect, BasicAssertions)
{
   benchmark bench("../input_data/test_input.txt");

   auto result = bench.run_fft_single_threaded();

   std::vector<std::complex<double>> expected_result = {
       {1.0, 0.0},
       {1.0, 0.0},
       {1.0, 0.0},
       {1.0, 0.0}
   };

   ASSERT_EQ(result.size(), expected_result.size());

   for (size_t i = 0; i < result.size(); ++i)
   {
      EXPECT_NEAR(result[i].real(), expected_result[i].real(), 1e-9);
      EXPECT_NEAR(result[i].imag(), expected_result[i].imag(), 1e-9);
   }
}

TEST(MultithreadedFftResultShouldBeCorrect, BasicAssertions)
{
    benchmark bench("../input_data/input_262144.txt");

    auto expected_result = bench.run_fft_single_threaded();

    unsigned int num_cores = thread::hardware_concurrency();
    auto actual_result = bench.run_fft_multithreaded(num_cores);

    ASSERT_EQ(actual_result.size(), expected_result.size());

    for (size_t i = 0; i < expected_result.size(); ++i)
    {
        EXPECT_NEAR(expected_result[i].real(), actual_result[i].real(), 1e-9);
        EXPECT_NEAR(expected_result[i].imag(), actual_result[i].imag(), 1e-9);
    }
}