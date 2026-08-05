import SwiftUI

enum ReaderDockAction: Hashable {
    case copy
    case share
    case outline
    case open

    static let primary: [ReaderDockAction] = [
        .copy,
        .share,
        .outline,
        .open,
    ]

    var title: String {
        switch self {
        case .copy: "Copy"
        case .share: "Share"
        case .outline: "Outline"
        case .open: "Open"
        }
    }

    var systemImage: String {
        switch self {
        case .copy: "doc.on.doc"
        case .share: "square.and.arrow.up"
        case .outline: "list.bullet.indent"
        case .open: "folder"
        }
    }

    var identifier: String {
        "reader-\(String(describing: self))"
    }
}

struct ReaderDockView: View {
    let copyMarkdown: () -> Void
    let shareMarkdown: () -> Void
    let showOutline: () -> Void
    let openDocument: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReaderDockAction.primary, id: \.self) { item in
                dockButton(
                    item.title,
                    systemImage: item.systemImage,
                    identifier: item.identifier,
                    action: { perform(item) }
                )
            }
        }
        .padding(6)
        .background(.ultraThickMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.12))
        }
        .shadow(color: DesignTokens.documentShadow, radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reader actions")
    }

    private func perform(_ item: ReaderDockAction) {
        switch item {
        case .copy:
            copyMarkdown()
        case .share:
            shareMarkdown()
        case .outline:
            showOutline()
        case .open:
            openDocument()
        }
    }

    private func dockButton(
        _ title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
