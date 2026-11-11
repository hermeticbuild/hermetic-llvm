int foreign_msvcstl(int value);

int main() {
  return foreign_msvcstl(42) == 42 ? 0 : 1;
}
