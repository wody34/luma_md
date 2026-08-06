import SwiftUI

struct WelcomeView: View {
    let hasRecentDocument: Bool
    let openDocument: () -> Void
    let openRecent: () -> Void
    let pasteClipboard: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 650

            ZStack {
                DesignTokens.glow
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    brand
                    Spacer(minLength: compact ? 20 : 56)
                    hero(compact: compact)
                    Spacer(minLength: compact ? 20 : 44)
                    actions(compact: compact)
                    Spacer(minLength: compact ? 16 : 48)
                    privacy
                }
                .frame(
                    maxWidth: 920,
                    maxHeight: compact ? .infinity : 680,
                    alignment: .topLeading
                )
                .padding(.horizontal, compact ? 32 : 56)
                .padding(.vertical, compact ? 20 : 42)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome-screen")
    }

    private var brand: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(DesignTokens.accent, in: RoundedRectangle(cornerRadius: 12))
            Text("Luma MD")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Luma MD")
    }

    private func hero(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 20) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(DesignTokens.accent)
                    .frame(width: 38, height: 2)
                Text("LOCAL MARKDOWN READER")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(DesignTokens.accentBright)
            }

            Text("Give every note\na quiet place to land.")
                .font(.system(size: compact ? 42 : 54, weight: .bold, design: .serif))
                .tracking(-1.8)
                .lineSpacing(-3)
                .fixedSize(horizontal: false, vertical: true)

            Text("Open local Markdown, keep its structure intact, and read without accounts, distractions, or leaving your Mac.")
                .font(.system(size: compact ? 15 : 17))
                .foregroundStyle(.secondary)
                .lineSpacing(5)
                .frame(maxWidth: 610, alignment: .leading)
        }
    }

    private func actions(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            Button(action: openDocument) {
                Label("Open Markdown", systemImage: "folder")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(minWidth: 176)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.accent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)
            .accessibilityIdentifier("welcome-open")

            HStack(spacing: 14) {
                if hasRecentDocument {
                    actionCard(
                        title: "Continue Reading",
                        detail: "Return to your most recent note.",
                        icon: "clock.arrow.circlepath",
                        identifier: "welcome-recent",
                        compact: compact,
                        action: openRecent
                    )
                }
                actionCard(
                    title: "Paste Clipboard",
                    detail: "Start a new note from copied text.",
                    icon: "doc.on.clipboard",
                    identifier: "welcome-paste",
                    compact: compact,
                    action: pasteClipboard
                )
            }
        }
    }

    private func actionCard(
        title: String,
        detail: String,
        icon: String,
        identifier: String,
        compact: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(DesignTokens.accentBright)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: 280, minHeight: compact ? 50 : 58, alignment: .leading)
            .padding(compact ? 10 : 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(.primary.opacity(0.10))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private var privacy: some View {
        Label(
            "Your notes stay local until you choose to share.",
            systemImage: "lock.shield"
        )
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("welcome-privacy")
    }
}
