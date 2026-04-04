#!/bin/sh
set -eu

HOST="${1:-${PJARCZAK_WSL_HOST_PATH:-/opt/pjarczak/bin/pjarczak_bambu_linux_host}}"
RUNTIME_DIR="${2:-${PJARCZAK_WSL_RUNTIME_DIR:-/opt/pjarczak/runtime}}"
PLUGIN_DIR="${PJARCZAK_BAMBU_PLUGIN_DIR:-}"

if [ -z "${PJARCZAK_BAMBU_NETWORK_SO:-}" ] && [ -n "$PLUGIN_DIR" ]; then
    export PJARCZAK_BAMBU_NETWORK_SO="$PLUGIN_DIR/libbambu_networking.so"
fi
if [ -z "${PJARCZAK_BAMBU_SOURCE_SO:-}" ] && [ -n "$PLUGIN_DIR" ]; then
    export PJARCZAK_BAMBU_SOURCE_SO="$PLUGIN_DIR/libBambuSource.so"
fi
if [ -z "${PJARCZAK_BAMBU_LIVE555_SO:-}" ] && [ -n "$PLUGIN_DIR" ]; then
    export PJARCZAK_BAMBU_LIVE555_SO="$PLUGIN_DIR/liblive555.so"
fi

LIB_DIR="$RUNTIME_DIR"
if [ -n "${PJARCZAK_BAMBU_NETWORK_SO:-}" ]; then
    LIB_DIR="$(dirname "$PJARCZAK_BAMBU_NETWORK_SO")"
fi

export LD_LIBRARY_PATH="$LIB_DIR:$RUNTIME_DIR${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
[ -x "$HOST" ] || chmod +x "$HOST" || true
exec "$HOST"
