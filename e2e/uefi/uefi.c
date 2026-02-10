typedef void *EFI_HANDLE;
typedef unsigned long long EFI_STATUS;

struct EFI_SYSTEM_TABLE;

EFI_STATUS efi_main(EFI_HANDLE image_handle, struct EFI_SYSTEM_TABLE *system_table) {
    (void)image_handle;
    (void)system_table;
    return 0;
}
