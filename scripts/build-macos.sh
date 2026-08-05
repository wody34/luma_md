#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/macos"
MODE="${1:-release}"

case "$MODE" in
    debug|release) ;;
    *)
        printf 'Usage: %s [debug|release]\n' "$0" >&2
        exit 64
        ;;
esac

for tool in swift codesign plutil iconutil ditto shasum open lipo; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required tool is unavailable: %s\n' "$tool" >&2
        exit 69
    fi
done

SWIFT_FLAGS=()
if [[ "${LUMA_MD_INCLUDE_QA:-0}" == "1" ]]; then
    SWIFT_FLAGS=(-Xswiftc -DLUMA_MD_QA)
fi

swift build \
    --package-path "$PACKAGE" \
    --configuration "$MODE" \
    --product LumaMD \
    "${SWIFT_FLAGS[@]}"

BIN_DIR="$(swift build \
    --package-path "$PACKAGE" \
    --configuration "$MODE" \
    --show-bin-path \
    "${SWIFT_FLAGS[@]}")"
BINARY="$BIN_DIR/LumaMD"
APP="$PACKAGE/build/$MODE/Luma MD.app"
CONTENTS="$APP/Contents"
ICONSET="$PACKAGE/build/$MODE/AppIcon.iconset"

test -x "$BINARY"
rm -rf "$APP" "$ICONSET"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$PACKAGE/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$BINARY" "$CONTENTS/MacOS/LumaMD"
chmod 755 "$CONTENTS/MacOS/LumaMD"

swift "$PACKAGE/Tools/AppIconGenerator.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$ICONSET"

plutil -lint "$CONTENTS/Info.plist" >/dev/null
[[ "$(plutil -extract CFBundleIdentifier raw "$CONTENTS/Info.plist")" == \
    "dev.lumamd.viewer.macos" ]]
[[ "$(plutil -extract CFBundleExecutable raw "$CONTENTS/Info.plist")" == "LumaMD" ]]
[[ "$(plutil -extract LSMinimumSystemVersion raw "$CONTENTS/Info.plist")" == "13.0" ]]
test -x "$CONTENTS/MacOS/LumaMD"
codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$PACKAGE/Resources/LumaMD.entitlements" \
    --sign - \
    "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

SOURCE_ENTITLEMENTS="$(plutil -convert json -o - "$PACKAGE/Resources/LumaMD.entitlements")"
SIGNED_ENTITLEMENTS="$(codesign -d --entitlements :- "$APP" 2>/dev/null \
    | plutil -convert json -o - -)"
[[ "$SIGNED_ENTITLEMENTS" == "$SOURCE_ENTITLEMENTS" ]]

VERSION="$(plutil -extract CFBundleShortVersionString raw "$CONTENTS/Info.plist")"
ARCHITECTURE="$(lipo -archs "$CONTENTS/MacOS/LumaMD")"
ARCHIVE="$PACKAGE/build/$MODE/Luma-MD-macOS-v$VERSION-$ARCHITECTURE.zip"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"
(
    cd "$(dirname "$ARCHIVE")"
    shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
)

printf 'Built signed macOS app: %s\n' "$APP"
printf 'Packaged macOS release: %s\n' "$ARCHIVE"
