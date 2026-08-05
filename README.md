# Luma MD

Luma MD is a focused, local-first Markdown reader for Android and macOS. Both editions
open user-selected Markdown files, render them in a hardened offline reading surface,
and retain the original source for local copy and share actions.

## What it supports

- `.md`, `.markdown`, `.mdown`, `.mkd`, `.mdx`, and plain-text files
- Headings and an on-page outline
- Bold, emphasis, strikethrough, and inline code
- Ordered, unordered, and task lists
- Blockquotes, fenced code, tables, horizontal rules, and safe external links
- Semantic offline MathML for inline/block formulas, including fractions, indexed roots,
  limits, accents, fences, matrices, common paper notation, and safe readable fallback
- Syntax highlighting for Kotlin/Java, JavaScript/TypeScript, Python, Bash, JSON,
  XML/HTML/SVG, CSS, and Markdown
- Linked `[^key]` footnotes with repeated references and return arrows
- Copy the original Markdown source to the system clipboard
- Create a temporary rendered memo from clipboard text
- Share the current note through the platform share service
- Dark and light reading themes
- Three text-size presets
- A responsive long-form reading column with adjustable width on macOS
- Platform-adapted outline, reader actions, keyboard, and window controls
- Empty and malformed-file recovery states
- One persisted recent document through Android URI permission or a macOS scoped bookmark
- Escaped HTML and an allowlist for `http`, `https`, `mailto`, and in-page links

The app is dependency-free at runtime. Markdown parsing and the UI shell are implemented
locally, so reading works offline.

Remote and relative images are intentionally not loaded: both editions deny remote
subresources and request access only to the selected Markdown file.

## Android requirements

- macOS or Linux shell with `zip`
- JDK 17
- Android SDK platform 36
- Android build-tools 36.1.0

The default macOS paths are:

```text
JAVA_HOME=/opt/homebrew/opt/openjdk@17
ANDROID_HOME=$HOME/Library/Android/sdk
```

Install JDK 17 on macOS with:

```bash
brew install openjdk@17
```

## Test

```bash
JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./scripts/test.sh
```

The contract suite compiles the pure-Java renderer and page builder with all warnings
enabled, then verifies Markdown semantics, unsafe-link handling, empty/malformed content,
theme tokens, metadata, outline navigation, and reading controls.

## Build a signed APK

```bash
JAVA_HOME=/opt/homebrew/opt/openjdk@17 \
ANDROID_HOME="$HOME/Library/Android/sdk" \
./scripts/build.sh release
```

Output:

```text
app/build/outputs/apk/release/luma-md-release.apk
```

The build uses the installed SDK directly:

1. `aapt2` compiles and links resources.
2. `javac` compiles Java against `android-36/android.jar`.
3. `d8` creates `classes.dex`.
4. `zipalign` aligns the APK.
5. `apksigner` signs and verifies it.

No Gradle installation or network dependency resolution is required.

## Install

With a device or emulator connected:

```bash
"$ANDROID_HOME/platform-tools/adb" install -r \
  app/build/outputs/apk/release/luma-md-release.apk
```

Launch it:

```bash
"$ANDROID_HOME/platform-tools/adb" shell am start -W \
  -n dev.lumamd.viewer/.MainActivity
```

In Luma MD, tap **Open markdown** and choose a file. You can also choose **Open with →
Luma MD** from a compatible file manager.

## Signing

For local installation, the build creates a stable development identity at:

```text
.local/signing/luma-development.jks
```

That directory and all keystores are ignored by Git. Keep the generated keystore if you
want later `adb install -r` builds to upgrade the installed app.

Release mode refuses to build without an existing protected keystore and all four signing
variables. Provide them without putting secrets in the repository:

```bash
LUMA_KEYSTORE=/absolute/path/upload-key.jks \
LUMA_KEY_ALIAS=upload \
LUMA_STORE_PASSWORD='your-store-password' \
LUMA_KEY_PASSWORD='your-key-password' \
JAVA_HOME=/opt/homebrew/opt/openjdk@17 \
ANDROID_HOME="$HOME/Library/Android/sdk" \
./scripts/build.sh release
```

The keystore must be mode `0600`; the build never creates a release key or uses the
development passwords implicitly.

For Google Play, protect and back up the upload key. This repository produces the signed
APK requested here; Play Console projects that require an Android App Bundle can reuse the
same source and signing identity with an AAB-capable build pipeline.

## macOS edition

The macOS app uses Swift 6, SwiftUI, AppKit, and `WKWebView`. It keeps the same offline
Markdown and semantic MathML contract while adapting the outline, adjustable reader width,
keyboard access, window chrome, and security-scoped file handling to macOS.

### macOS requirements

- Runtime: macOS 13 or newer
- Build host: a macOS release that supports the installed Swift 6 toolchain
- Swift 6 toolchain
- Command Line Tools with `codesign`

### Test macOS

```bash
bash scripts/test-macos.sh
```

This runs the Core and macOS contract runners, then builds the app with Swift warnings
treated as errors.

### Build and run macOS

```bash
bash scripts/build-macos.sh release
open -n "macos/build/release/Luma MD.app"
```

The assembled artifact is:

```text
macos/build/release/Luma MD.app
```

The build verifies the ad-hoc signature and bundles App Sandbox, user-selected read-only
file access, app-scoped bookmark entitlements, and the narrow
`com.apple.nsurlsessiond` Mach lookup exception required to bootstrap sandboxed WebKit.
It contains no network client or server entitlement, and CSP still denies all connections
and remote subresources.

The default build targets the build host architecture. On Apple Silicon it produces an
`arm64` app, not a universal or Intel build. The GitHub artifact is ad-hoc signed and is
not Developer ID notarized because no Developer ID identity is available in this build
environment. Gatekeeper may therefore require **Open** from Finder's context menu, or:

```bash
xattr -dr com.apple.quarantine "/Applications/Luma MD.app"
```

Only remove quarantine after verifying the published SHA-256 checksum.

## Project layout

```text
DESIGN.md                         visual and interaction contract
app/src/main/AndroidManifest.xml  Android entry points and file intents
app/src/main/java/.../core/       Markdown and HTML shell, Android-free tests
app/src/main/java/.../            document loading and Activity wiring
app/src/main/res/                 icon, theme, strings, and colors
app/src/test/java/                executable behavior contracts
macos/Sources/LumaMDCore/         macOS Markdown and semantic MathML core
macos/Sources/LumaMDMac/          SwiftUI/AppKit/WKWebView application surface
macos/Tests/                      macOS Core and app contract tests
scripts/test.sh                   pure-Java test runner
scripts/build.sh                  direct-SDK signed APK pipeline
scripts/test-macos.sh             SwiftPM Core/app contract and warning gates
scripts/build-macos.sh            signed macOS bundle assembly
```

## License

Copyright (c) 2026 wody34. All rights reserved. See `LICENSE`.

## Privacy and permissions

Luma MD requests no internet, account, or analytics access. Android grants access only to
the file selected by the user or shared through an `ACTION_VIEW` intent. macOS uses App
Sandbox security-scoped read-only access, app-scoped bookmarks, and the documented WebKit
bootstrap Mach exception above. Neither app has a network permission/entitlement. Both web
surfaces block scripts and remote subresources; external safe links open in another app.
