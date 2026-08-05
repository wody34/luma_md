# Luma MD Design System

## 0. Research Log

### Brief

Luma MD is a local-first Markdown reader for Android and macOS. The product should feel
as refined and focused as Obsidian without copying Obsidian's brand, icon, or screen
chrome. Opening a plain-text file must feel immediate, calm, and trustworthy on both
platforms.

### Sources

- **Official Obsidian mobile product page and Google Play listing:** retained the product
  principles of local Markdown files, offline access, quick actions, configurable reading,
  and outline navigation. No trademarked assets or pixel geometry are reused.
- **Frontend design-system architecture:** `DESIGN.md` is the visual contract and exists
  before product UI code.
- **Layout mechanics reference:** one viewport owns scrolling; top controls remain
  predictable; long, empty, and unbroken content must not escape the reader column.
- **Interaction mechanics reference:** controls visibly acknowledge state changes, motion
  communicates hierarchy, and reduced-motion users receive immediate transitions.
- **Aside reference:** harvested soft-squircle controls, quiet depth, precise borders, and
  product-like finish. Its bright marketing composition is intentionally not reused.
- **Designpowers:** accessibility constraints, cognitive load, accepted debt, and review
  criteria are explicit rather than implicit.
- **Unavailable lanes:** packaged minimalist/soft Layer A files, ui-ux-db script, and
  Lazyweb image capture were unavailable or unnecessary because the user named a concrete
  product direction. Two delegated research lanes were closed as inconclusive.

### Product-specific synthesis

The app uses an **amethyst reading room** metaphor: near-black violet surfaces, a single
luminous purple accent, book-like type rhythm, and a compact tool rail. It should feel
crafted and dimensional without looking glossy, gamified, or cyberpunk.

## 1. Brand and Product Principles

### Name

**Luma MD** — "Luma" suggests clarity and illumination; "MD" states the job.

### Promise

> Your Markdown, beautifully readable and always local.

### Principles

1. **The document is the hero.** Controls frame content; they never compete with it.
2. **Local is visible.** File name, type, and local status are shown in plain language.
3. **One tap to the next action.** Opening a file, changing theme, and resizing type are
   always reachable without a nested settings screen.
4. **Quiet depth, not flat rectangles.** Borders, restrained gradients, and layered
   surfaces establish hierarchy without ornamental cards everywhere.
5. **Original inspiration.** No Obsidian gem mark, vault terminology, purple shade,
   typography, or layout is copied exactly.

## 2. Color Tokens

### Dark theme — default

| Token | Value | Use |
|---|---:|---|
| `canvas` | `#0E0D13` | window and overscroll |
| `canvas-glow` | `#1B1530` | restrained top radial glow |
| `panel` | `#16141E` | reader shell |
| `surface` | `#1D1A27` | dock and metadata rows |
| `surface-raised` | `#252131` | pressed/selected controls |
| `border` | `#342E43` | structural separators |
| `border-soft` | `rgba(255,255,255,.075)` | quiet material edge |
| `text` | `#F4F1FA` | title and body |
| `text-secondary` | `#B8B2C5` | metadata |
| `text-tertiary` | `#817A8E` | labels and inactive icons |
| `accent` | `#A98AFB` | primary control and focus |
| `accent-strong` | `#8E63EE` | pressed accent |
| `accent-soft` | `rgba(169,138,251,.14)` | selected background |
| `success` | `#79D8B0` | completed task/local status |
| `code` | `#171522` | code block canvas |
| `shadow` | `rgba(0,0,0,.34)` | raised material |

### Light theme

| Token | Value | Use |
|---|---:|---|
| `canvas` | `#F3F0F7` | window |
| `canvas-glow` | `#E7DDF9` | restrained top glow |
| `panel` | `#FCFBFE` | reader shell |
| `surface` | `#F1EDF6` | dock and metadata rows |
| `surface-raised` | `#E9E2F2` | pressed/selected controls |
| `border` | `#DDD5E7` | structural separators |
| `border-soft` | `rgba(38,29,49,.08)` | quiet material edge |
| `text` | `#25212B` | title and body |
| `text-secondary` | `#625B6C` | metadata |
| `text-tertiary` | `#8A8193` | labels and inactive icons |
| `accent` | `#7650C8` | primary control and focus |
| `accent-strong` | `#5F38AE` | pressed accent |
| `accent-soft` | `rgba(118,80,200,.12)` | selected background |
| `success` | `#287A5D` | completed task/local status |
| `code` | `#F0ECF5` | code block canvas |
| `shadow` | `rgba(43,29,58,.12)` | raised material |

