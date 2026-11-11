extern "C" int msvcstl_probe(int);

extern "C" __declspec(dllexport) int go_msvcstl_probe(int value) {
  return msvcstl_probe(value);
}
