#!/usr/bin/env bash
#
# convert_dxf_to_glb.sh -- helper script to convert DXF files to glb
#
# This script uses the Assimp command‑line tool to convert one or more
# DXF files to the glTF binary format (.glb).  Assimp is not
# distributed with this repository; you must install it on your
# system.  See https://github.com/assimp/assimp for installation
# instructions.

if ! command -v assimp >/dev/null 2>&1; then
    echo "Error: assimp command not found. Please install the Assimp CLI." >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file1.dxf> [file2.dxf ...]"
    exit 1
fi

for file in "$@"; do
    if [ ! -f "$file" ]; then
        echo "Warning: '$file' does not exist or is not a file. Skipping." >&2
        continue
    fi
    base="$(basename "$file" .dxf)"
    out="${base}.glb"
    echo "Converting $file -> $out"
    assimp export "$file" "$out" || {
        echo "Error converting $file" >&2
    }
done