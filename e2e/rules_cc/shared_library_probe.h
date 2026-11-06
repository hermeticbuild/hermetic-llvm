#pragma once

#if defined(_WIN32) && defined(SHARED_LIBRARY_BUILD)
__declspec(dllexport)
#elif defined(_WIN32)
__declspec(dllimport)
#endif
int shared_answer(void);
