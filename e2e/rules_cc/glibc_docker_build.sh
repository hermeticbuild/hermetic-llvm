#!/usr/bin/env bash
# Runs inside the native ARM64 builder. Build an upstream runtime, then use
# that runtime's loader and libraries for every consumer execution.
set -euo pipefail
version=${1:?version}
url=${2:?source URL}
digest=${3:?source SHA256}
printf '%s\n%s\n%s\n' "$version" "$url" "$digest" > /expected-source.txt
if [[ -f /out/build.complete ]]; then
    [[ $(cat /out/build.complete) == "$digest" ]]
    cmp /expected-source.txt /out/source.txt
else
    mkdir /source /build
    curl --fail --location --retry 3 "$url" -o /source.tar
    printf '%s  /source.tar\n' "$digest" | sha256sum --check
    tar -xf /source.tar -C /source --strip-components=1
    cp /expected-source.txt /out/source.txt
    "$CC" --version > /out/compiler.txt
    ld --version > /out/binutils.txt

# The old configure script's make whitelist predates GNU make 4. Only this
# configure-time version check changes; upstream runtime sources stay intact.
    sed -i 's/3\.79\* | 3\.\[89\]\*)/3.79* | 3.[89]* | 4.*)/' /source/configure
    cd /build
    CFLAGS='-O2 -g0 -fcommon -fno-stack-protector' \
        /source/configure --prefix=/runtime --disable-werror --disable-nscd \
        CXX= > /out/configure.log 2>&1
    make -j"${BUILD_JOBS:-8}" > /out/make.log 2>&1
    make install_root=/out install > /out/install.log 2>&1
    printf '%s\n' "$digest" > /out/build.complete
fi
library=/out/runtime/lib
loader="$library/ld-linux-aarch64.so.1"
[[ -x "$loader" && -e "$library/libc.so.6" ]]
"$loader" --library-path "$library" "$library/libc.so.6" > /out/libc-version.txt
grep -F "release version $version" /out/libc-version.txt

# glibc 2.17's elf/rtld.c maps a directly invoked ET_DYN program as a library.
# elf/dl-init.c then runs its constructors before __libc_csu_init repeats them.
# Execute via the kernel's original PT_INTERP in an isolated matching root.
mkdir -p /rootfs/runtime/lib /rootfs/binaries /rootfs/tmp
cp -a "$library"/*.so* /rootfs/runtime/lib/
ln -s runtime/lib /rootfs/lib
cp /binaries/main /binaries/glibc_runtime_pie /binaries/glibc_runtime_nopie /rootfs/binaries/

for kind in main glibc_runtime_pie glibc_runtime_nopie; do
    expected=$(awk -F '\t' -v v="$version" -v k="$kind" \
        '$1 == "aarch64" && $2 == v && $3 == k { print $4 }' /artifacts.tsv)
    [[ -n "$expected" ]]
    printf '%s  /binaries/%s\n' "$expected" "$kind" | sha256sum --check
    chroot /rootfs /runtime/lib/ld-linux-aarch64.so.1 --library-path /runtime/lib \
        --list "/binaries/$kind" > "/out/$kind.libraries.txt"
    # Every shared library must come from the matching installed runtime.
    awk '/=>/ && $3 !~ /^\/runtime\/lib\// { print; bad=1 } END { exit bad }' \
        "/out/$kind.libraries.txt"
    chroot /rootfs "/binaries/$kind" > "/out/$kind.normal.txt"
    if [[ "$kind" == main ]]; then
        printf 'Hello, World!\n' > /out/normal.expected
    else
        printf 'constructor\nglibc=%s\nruntime_ok\nmain_tls_destructor\natexit\ndestructor\n' \
            "$version" > /out/normal.expected
    fi
    diff -u /out/normal.expected "/out/$kind.normal.txt"
    if [[ "$kind" != main ]]; then
        chroot /rootfs "/binaries/$kind" quick > "/out/$kind.quick.txt"
        printf 'constructor\nglibc=%s\nquick_exit\n' "$version" > /out/quick.expected
        diff -u /out/quick.expected "/out/$kind.quick.txt"
    fi
done
printf '%s\tpass\n' "$version" > /out/result.tsv
