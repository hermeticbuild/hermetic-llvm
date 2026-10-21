// The SDK header requests exe_initialize_mta.lib and forces its initializer in.
#define _EXE_INITIALIZE_MTA
#include <comdef.h>

int main() {
  APTTYPE apartment;
  APTTYPEQUALIFIER qualifier;
  if (FAILED(CoGetApartmentType(&apartment, &qualifier)) ||
      apartment != APTTYPE_MTA) {
    return 1;
  }

  // comdef.h selects comsupp.lib or comsuppw.lib according to UNICODE.
  // Converting a narrow string exercises the selected archive's implementation.
  const _bstr_t text("42");
  if (text.length() != 2 || static_cast<const wchar_t*>(text)[1] != L'2') {
    return 2;
  }
  return 0;
}
