#!/usr/bin/env bash
set -Eeuo pipefail

target="${1:-/restore}"
mkdir -p "${target}"

restic restore latest --target "${target}"

echo "Latest snapshot restored into ${target}."
echo "Dump files:"
find "${target}" -type f -name "*.dump" -print
