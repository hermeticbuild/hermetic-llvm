package wasm

import (
	"bytes"
	"os"
	"os/exec"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

var (
	wasiP1ThreadsRlocationpath string
	wasiP2CommandRlocationpath string
	wasiP3CommandRlocationpath string
	wasmToolsRlocationpath     string
)

func TestWASIVariants(t *testing.T) {
	wasmTools, err := runfiles.Rlocation(wasmToolsRlocationpath)
	if err != nil {
		t.Fatalf("resolve wasm-tools: %v", err)
	}
	for _, variant := range []struct {
		name      string
		rlocation string
		header    []byte
	}{
		{"p1_threads", wasiP1ThreadsRlocationpath, []byte{'\x00', 'a', 's', 'm', 1, 0, 0, 0}},
		{"p2", wasiP2CommandRlocationpath, []byte{'\x00', 'a', 's', 'm', 13, 0, 1, 0}},
		{"p3", wasiP3CommandRlocationpath, []byte{'\x00', 'a', 's', 'm', 13, 0, 1, 0}},
	} {
		t.Run(variant.name, func(t *testing.T) {
			path, err := runfiles.Rlocation(variant.rlocation)
			if err != nil {
				t.Fatalf("resolve %q: %v", variant.rlocation, err)
			}
			binary, err := os.ReadFile(path)
			if err != nil {
				t.Fatalf("read %q: %v", path, err)
			}
			if !bytes.HasPrefix(binary, variant.header) {
				t.Fatalf("%s does not have the expected WebAssembly header % x", variant.name, variant.header)
			}
			if output, err := exec.Command(wasmTools, "validate", "--features", "all", path).CombinedOutput(); err != nil {
				t.Fatalf("validate %s: %v\n%s", variant.name, err, output)
			}
		})
	}
}
