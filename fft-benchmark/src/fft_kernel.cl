// fft_kernel.cl
// OpenCL kernel for one stage of Radix-2 FFT

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
    // Get global ID of the work-item
    // Each work-item processes one butterfly operation
    int gid = get_global_id(0);

    // m = 2^stage (size of the current sub-FFT)
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
