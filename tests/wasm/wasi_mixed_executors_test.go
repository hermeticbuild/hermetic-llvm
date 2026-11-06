package wasm

import (
	"bytes"
	"os"
	"os/exec"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

var componentPaths, validatorPath string

func TestWASIComponentsWithMixedExecutors(t *testing.T) {
	validator, err := runfiles.Rlocation(validatorPath)
	if err != nil {
		t.Fatal(err)
	}
	paths := strings.Fields(componentPaths)
	if len(paths) != 4 {
		t.Fatalf("expected both P2/P3 components from both executors, got %d", len(paths))
	}
	for _, location := range paths {
		t.Run(location, func(t *testing.T) {
			path, err := runfiles.Rlocation(location)
			if err != nil {
				t.Fatal(err)
			}
			binary, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.HasPrefix(binary, []byte{'\x00', 'a', 's', 'm', 13, 0, 1, 0}) {
				t.Fatal("expected a WebAssembly component")
			}
			if output, err := exec.Command(validator, "validate", "--features", "all", path).CombinedOutput(); err != nil {
				t.Fatalf("validate: %v\n%s", err, output)
			}
		})
	}
}
