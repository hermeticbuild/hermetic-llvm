extern int fortran_add(int, int);

int main(void) {
  return fortran_add(12, 13) == 25 ? 0 : 1;
}