### Contrast rules

- Body copy is always `text` on `panel`.
- `text-tertiary` is never used below 12sp or for essential information.
- Accent is never the only indication of state; active controls also use shape/fill/label.
- Links are underlined on focus and use accent plus a trailing external-link glyph.

## 3. Typography

No network font is allowed. The stack must remain crisp and fully offline.

| Role | Stack | Size / line | Weight | Tracking |
|---|---|---|---:|---:|
| Brand | system sans | 15sp / 20sp | 700 | `-.01em` |
| Document H1 | `ui-serif, Georgia, serif` | 34sp / 40sp | 700 | `-.025em` |
| Document H2 | `ui-serif, Georgia, serif` | 25sp / 32sp | 700 | `-.018em` |
| Document H3 | system sans | 19sp / 26sp | 700 | `-.01em` |
| Body | system sans | 17sp / 29sp | 400 | `-.003em` |
| Metadata | system sans | 12sp / 17sp | 600 | `.045em` |
| Code | `ui-monospace, SFMono-Regular, Menlo, monospace` | 14sp / 23sp | 450 | `0` |
| Button | system sans | 14sp / 18sp | 700 | `0` |

Type controls apply `.92`, `1`, and `1.12` body-scale multipliers. Headings scale at
half that delta so large text remains balanced. Android caps body measure at 720px.
The macOS document/head/outline measure uses 45rem on compact and standard windows,
expands to 60rem from a 1200-point viewport, and reaches 68rem from 1600 points while
still yielding to page padding on narrower windows.

## 4. Spacing, Shape, and Material

### Spacing scale

`4, 8, 12, 16, 20, 24, 32, 40, 56, 72`

- Phone horizontal gutter: `18px`.
- Reader content inset: `24px` phone, `48px` tablet.
- Paragraph rhythm: `0 0 18px`.
- Section rhythm: `36px` before H2 and `26px` before H3.

### Radius

- Compact icon control: `12px`.
- Buttons and metadata: `14px`.
- Reader shell: `24px`.
- Welcome feature panel: `28px`.
- Pills: full radius, used only for status and file type.

### Depth

- Window: one radial amethyst glow at the top and a flat canvas below it.
- Reader: `1px` soft border plus `0 24px 70px shadow`; no glass blur.
- Controls: border and tonal fill; pressed state translates `1px` and darkens.
- Cards are reserved for the reader shell and welcome feature panel. List rows and
  metadata remain border-separated to avoid "dashboard card soup."

## 5. Components and Screens

### App mark

An original rounded-square "folded page" vector: two offset paper planes create an
abstract `L`. It uses accent and a subtle inner highlight. It is not a gemstone.

### Top bar

- Left: app mark, `Luma MD`, local status dot.
- Right: theme button and `Open` primary button.
- Height: 64px plus safe-area inset.
- On narrow screens, the word `Open` remains visible; brand status text may collapse.

### Welcome screen

1. Eyebrow: `LOCAL MARKDOWN READER`.
2. Headline: `Give every note a quiet place to land.`
3. Supporting copy: plain-text ownership and offline reading.
4. Primary action: `Open markdown`.
5. Feature panel: three short facts — local files, focused reading, safe links.
6. Recent-file affordance appears only when a persisted URI is available.
7. Bottom privacy note: `Nothing leaves your device.`

The welcome screen is not a fake dashboard and contains no meaningless statistics.

### Reader screen

1. Top bar.
2. Compact document header:
   - `LOCAL FILE` eyebrow.
   - document title derived from first H1 or filename.
   - filename, estimated reading time, and file size.
3. Semantic Markdown body inside one reader surface.
4. Floating bottom tool dock:
   - outline toggle,
   - type size cycle,
   - theme toggle,
   - open another file.
5. Outline sheet is an in-document panel, not a second scrolling viewport.

### Markdown primitives

- H1 has no decorative gradient text.
- Blockquote uses a 3px accent rail and soft accent fill.
- Inline code uses a tonal capsule; fenced code uses a labeled block with horizontal
  overflow.
