extern "C" void __cxa_call_terminate(void *);

// Keep a relocation to the support-only symbol that the empty stub lacked.
void (*volatile terminate_function)(void *) = &__cxa_call_terminate;

int main() { return terminate_function == nullptr; }
