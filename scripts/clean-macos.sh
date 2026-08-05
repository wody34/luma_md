#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf \
    "$ROOT/macos/.build" \
    "$ROOT/macos/.swiftpm" \
    "$ROOT/macos/build"

printf 'Removed macOS derived products.\n'
