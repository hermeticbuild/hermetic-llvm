package wasm

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/imports/wasi_snapshot_preview1"
)

var (
	wasiDefaultRlocationpath   string
	wasiP1CommandRlocationpath string
	wasiP1ReactorRlocationpath string
)

func readWASI(t *testing.T, rlocation string) []byte {
	t.Helper()
	if rlocation == "" {
		t.Fatal("WASI binary rlocationpath not set")
	}
	path, err := runfiles.Rlocation(rlocation)
	if err != nil {
		t.Fatalf("resolve %q: %v", rlocation, err)
	}
	binary, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %q: %v", path, err)
	}
	return binary
}

func TestWASIP1Command(t *testing.T) {
	for _, variant := range []struct {
		name      string
		rlocation string
	}{
		{"default", wasiDefaultRlocationpath},
		{"p1", wasiP1CommandRlocationpath},
	} {
		t.Run(variant.name, func(t *testing.T) {
			ctx := context.Background()
			runtime := wazero.NewRuntime(ctx)
			t.Cleanup(func() { _ = runtime.Close(ctx) })
			if _, err := wasi_snapshot_preview1.Instantiate(ctx, runtime); err != nil {
				t.Fatalf("instantiate WASI Preview 1: %v", err)
			}

			dir := t.TempDir()
			var stdout, stderr bytes.Buffer
			config := wazero.NewModuleConfig().
				WithArgs("wasi_command", "hermetic").
				WithEnv("WASI_TEST_VALUE", "libc").
				WithStdout(&stdout).
				WithStderr(&stderr).
				WithFSConfig(wazero.NewFSConfig().WithDirMount(dir, "/work"))
			if _, err := runtime.InstantiateWithConfig(ctx, readWASI(t, variant.rlocation), config); err != nil {
				t.Fatalf("run %s command: %v; stderr: %s", variant.name, err, &stderr)
			}
			const want = "hermetic: libc 42.25\n"
			if got := stdout.String(); got != want {
				t.Errorf("stdout = %q, want %q", got, want)
			}
			if got := stderr.String(); got != "" {
				t.Errorf("stderr = %q, want empty", got)
			}
			contents, err := os.ReadFile(filepath.Join(dir, "result.txt"))
			if err != nil {
				t.Fatalf("read WASI result file: %v", err)
			}
			if string(contents) != want {
				t.Errorf("result.txt = %q, want %q", contents, want)
			}
		})
	}
}

func TestWASIP1Reactor(t *testing.T) {
	ctx := context.Background()
	runtime := wazero.NewRuntime(ctx)
	t.Cleanup(func() { _ = runtime.Close(ctx) })
	if _, err := wasi_snapshot_preview1.Instantiate(ctx, runtime); err != nil {
		t.Fatalf("instantiate WASI Preview 1: %v", err)
	}

	module, err := runtime.InstantiateWithConfig(ctx, readWASI(t, wasiP1ReactorRlocationpath),
		wazero.NewModuleConfig().WithStartFunctions())
	if err != nil {
		t.Fatalf("instantiate reactor: %v", err)
	}
	if module.ExportedFunction("_start") != nil {
		t.Error("reactor unexpectedly exports _start")
	}
	initialize := module.ExportedFunction("_initialize")
	if initialize == nil {
		t.Fatal("reactor does not export _initialize")
	}
	add := module.ExportedFunction("add_to_counter")
	if add == nil {
		t.Fatal("reactor does not export add_to_counter")
	}
	if _, err := initialize.Call(ctx); err != nil {
		t.Fatalf("initialize reactor: %v", err)
	}
	after, err := add.Call(ctx, 5)
	if err != nil || len(after) != 1 || after[0] != 42 {
		t.Fatalf("after initialization: result %v, error %v; want 42", after, err)
	}
	next, err := add.Call(ctx, 1)
	if err != nil || len(next) != 1 || next[0] != 43 {
		t.Fatalf("second reactor call: result %v, error %v; want 43", next, err)
	}
}
