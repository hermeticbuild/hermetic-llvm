#include <omp.h>

int main() {
  omp_lock_t lock;
  return sizeof(lock) == 0;
}
