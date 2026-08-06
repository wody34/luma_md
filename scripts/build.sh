#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-debug}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
BUILD_TOOLS_VERSION="${BUILD_TOOLS_VERSION:-36.1.0}"
PLATFORM_VERSION="${PLATFORM_VERSION:-android-36}"

BUILD_TOOLS="$ANDROID_HOME/build-tools/$BUILD_TOOLS_VERSION"
ANDROID_JAR="$ANDROID_HOME/platforms/$PLATFORM_VERSION/android.jar"
SHASUM="$(command -v shasum || true)"
SOURCE_ROOT="$ROOT/app/src/main"
BUILD_DIR="$ROOT/app/build"
INTERMEDIATES="$BUILD_DIR/intermediates"
OUTPUT_DIR="$BUILD_DIR/outputs/apk/$MODE"
GENERATED="$INTERMEDIATES/generated"
CLASSES="$INTERMEDIATES/classes"
DEX="$INTERMEDIATES/dex"
COMPILED_RES="$INTERMEDIATES/resources.zip"
RESOURCE_APK="$INTERMEDIATES/resources.apk"
DEX_APK="$INTERMEDIATES/with-dex.apk"
ALIGNED_APK="$INTERMEDIATES/aligned.apk"
FINAL_APK="$OUTPUT_DIR/luma-md-$MODE.apk"
SOURCE_LIST="$INTERMEDIATES/sources.list"

case "$MODE" in
    debug|release) ;;
    *)
        printf 'Usage: %s [debug|release]\n' "$0" >&2
        exit 64
        ;;
esac

for command in "$JAVA_HOME/bin/javac" "$JAVA_HOME/bin/keytool" \
    "$BUILD_TOOLS/aapt2" "$BUILD_TOOLS/d8" "$BUILD_TOOLS/zipalign" \
    "$BUILD_TOOLS/apksigner" "$SHASUM"; do
    if [[ ! -x "$command" ]]; then
        printf 'Missing build command: %s\n' "$command" >&2
        exit 1
    fi
done

if [[ ! -f "$ANDROID_JAR" ]]; then
    printf 'Missing Android platform: %s\n' "$ANDROID_JAR" >&2
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$GENERATED" "$CLASSES" "$DEX" "$OUTPUT_DIR"

"$BUILD_TOOLS/aapt2" compile \
    --dir "$SOURCE_ROOT/res" \
    -o "$COMPILED_RES"

"$BUILD_TOOLS/aapt2" link \
    -o "$RESOURCE_APK" \
    -I "$ANDROID_JAR" \
    --manifest "$SOURCE_ROOT/AndroidManifest.xml" \
    --java "$GENERATED" \
    --min-sdk-version 26 \
    --target-sdk-version 36 \
    --version-code 2 \
    --version-name 1.0.1 \
    --auto-add-overlay \
    "$COMPILED_RES"

find "$SOURCE_ROOT/java" "$GENERATED" -name '*.java' -type f | sort > "$SOURCE_LIST"
if [[ ! -s "$SOURCE_LIST" ]]; then
    printf 'No Java sources found.\n' >&2
    exit 1
fi

"$JAVA_HOME/bin/javac" \
    -encoding UTF-8 \
    -source 8 \
    -target 8 \
    -Xlint:all,-options \
    -bootclasspath "$ANDROID_JAR" \
    -d "$CLASSES" \
    @"$SOURCE_LIST"

find "$CLASSES" -name '*.class' -type f | sort > "$INTERMEDIATES/classes.list"
D8_MODE=()
if [[ "$MODE" == "release" ]]; then
    D8_MODE=(--release)
fi
"$BUILD_TOOLS/d8" \
    "${D8_MODE[@]}" \
    --lib "$ANDROID_JAR" \
    --min-api 26 \
    --output "$DEX" \
    @"$INTERMEDIATES/classes.list"

cp "$RESOURCE_APK" "$DEX_APK"
(
    cd "$DEX"
    zip -q -u "$DEX_APK" classes.dex
)

"$BUILD_TOOLS/zipalign" -f -p 4 "$DEX_APK" "$ALIGNED_APK"

if [[ "$MODE" == "release" ]]; then
    for variable in LUMA_KEYSTORE LUMA_KEY_ALIAS LUMA_STORE_PASSWORD LUMA_KEY_PASSWORD; do
        if [[ -z "${!variable:-}" ]]; then
            printf 'Release signing requires %s.\n' "$variable" >&2
            exit 78
        fi
    done
    KEYSTORE="$LUMA_KEYSTORE"
    KEY_ALIAS="$LUMA_KEY_ALIAS"
    STORE_PASSWORD="$LUMA_STORE_PASSWORD"
    KEY_PASSWORD="$LUMA_KEY_PASSWORD"
    if [[ ! -f "$KEYSTORE" ]]; then
        printf 'Release keystore does not exist: %s\n' "$KEYSTORE" >&2
        exit 66
    fi
    if [[ -n "$(find "$KEYSTORE" -prune -perm -077 -print -quit)" ]]; then
        printf 'Release keystore must not be readable or writable by group/other users.\n' >&2
        exit 77
    fi
else
    KEYSTORE="${LUMA_KEYSTORE:-$ROOT/.local/signing/luma-development.jks}"
    KEY_ALIAS="${LUMA_KEY_ALIAS:-luma-development}"
    STORE_PASSWORD="${LUMA_STORE_PASSWORD:-android}"
    KEY_PASSWORD="${LUMA_KEY_PASSWORD:-android}"
fi

if [[ "$MODE" == "debug" && ! -f "$KEYSTORE" ]]; then
    umask 077
    mkdir -p "$(dirname "$KEYSTORE")"
    "$JAVA_HOME/bin/keytool" -genkeypair \
        -keystore "$KEYSTORE" \
        -storepass "$STORE_PASSWORD" \
        -keypass "$KEY_PASSWORD" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=Luma MD Development,O=Luma MD,C=KR" \
        -noprompt >/dev/null
fi
if [[ "$MODE" == "debug" ]]; then
    chmod 600 "$KEYSTORE"
fi

"$BUILD_TOOLS/apksigner" sign \
    --ks "$KEYSTORE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass "pass:$STORE_PASSWORD" \
    --key-pass "pass:$KEY_PASSWORD" \
    --out "$FINAL_APK" \
    "$ALIGNED_APK"

"$BUILD_TOOLS/apksigner" verify --verbose "$FINAL_APK" >/dev/null
(
    cd "$OUTPUT_DIR"
    "$SHASUM" -a 256 "$(basename "$FINAL_APK")" > "$(basename "$FINAL_APK").sha256"
)
printf 'Built signed APK: %s\n' "$FINAL_APK"
printf 'Wrote Android checksum: %s\n' "$FINAL_APK.sha256"
