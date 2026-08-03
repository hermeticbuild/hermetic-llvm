typedef void *EFI_HANDLE;
typedef unsigned long long EFI_STATUS;

struct EFI_SYSTEM_TABLE;

static void outb(unsigned short port, unsigned char value) {
    __asm__ volatile("outb %0, %1" : : "a"(value), "Nd"(port));
}

EFI_STATUS efi_main(EFI_HANDLE image_handle, struct EFI_SYSTEM_TABLE *system_table) {
    static const char marker[] = "UEFI_BOOT_OK\n";

    (void)image_handle;
    (void)system_table;

    for (unsigned long i = 0; i < sizeof(marker) - 1; ++i) {
        outb(0xe9, marker[i]);
    }

    outb(0xf4, 0x21);
    for (;;) {
        __asm__ volatile("hlt");
    }
}
