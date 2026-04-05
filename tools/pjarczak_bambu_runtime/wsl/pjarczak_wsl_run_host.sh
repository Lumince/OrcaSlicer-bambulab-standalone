#!/bin/sh
set -eu

MODE="run"
if [ "${1:-}" = "--probe" ]; then
    MODE="probe"
    shift
fi

PACKAGE_DIR="${1:-${PJARCZAK_BAMBU_WINDOWS_PLUGIN_DIR:-}}"
PLUGIN_CACHE_DIR="${2:-${PJARCZAK_BAMBU_WINDOWS_PLUGIN_CACHE_DIR:-}}"
if [ -z "$PACKAGE_DIR" ]; then
    echo "missing Windows package directory path" >&2
    exit 127
fi

PACKAGE_RUNTIME_DIR="$PACKAGE_DIR/pjarczak_bambu_linux_host.runtime"

find_first_existing() {
    for path in "$@"; do
        if [ -n "$path" ] && [ -f "$path" ]; then
            printf '%s\n' "$path"
            return 0
        fi
    done
    return 1
}

HOST_SRC="$(find_first_existing \
    "$PACKAGE_DIR/pjarczak_bambu_linux_host" \
    "$PACKAGE_RUNTIME_DIR/pjarczak_bambu_linux_host" || true)"
if [ -z "$HOST_SRC" ]; then
    echo "missing runtime file: pjarczak_bambu_linux_host" >&2
    exit 127
fi

find_payload_file() {
    local name="$1"
    if [ -f "$PACKAGE_DIR/$name" ]; then
        printf '%s\n' "$PACKAGE_DIR/$name"
        return 0
    fi
    if [ -f "$PACKAGE_RUNTIME_DIR/$name" ]; then
        printf '%s\n' "$PACKAGE_RUNTIME_DIR/$name"
        return 0
    fi
    if [ -n "$PLUGIN_CACHE_DIR" ] && [ -f "$PLUGIN_CACHE_DIR/$name" ]; then
        printf '%s\n' "$PLUGIN_CACHE_DIR/$name"
        return 0
    fi
    return 1
}

NETWORK_SRC="$(find_payload_file libbambu_networking.so || true)"
SOURCE_SRC="$(find_payload_file libBambuSource.so || true)"
LIVE555_SRC="$(find_payload_file liblive555.so || true)"
MANIFEST_SRC="$(find_payload_file linux_payload_manifest.json || true)"

if [ -z "$NETWORK_SRC" ] || [ -z "$SOURCE_SRC" ]; then
    echo "plugin_not_downloaded package_dir=$PACKAGE_DIR plugin_cache_dir=${PLUGIN_CACHE_DIR:-none}" >&2
    if [ "$MODE" = "probe" ]; then
        exit 3
    fi
    exit 127
fi

if ! command -v sha256sum >/dev/null 2>&1; then
    echo "sha256sum not found inside WSL distro" >&2
    exit 127
fi

RUNTIME_BASE="${PJARCZAK_BAMBU_WSL_RUNTIME_DIR:-/root/.pjarczak-bambu-runtime}"
mkdir -p "$RUNTIME_BASE"

RUNTIME_HASH="$({
    sha256sum "$HOST_SRC" "$NETWORK_SRC" "$SOURCE_SRC"
    [ -n "$LIVE555_SRC" ] && sha256sum "$LIVE555_SRC"
    [ -n "$MANIFEST_SRC" ] && sha256sum "$MANIFEST_SRC"
} | sha256sum | cut -d ' ' -f1)"
TARGET_DIR="$RUNTIME_BASE/$RUNTIME_HASH"
CURRENT_DIR="$RUNTIME_BASE/current"

copy_payload_dir() {
    local src_dir="$1"
    local dst_dir="$2"
    [ -d "$src_dir" ] || return 0

    for path in "$src_dir"/*; do
        [ -f "$path" ] || continue
        base="$(basename "$path")"
        case "$base" in
            pjarczak_bambu_linux_host|libbambu_networking.so|libBambuSource.so|liblive555.so|linux_payload_manifest.json)
                continue
                ;;
            *.dll|*.ps1|*.txt|*.tar|*.zip|*.cmd|*.bat|*.sh)
                continue
                ;;
        esac
        cp "$path" "$dst_dir/$base"
    done
}

if [ ! -d "$TARGET_DIR" ]; then
    TMP_DIR="$RUNTIME_BASE/.tmp-$RUNTIME_HASH-$$"
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    cp "$HOST_SRC" "$TMP_DIR/pjarczak_bambu_linux_host"
    cp "$NETWORK_SRC" "$TMP_DIR/libbambu_networking.so"
    cp "$SOURCE_SRC" "$TMP_DIR/libBambuSource.so"
    if [ -n "$LIVE555_SRC" ]; then
        cp "$LIVE555_SRC" "$TMP_DIR/liblive555.so"
    fi
    if [ -n "$MANIFEST_SRC" ]; then
        cp "$MANIFEST_SRC" "$TMP_DIR/linux_payload_manifest.json"
    fi

    copy_payload_dir "$PACKAGE_RUNTIME_DIR" "$TMP_DIR"
    copy_payload_dir "$PACKAGE_DIR" "$TMP_DIR"

    chmod 755 "$TMP_DIR/pjarczak_bambu_linux_host"
    mv "$TMP_DIR" "$TARGET_DIR"
fi

rm -rf "$CURRENT_DIR"
ln -s "$TARGET_DIR" "$CURRENT_DIR"

export PJARCZAK_BAMBU_PLUGIN_DIR="$CURRENT_DIR"
export PJARCZAK_BAMBU_NETWORK_SO="$CURRENT_DIR/libbambu_networking.so"
export PJARCZAK_BAMBU_SOURCE_SO="$CURRENT_DIR/libBambuSource.so"
if [ -f "$CURRENT_DIR/liblive555.so" ]; then
    export PJARCZAK_BAMBU_LIVE555_SO="$CURRENT_DIR/liblive555.so"
fi
export LD_LIBRARY_PATH="$CURRENT_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ "$MODE" = "probe" ]; then
    if ! ldd "$CURRENT_DIR/pjarczak_bambu_linux_host" >/tmp/pjarczak-ldd.txt 2>&1; then
        cat /tmp/pjarczak-ldd.txt >&2 || true
        exit 127
    fi
    if grep -q 'not found' /tmp/pjarczak-ldd.txt; then
        cat /tmp/pjarczak-ldd.txt >&2
        exit 127
    fi
    echo "probe_ok runtime_dir=$CURRENT_DIR runtime_hash=$RUNTIME_HASH"
    exit 0
fi

exec "$CURRENT_DIR/pjarczak_bambu_linux_host"
