// A target-local suppression must override the toolchain's default warning,
// including when all remaining warnings are errors.
void set_parameter(int parameter) { parameter = 1; }

int main(void) { return 0; }
