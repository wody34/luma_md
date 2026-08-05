# Luma MD 1.0.0

First public release of the local-first Markdown reader for Android and macOS.

## Highlights

- Offline Markdown reading for `.md`, `.markdown`, `.mdown`, `.mkd`, `.mdx`, and text
- Semantic MathML formulas with fractions, roots, limits, accents, fences, matrices,
  common paper notation, bounded parsing, and escaped fallback
- Outline navigation, syntax-highlighted fenced code, tables, task lists, footnotes,
  safe links, themes, type scales, source copy, clipboard memos, and native sharing
- Android secure document picker and persisted URI access
- macOS security-scoped read-only files, one recent bookmark, adjustable reader width,
  adaptive borderless window, keyboard access, and Finder Open With support
- No runtime package, network, account, analytics, or JavaScript dependency

## Assets

- `luma-md-release.apk`: Android 8.0+ signed APK
- `luma-md-release.apk.sha256`: Android SHA-256 checksum
- `Luma-MD-macOS-v1.0.0-arm64.zip`: macOS 13+ Apple Silicon app archive
- `Luma-MD-macOS-v1.0.0-arm64.zip.sha256`: macOS SHA-256 checksum

## Signing and installation

The Android APK uses the protected Luma MD release certificate:

```text
CN=Luma MD Release, O=Luma MD, C=KR
SHA-256: 6a13e9f55b587b5872f006ff48d7b233057b2a43408376ee8902e9feb2572593
```

The macOS app is sandboxed, hardened-runtime enabled, ad-hoc signed, and not notarized
because this build environment has no Developer ID identity. Verify the checksum first.
Gatekeeper may require **Open** from Finder's context menu, or removal of quarantine:

```bash
xattr -dr com.apple.quarantine "/Applications/Luma MD.app"
```

The macOS asset is `arm64` only. Intel and universal builds are not included.

## Privacy boundary

Both editions block scripts and remote subresources. Android requests no permissions.
macOS ships App Sandbox, user-selected read-only file, app-scoped bookmark entitlements,
and the narrow `com.apple.nsurlsessiond` Mach lookup exception required to bootstrap
sandboxed WebKit; it has no network client/server entitlement. Relative and remote images
are intentionally not loaded.
