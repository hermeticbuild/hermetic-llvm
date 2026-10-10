"""Makes the release build at the current commit bootstrap from llvm-22.1.7-2."""

import json
import re
from pathlib import Path

SEED_VERSION = "22.1.7"
SEED_RELEASE = "llvm-22.1.7-2"

module = Path("MODULE.bazel")
text = module.read_text()
llvm_version = re.search(r'^LLVM_VERSION = "([^"]+)"$', text, re.M).group(1)
index_path = Path("extensions/llvm_toolchain_minimal_index.json")
index = json.loads(index_path.read_text())
assert index["latest_by_llvm_version"][SEED_VERSION] == SEED_RELEASE

# Older commits select the seed with PREBUILT_LLVM_VERSION in MODULE.bazel,
# newer ones fall back to default_prebuilt_llvm_version if the index has no
# release for LLVM_VERSION.
text, n = re.subn(r'^PREBUILT_LLVM_VERSION = "[^"]+"$', f'PREBUILT_LLVM_VERSION = "{SEED_VERSION}"', text, flags=re.M)
if n:
    module.write_text(text)
else:
    index["default_prebuilt_llvm_version"] = SEED_VERSION
    index["latest_by_llvm_version"].pop(llvm_version, None)
    index_path.write_text(json.dumps(index, indent=2) + "\n")
