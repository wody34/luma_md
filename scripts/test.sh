#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
BUILD_DIR="$ROOT/app/build/test"
SOURCE_LIST="$BUILD_DIR/sources.list"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/classes"

find \
    "$ROOT/app/src/main/java/dev/lumamd/viewer/core" \
    "$ROOT/app/src/test/java" \
    -name '*.java' -type f | sort > "$SOURCE_LIST"

"$JAVA_HOME/bin/javac" \
    -encoding UTF-8 \
    -source 8 \
    -target 8 \
    -Xlint:all,-options \
    -d "$BUILD_DIR/classes" \
    @"$SOURCE_LIST"

SCOPE="${1:-all}"
case "$SCOPE" in
    core|edge|math|highlight|footnote)
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.MarkdownRendererTest "$SCOPE"
        ;;
    layout)
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.AppPageBuilderTest "$SCOPE"
        ;;
    actions)
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.ReaderActionsTest
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.WebNavigationPolicyTest
        ;;
    share)
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.ShareContractTest
        ;;
    manifest)
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.AndroidManifestTest
        ;;
    all)
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.MarkdownRendererTest all
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.AppPageBuilderTest
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.AndroidManifestTest
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.SafeAreaInsetsTest
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.ReaderActionsTest
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.WebNavigationPolicyTest
        "$JAVA_HOME/bin/java" -ea -cp "$BUILD_DIR/classes" \
            dev.lumamd.viewer.core.ShareContractTest
        ;;
    *)
        printf 'Unknown test scope: %s\n' "$SCOPE" >&2
        exit 2
        ;;
esac

printf '%s contract tests passed.\n' "$SCOPE"
