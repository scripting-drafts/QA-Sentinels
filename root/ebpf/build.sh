#!/usr/bin/env bash
# Build the layer-2 eBPF tracer.
#
# Preferred: system clang + libbpf-dev.
# Fallback: the user-local toolchain created by bootstrap-ebpf.sh (no root).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/root/ebpf"
TC="${QA_EBPF_TOOLCHAIN:-$ROOT/toolchain}"

if command -v clang >/dev/null 2>&1 && [[ -f /usr/include/bpf/libbpf.h ]]; then
  CLANG="$(command -v clang)"
  BPF_INC="-I/usr/include"
  LDLIBS="-lbpf -lelf -lz -lpthread"
elif [[ -x "$TC/usr/lib/llvm-14/bin/clang" ]]; then
  CLANG="$TC/usr/lib/llvm-14/bin/clang"
  TC_LIB="$TC/usr/lib/x86_64-linux-gnu"
  export LD_LIBRARY_PATH="$TC_LIB:$TC/usr/lib/llvm-14/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  BPF_INC="-I$TC/usr/include"
  # libbpf-dev ships headers and a libbpf.so symlink; the libbpf.so.0 object
  # lives in libbpf0. Prefer the static archive, then the toolchain shared
  # library, then the host runtime library.
  if [[ -f "$TC_LIB/libbpf.a" ]]; then
    LDLIBS="$TC_LIB/libbpf.a -lelf -lz -lpthread"
  elif [[ -e "$TC_LIB/libbpf.so.0" ]]; then
    LDLIBS="-L$TC_LIB -Wl,-rpath,$TC_LIB -lbpf -lelf -lz -lpthread"
  elif [[ -e /usr/lib/x86_64-linux-gnu/libbpf.so.0 ]]; then
    LDLIBS="/usr/lib/x86_64-linux-gnu/libbpf.so.0 -lelf -lz -lpthread"
  else
    echo "libbpf runtime library not found. run: $ROOT/root/ebpf/bootstrap-ebpf.sh" >&2
    exit 1
  fi
else
  echo "no clang/libbpf found. run: $ROOT/root/ebpf/bootstrap-ebpf.sh" >&2
  exit 1
fi

if ! command -v bpftool >/dev/null 2>&1; then
  echo "bpftool is required to generate vmlinux.h" >&2
  exit 1
fi

cd "$HERE"
echo "generating vmlinux.h from /sys/kernel/btf/vmlinux"
bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h

echo "building qa_trace.bpf.o with $CLANG"
"$CLANG" -target bpf -D__TARGET_ARCH_x86 -O2 -g $BPF_INC -I. \
  -c qa_trace.bpf.c -o qa_trace.bpf.o

echo "building loader"
gcc -O2 -Wall -Wextra $BPF_INC -I. -o qa_ebpf qa_trace.c $LDLIBS

mkdir -p "$ROOT/bin"
install -m 0755 qa_ebpf "$ROOT/bin/qa_ebpf"
install -m 0644 qa_trace.bpf.o "$ROOT/bin/qa_trace.bpf.o"
STAMP="$ROOT/bin/qa_ebpf.build.json"
printf '{\n  "kernel_release": "%s",\n  "built_at": "%s",\n  "binary_sha256": "%s",\n  "object_sha256": "%s"\n}\n' \
  "$(uname -r)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "$(sha256sum "$ROOT/bin/qa_ebpf" | awk '{print $1}')" \
  "$(sha256sum "$ROOT/bin/qa_trace.bpf.o" | awk '{print $1}')" >"$STAMP"
echo "installed: $ROOT/bin/qa_ebpf and $ROOT/bin/qa_trace.bpf.o"
echo "stamp: $STAMP"
echo "test without privileges (should fail cleanly): $ROOT/bin/qa_ebpf --duration 1"
