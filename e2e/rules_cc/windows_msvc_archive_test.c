int windows_msvc_archive_value(void);
int windows_msvc_archive_order(void);

int main(void) {
  // LIB reverses archive members: the last provider wins symbol resolution.
  return windows_msvc_archive_value() == 42 && windows_msvc_archive_order() == 2
             ? 0
             : 1;
}
