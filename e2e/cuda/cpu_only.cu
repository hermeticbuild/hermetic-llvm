// CUDA translation units with no device registration must pass through unchanged.
extern "C" int cpu_only_value() { return 123; }
