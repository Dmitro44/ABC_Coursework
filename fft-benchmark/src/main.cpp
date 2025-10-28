#include "benchmark.h"

int main (int argc, char *argv[]) {

    if (argc > 1)
    {
        return 0;
    }

    benchmark bench(argv[1]);

    bench.run_fft_single_threaded();

    bench.print_data();
    return 0;
}
