package main

/*
#include <stdio.h>

static void greet(void) {
    puts("hello from cgo");
}
*/
import "C"

func main() {
    C.greet()
}
