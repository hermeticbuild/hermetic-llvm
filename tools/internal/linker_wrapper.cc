#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <fstream>
#include <memory>
#include <string>
#include <vector>

#include "tools/cpp/runfiles/runfiles.h"
#include "tools/internal/linker_wrapper_config.h"

using bazel::tools::cpp::runfiles::Runfiles;

namespace {

constexpr const char* kTreeRootToken = "__LLVM_LINKER_TREE__";

std::string ResolveRunfilePath(const Runfiles& runfiles,
                               const char* runfile_key,
                               const char* description) {
  if (runfile_key == nullptr || runfile_key[0] == '\0') {
    fprintf(stderr, "linker_wrapper: empty runfile key for %s\n", description);
    exit(2);
  }

  std::string resolved_path = runfiles.Rlocation(runfile_key);
  if (!resolved_path.empty()) {
    return resolved_path;
  }

  fprintf(stderr, "linker_wrapper: failed to resolve runfile for %s: key='%s'\n",
          description, runfile_key);
  exit(2);
}

std::vector<std::string> ParseContractFields(const std::string& line) {
  std::vector<std::string> fields;
  size_t start = 0;
  while (start <= line.size()) {
    const size_t tab = line.find('\t', start);
    if (tab == std::string::npos) {
      fields.push_back(line.substr(start));
      break;
    }
    fields.push_back(line.substr(start, tab - start));
    start = tab + 1;
  }
  return fields;
}

void RequireArity(const std::vector<std::string>& fields, size_t expected,
                  const char* directive) {
  if (fields.size() == expected) {
    return;
  }
  fprintf(stderr,
          "linker_wrapper: invalid contract %s directive (expected %zu fields, got %zu)\n",
          directive, expected, fields.size());
  exit(2);
}

std::string ReplaceTreeToken(const std::string& value,
                             const std::string& tree_root) {
  const std::string token(kTreeRootToken);
  const size_t position = value.find(token);
  if (position == std::string::npos) {
    return value;
  }
  return value.substr(0, position) + tree_root +
         value.substr(position + token.size());
}

void ApplyContractLine(const std::vector<std::string>& fields,
                       const std::string& tree_root,
                       std::vector<std::string>* arguments) {
  if (fields.empty()) {
    return;
  }

  if (fields[0] == "arg") {
    RequireArity(fields, 2, "arg");
    arguments->push_back(ReplaceTreeToken(fields[1], tree_root));
    return;
  }

  if (fields[0] == "setenv") {
    RequireArity(fields, 3, "setenv");
    const std::string value = ReplaceTreeToken(fields[2], tree_root);
    if (setenv(fields[1].c_str(), value.c_str(), 1) != 0) {
      fprintf(stderr, "linker_wrapper: setenv failed for '%s': %s\n",
              fields[1].c_str(), strerror(errno));
      exit(2);
    }
    return;
  }

  fprintf(stderr, "linker_wrapper: unknown contract directive '%s'\n",
          fields[0].c_str());
  exit(2);
}

void AppendLinkerContractArguments(const std::string& contract_manifest_path,
                                   const std::string& tree_root,
                                   std::vector<std::string>* arguments) {
  std::ifstream contract_stream(contract_manifest_path);
  if (!contract_stream.is_open()) {
    fprintf(stderr, "linker_wrapper: failed to open linker contract at '%s'\n",
            contract_manifest_path.c_str());
    exit(2);
  }

  std::string line;
  while (std::getline(contract_stream, line)) {
    if (line.empty() || line[0] == '#') {
      continue;
    }
    ApplyContractLine(ParseContractFields(line), tree_root, arguments);
  }
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <clang++-style-link-args...>\n"
                    "Example: %s input.o -o output_binary\n",
            argv[0], argv[0]);
    return 2;
  }

  std::string runfiles_error;
  std::unique_ptr<Runfiles> runfiles(
      Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &runfiles_error));
  if (!runfiles) {
    fprintf(stderr, "linker_wrapper: failed to initialize runfiles: %s\n",
            runfiles_error.c_str());
    return 2;
  }

  const std::string clang_path =
      ResolveRunfilePath(*runfiles, llvm_toolchain::kLinkerWrapperClangRlocation,
                         "platform clang++");
  const std::string contract_manifest_path = ResolveRunfilePath(
      *runfiles, llvm_toolchain::kLinkerWrapperContractManifestRlocation,
      "linker contract manifest");
  const std::string contract_tree_path = ResolveRunfilePath(
      *runfiles, llvm_toolchain::kLinkerWrapperContractTreeRlocation,
      "linker contract tree");

  std::vector<std::string> argument_storage;
  argument_storage.reserve(static_cast<size_t>(argc) + 24);
  argument_storage.push_back(clang_path);

  AppendLinkerContractArguments(contract_manifest_path, contract_tree_path,
                                &argument_storage);

  for (int index = 1; index < argc; ++index) {
    argument_storage.push_back(argv[index]);
  }

  std::vector<char*> exec_arguments;
  exec_arguments.reserve(argument_storage.size() + 1);
  for (std::string& argument : argument_storage) {
    exec_arguments.push_back(const_cast<char*>(argument.c_str()));
  }
  exec_arguments.push_back(nullptr);

  execv(clang_path.c_str(), exec_arguments.data());
  fprintf(stderr, "linker_wrapper: execv failed for '%s': %s\n",
          clang_path.c_str(), strerror(errno));
  return 2;
}
