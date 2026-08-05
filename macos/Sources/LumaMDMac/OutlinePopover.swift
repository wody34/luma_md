import LumaMDCore
import SwiftUI

struct OutlinePopover: View {
    let headings: [MarkdownDocument.Heading]
    let selectHeading: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Outline", systemImage: "list.bullet.indent")
                .font(.headline)

            if headings.isEmpty {
                Text("This note has no headings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("outline-empty")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(headings.enumerated()), id: \.offset) { _, heading in
                            Button {
                                selectHeading(heading.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Text("H\(heading.level)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(DesignTokens.accentBright)
                                        .frame(width: 20)
                                    Text(heading.text)
                                        .font(.system(size: 13))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(.leading, CGFloat(max(0, heading.level - 1)) * 10)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(heading.text), heading level \(heading.level)")
                            .accessibilityIdentifier("outline-\(heading.id)")
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(16)
        .frame(width: 310, alignment: .leading)
        .accessibilityIdentifier("reader-outline")
    }
}
