package wasm

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/imports/wasi_snapshot_preview1"
)

var thinLTOP1, thinLTOP2, thinLTOP3, thinLTOValidator string

func TestWASIThinLTO(t *testing.T) {
	validator, err := runfiles.Rlocation(thinLTOValidator)
	if err != nil {
		t.Fatal(err)
	}
	for _, variant := range []struct{ name, location string }{
		{"p1", thinLTOP1}, {"p2", thinLTOP2}, {"p3", thinLTOP3},
	} {
		t.Run(variant.name, func(t *testing.T) {
			path, err := runfiles.Rlocation(variant.location)
			if err != nil {
				t.Fatal(err)
			}
			if output, err := exec.Command(validator, "validate", "--features", "all", path).CombinedOutput(); err != nil {
				t.Fatalf("validate: %v\n%s", err, output)
			}
			blob, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if variant.name != "p1" {
				if !bytes.HasPrefix(blob, []byte{'\x00', 'a', 's', 'm', 13, 0, 1, 0}) {
					t.Fatal("expected a WebAssembly component")
				}
				return
			}
			ctx := context.Background()
			runtime := wazero.NewRuntime(ctx)
			defer runtime.Close(ctx)
			if _, err := wasi_snapshot_preview1.Instantiate(ctx, runtime); err != nil {
				t.Fatal(err)
			}
			var stdout bytes.Buffer
			if _, err := runtime.InstantiateWithConfig(ctx, blob, wazero.NewModuleConfig().WithStdout(&stdout)); err != nil {
				t.Fatal(err)
			}
			if got := stdout.String(); got != "42\n" {
				t.Fatalf("stdout = %q, want 42", got)
			}
		})
	}
}
