import AppKit
import LumaMDCore
import SwiftUI

struct OutlinePanelColor {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var relativeLuminance: Double {
        func linearize(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red)
            + 0.7152 * linearize(green)
            + 0.0722 * linearize(blue)
    }
}

enum OutlinePanelPalette {
    static let lightSurface = OutlinePanelColor(
        red: 252.0 / 255.0,
        green: 251.0 / 255.0,
        blue: 254.0 / 255.0
    )
    static let lightForeground = OutlinePanelColor(
        red: 37.0 / 255.0,
        green: 33.0 / 255.0,
        blue: 43.0 / 255.0
    )
    static let darkSurface = OutlinePanelColor(
        red: 22.0 / 255.0,
        green: 20.0 / 255.0,
        blue: 30.0 / 255.0
    )
    static let darkForeground = OutlinePanelColor(
        red: 244.0 / 255.0,
        green: 241.0 / 255.0,
        blue: 250.0 / 255.0
    )

    static func contrastRatio(
        foreground: OutlinePanelColor,
        surface: OutlinePanelColor
    ) -> Double {
        let lighter = max(foreground.relativeLuminance, surface.relativeLuminance)
        let darker = min(foreground.relativeLuminance, surface.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

enum ReaderOutlineLayout {
    static let sideInset: CGFloat = 20
    static let topInset: CGFloat = 20
    static let dockClearance: CGFloat = 88
    static let maximumWidth: CGFloat = 360
    static let maximumHeight: CGFloat = 360

    static func panelWidth(for containerWidth: CGFloat) -> CGFloat {
        min(maximumWidth, max(0, containerWidth - sideInset * 2))
    }

    static func panelMaximumHeight(for containerHeight: CGFloat) -> CGFloat {
        min(maximumHeight, max(0, containerHeight - topInset - dockClearance))
    }
}

struct OutlinePopover: View {
    private enum FocusTarget: Hashable {
        case close
        case heading(Int)
    }

    let headings: [MarkdownDocument.Heading]
    let selectHeading: (String) -> Void
    let dismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedTarget: FocusTarget?
    @State private var keyboardMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label("Outline", systemImage: "list.bullet.indent")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Label("Close Outline", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focused($focusedTarget, equals: .close)
                .keyboardShortcut(.cancelAction)
                .help("Close Outline")
                .accessibilityLabel("Close Outline")
                .accessibilityIdentifier("outline-close")
            }

            if headings.isEmpty {
                Text("This note has no headings.")
                    .font(.callout)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("outline-empty")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(headings.enumerated()), id: \.offset) { index, heading in
                            Button {
                                selectHeading(heading.id)
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(DesignTokens.accentBright.opacity(0.7))
                                        .frame(width: 2, height: 16)
                                        .accessibilityHidden(true)
                                    Text(heading.text)
                                        .font(.system(size: 13))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(.leading, CGFloat(max(0, heading.level - 1)) * 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .focused($focusedTarget, equals: .heading(index))
                            .accessibilityLabel("\(heading.text), heading level \(heading.level)")
                            .accessibilityIdentifier("outline-\(heading.id)")
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(16)
        .foregroundStyle(foregroundColor)
        .background(surfaceColor, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(foregroundColor.opacity(0.14))
        }
        .shadow(color: DesignTokens.documentShadow, radius: 24, y: 12)
        .contentShape(Rectangle())
        .focusSection()
        .onAppear {
            focusedTarget = .close
            installKeyboardMonitor()
        }
        .onDisappear(perform: removeKeyboardMonitor)
        .onExitCommand(perform: dismiss)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("reader-outline")
    }

    private func installKeyboardMonitor() {
        removeKeyboardMonitor()
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            if event.keyCode == 53 {
                dismiss()
                return nil
            }
            guard event.keyCode == 48 else { return event }

            let targets = [FocusTarget.close]
                + headings.indices.map(FocusTarget.heading)
            let currentIndex = targets.firstIndex(
                of: focusedTarget ?? .close
            ) ?? 0
            let direction = event.modifierFlags.contains(.shift) ? -1 : 1
            let nextIndex = (currentIndex + direction + targets.count)
                % targets.count
            focusedTarget = targets[nextIndex]
            return nil
        }
    }

    private func removeKeyboardMonitor() {
        guard let keyboardMonitor else { return }
        NSEvent.removeMonitor(keyboardMonitor)
        self.keyboardMonitor = nil
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? OutlinePanelPalette.darkSurface.color
            : OutlinePanelPalette.lightSurface.color
    }

    private var foregroundColor: Color {
        colorScheme == .dark
            ? OutlinePanelPalette.darkForeground.color
            : OutlinePanelPalette.lightForeground.color
    }
}
