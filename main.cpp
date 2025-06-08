// A naïve prime counter just to burn CPU cycles.
// Build with -g and -fno-omit-frame-pointer so VTune resolves stacks cleanly.

#include <chrono>
#include <iostream>

bool is_prime(unsigned long long n) {
    if (n < 2) return false;
    for (unsigned long long i = 2; i * i <= n; ++i) {
        if (n % i == 0) return false;
    }
    return true;
}

int main() {
    const unsigned long long limit = 10'0000;          // 1e5
    unsigned long long prime_count = 0;

    auto t0 = std::chrono::high_resolution_clock::now();
    for (unsigned long long n = 2; n <= limit; ++n)
        if (is_prime(n)) ++prime_count;
    auto t1 = std::chrono::high_resolution_clock::now();

    std::chrono::duration<double> dt = t1 - t0;
    std::cout << "Found " << prime_count << " primes up to "
              << limit << " in " << dt.count() << " s\n";
    return 0;
}
