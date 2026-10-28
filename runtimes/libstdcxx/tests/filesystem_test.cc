#include <cstdlib>
#ifdef FS_TEST_EXPERIMENTAL
#include <experimental/filesystem>
#else
#include <filesystem>
#endif
#include <fstream>
#include <iostream>
#include <set>
#include <string>

extern "C" int FS_TEST_FUNCTION() {
#ifdef FS_TEST_EXPERIMENTAL
  namespace fs = std::experimental::filesystem;
#else
  namespace fs = std::filesystem;
#endif
  const char *tmp = std::getenv("TEST_TMPDIR");
  if (!tmp)
    return 1;

  std::error_code ec;
  if (fs::current_path() != fs::current_path(ec) || ec ||
      fs::temp_directory_path() != fs::temp_directory_path(ec) || ec)
    return 6;

  // Long names exercise heap-allocated strings in both libstdc++ string ABIs.
  const fs::path root = fs::path(tmp) / "libstdcxx-filesystem-abi-test";
  const fs::path child = root / "directory-longer-than-the-small-string-buffer";
  const fs::path file = child / "file-longer-than-the-small-string-buffer.txt";
  fs::create_directories(child);
  std::ofstream(file.c_str()) << "filesystem test\n";
  if (!fs::is_directory(child) || !fs::is_regular_file(file) ||
      fs::file_size(file) != 16 ||
      file.filename() != "file-longer-than-the-small-string-buffer.txt")
    return 2;

  std::set<fs::path> entries;
  for (const auto &entry : fs::directory_iterator(child))
    entries.insert(entry.path());
  if (entries != std::set<fs::path>{file}) {
    std::cerr << "directory_iterator returned unexpected paths\n";
    return 3;
  }

  entries.clear();
  for (const auto &entry : fs::recursive_directory_iterator(root))
    entries.insert(entry.path());
  if (entries != std::set<fs::path>{child, file}) {
    std::cerr << "recursive_directory_iterator returned unexpected paths\n";
    return 4;
  }

  const fs::path missing = root / "missing-file-longer-than-the-small-string";
  try {
    (void)fs::canonical(missing);
    return 7;
  } catch (const fs::filesystem_error &error) {
    if (error.path1() != missing ||
        std::string(error.what()).find("missing-file") == std::string::npos)
      return 8;
  }

  if (fs::remove_all(root) != 3)
    return 5;
  return 0;
}