- Inline and display math use semantic native MathML in Android WebView and macOS
  WKWebView. Fractions, indexed roots, limits, accents, fences, matrices, variants, and
  common paper notation retain mathematical structure and accessibility semantics.
  Unknown or malformed expressions fall back to escaped readable text. Styling remains
  local CSS with no script, package, font download, or network dependency.
- Task list checkboxes are custom CSS squares with a check glyph and strike-free completed
  copy.
- Tables scroll horizontally inside their own region, never widen the page.
- Horizontal rule is a subtle border with generous vertical space.
- Links show clear focus state and open external destinations outside the WebView.
- Images, when supported, fit the column and keep their intrinsic aspect ratio.

### Empty and error states

- Empty file title remains the filename.
- Centered quiet state: folded-page icon, `This file is empty`, and one sentence explaining
  that the file can be edited elsewhere and reopened.
- Oversized/unreadable files show an explicit error panel with `Open another file`.
- Raw exception messages are never shown.

## 6. Interaction and Motion

| Interaction | Response | Duration / curve |
|---|---|---|
| Button press | tonal fill + `translateY(1px)` | 90ms ease-out |
| Theme change | color/material cross-fade | 180ms ease-out |
| Type change | body scale transition, control label updates | 160ms ease-out |
| Outline open | panel fade + `translateY(8px→0)` | 180ms cubic-bezier(.2,.8,.2,1) |
| File loaded | reader opacity `0→1`, no movement | 160ms ease-out |
| Focus | 2px accent ring with 2px offset | immediate |

- No looping decorative motion.
- No layout-property animation.
- With `prefers-reduced-motion: reduce`, all transitions are disabled.
- On Android, custom URL schemes (`luma://open`, `luma://theme`, `luma://type`,
  `luma://outline`) communicate control intent without enabling JavaScript. macOS routes
  equivalent actions through native SwiftUI/AppKit controls.

## 7. Layout and Responsiveness

- `body` owns vertical scrolling. Nested vertical scroll areas are forbidden.
- The top bar is sticky; the bottom dock is fixed and accounts for gesture navigation.
- Reader bottom padding includes dock height plus `24px`.
- Long words and URLs use `overflow-wrap:anywhere`.
- Code and tables own horizontal overflow without widening the document.
- At 600px width, reader insets increase and the tool dock becomes a side rail.
- At 900px width, the Android outline may remain visible beside the document while its
  measure stays capped; the macOS reader expands at its wider viewport breakpoints.
- Empty content must not collapse the reader or push actions below the viewport.

## 8. Accessibility, QA, and Accepted Debt

### Accessibility contract

- Interactive targets are at least 48x48 CSS pixels.
- All icon-only controls have visible tooltips/titles and `aria-label`.
- Semantic headings preserve document outline.
- Focus order follows visual order.
- File status is text plus icon/shape, not color alone.
- Body copy meets WCAG AA contrast in both themes.
- Korean, Latin, and code glyphs must not clip at the large type setting.
- The app respects system dark mode on first launch and persists explicit overrides.

### Objective visual QA

Fresh API 36.1 emulator and signed macOS app evidence must show:

1. Welcome screen at 1080x2400 with no clipping, accidental double scroll, or inaccessible
   primary action.
2. Dark and light themes with visibly different canvas/panel/control tokens.
3. A real document containing headings, task list, blockquote, table, and code.
4. Large type with stable reader width, wrapped long text, and usable dock.
5. Empty state with a live app process and visible recovery action.
6. Semantic inline/block MathML with no raw delimiter capture, scripts, or remote resource.
7. macOS adaptive window chrome, adjustable reader width, outline, and security-scoped
   open/recovery behavior.

### Flatness and slop rejection

- Reject a screen that is only flat rectangles on a uniform background.
- Reject purple glow behind every section; one atmospheric glow is the maximum.
- Reject excessive pills, generic gradient headlines, fake usage metrics, decorative
  sparkles, emoji icons, and controls without a real action.
- Reject a reader whose toolbar attracts more attention than the document title.

### Accepted debt

- Both editions use hardened web views for semantic typography rather than duplicating a
  partial native Markdown layout engine. TalkBack and VoiceOver smoke tests are required;
  full external accessibility-service certification remains outside local release QA.
- Relative image resolution is deferred because persistable document-tree access differs
  from single-file access. The reader safely renders Markdown text without requesting
  broad storage permission.
