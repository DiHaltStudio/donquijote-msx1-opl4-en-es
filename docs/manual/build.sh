#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$root"
mkdir -p build
for lang in es en; do
    "${TECTONIC:-tectonic}" --keep-logs --outdir build "manual-$lang.tex" > "build/tectonic-$lang.txt" 2>&1
    cp "build/manual-$lang.pdf" "manual-$lang.pdf"
done
