package main

import (
	"os"
	"syscall"
)

func main() {
	if len(os.Args) != 2 {
		panic("expected the path to msvcstl_bridge.dll")
	}
	probe := syscall.NewLazyDLL(os.Args[1]).NewProc("go_msvcstl_probe")
	result, _, _ := probe.Call(42)
	if result != 42 {
		panic("Microsoft STL DLL call returned an unexpected result")
	}
}
