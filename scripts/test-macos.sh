#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

swift test \
    --package-path "$ROOT/macos" \
    "$@"

swift run \
    --package-path "$ROOT/macos" \
    LumaMDCoreTestRunner

swift run \
    --package-path "$ROOT/macos" \
    LumaMDMacTestRunner

swift build \
    --package-path "$ROOT/macos" \
    --product LumaMD \
    -Xswiftc -warnings-as-errors
