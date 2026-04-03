#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
STANDALONE_CMAKE_DIR="$SCRIPT_DIR"
BUILD_DIR="${1:-$SCRIPT_DIR/.build-linux-host}"
BUILD_CONFIG="${BUILD_CONFIG:-Release}"
RUNTIME_ROOT="$PROJECT_DIR/tools/pjarczak_bambu_linux_host/runtime/linux-x86_64"
RUNTIME_LIB_DIR="$RUNTIME_ROOT/pjarczak_bambu_linux_host.runtime"

purge_incompatible_cache() {
    if [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]]; then
        return 0
    fi

    local cache_source=""
    cache_source="$(sed -n 's/^CMAKE_HOME_DIRECTORY:INTERNAL=//p' "$BUILD_DIR/CMakeCache.txt" | head -n 1 || true)"
    if [[ -n "$cache_source" && "$cache_source" != "$STANDALONE_CMAKE_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
}

find_host_bin() {
    if [[ -d "$BUILD_DIR" ]]; then
        find "$BUILD_DIR" -type f -name pjarczak_bambu_linux_host | head -n 1
    fi
}

configure_and_build() {
    purge_incompatible_cache
    mkdir -p "$BUILD_DIR"
    cmake -S "$STANDALONE_CMAKE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE="$BUILD_CONFIG"
    cmake --build "$BUILD_DIR" --target pjarczak_bambu_linux_host -j"${CMAKE_BUILD_PARALLEL_LEVEL:-$(nproc)}"
}

copy_runtime_libs() {
    local host_bin="$1"
    mkdir -p "$RUNTIME_LIB_DIR"

    mapfile -t libs < <(
        ldd "$host_bin" | awk '
            /=>/ && $3 ~ /^\// { print $3 }
            /^\// { print $1 }
        ' | sort -u
    )

    for lib in "${libs[@]}"; do
        local base
        base="$(basename -- "$lib")"
        case "$base" in
            ld-linux*|libc.so.*|libm.so.*|libpthread.so.*|librt.so.*|libdl.so.*|libresolv.so.*|libnsl.so.*|libutil.so.*|libgcc_s.so.*)
                continue
                ;;
        esac
        cp -Lf "$lib" "$RUNTIME_LIB_DIR/"
    done
}

if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "this packaging script currently produces linux-x86_64 runtime only" >&2
    exit 1
fi

HOST_BIN="$(find_host_bin || true)"
if [[ -z "$HOST_BIN" ]]; then
    configure_and_build
    HOST_BIN="$(find_host_bin || true)"
fi

if [[ -z "$HOST_BIN" || ! -f "$HOST_BIN" ]]; then
    echo "failed to build/find pjarczak_bambu_linux_host in $BUILD_DIR" >&2
    exit 1
fi

rm -rf "$RUNTIME_ROOT"
mkdir -p "$RUNTIME_ROOT" "$RUNTIME_LIB_DIR"

cp -f "$HOST_BIN" "$RUNTIME_ROOT/pjarczak_bambu_linux_host"
chmod +x "$RUNTIME_ROOT/pjarczak_bambu_linux_host"

copy_runtime_libs "$HOST_BIN"

echo "linux host runtime packaged into:"
echo "  $RUNTIME_ROOT"
