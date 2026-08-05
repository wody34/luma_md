import AppKit
import SwiftUI

public struct ContentView: View {
    @ObservedObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            canvas
                .ignoresSafeArea()

            switch model.state {
            case .welcome:
                WelcomeView(
                    hasRecentDocument: model.hasRecentDocument,
                    openDocument: model.openDocument,
                    openRecent: model.openRecent,
                    pasteClipboard: model.createClipboardMemo
                )
            case let .reading(note):
                ReaderView(model: model, note: note)
            case let .failure(message):
                failureView(message)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .frame(
            minWidth: DesignTokens.windowMinimum.width,
            minHeight: DesignTokens.windowMinimum.height
        )
        .onAppear {
            NativeQACapture.log("state=welcome")
            NativeQACapture.log(
                "preferences theme=\(model.theme) type=\(model.typeScale)"
            )
            if QAEnvironment[.clearRecent] == "1" {
                model.clearRecent()
                NativeQACapture.log("recent-clear result=PASS")
            }
            if QAEnvironment[.clipboardMemo] == "1" {
                model.createClipboardMemo()
                NativeQACapture.log("clipboard-memo action=invoked")
            }
            if QAEnvironment[.openRecent] == "1" {
                model.openRecent()
                NativeQACapture.log("open-recent action=invoked")
            }
            NativeQACapture.log("recent available=\(model.hasRecentDocument)")
            NativeQACapture.captureWindow(named: "welcome")
        }
        .onChange(of: model.theme) { theme in
            NativeQACapture.log("preference-change theme=\(theme)")
        }
        .onChange(of: model.typeScale) { typeScale in
            NativeQACapture.log("preference-change type=\(typeScale)")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            NativeQACapture.log("window=did-become-key")
            if let window = note.object as? NSWindow {
                NativeQACapture.configureWindow(window)
            }
            let name = QAEnvironment[.showActions] == "1"
                ? "outline-popover"
                : captureName
            NativeQACapture.captureWindow(named: name)
        }
        .onChange(of: model.state) { state in
            switch state {
            case .welcome:
                NativeQACapture.log("state=welcome")
                NativeQACapture.captureWindow(named: "home")
            case let .reading(note):
                NativeQACapture.log(
                    "state=reading filename=\(note.filename) bytes=\(note.byteCount) temporary=\(note.isTemporary) recent=\(model.hasRecentDocument) elapsed-ms=\(NativeQACapture.elapsedMilliseconds)"
                )
                NativeQACapture.captureWindow(named: "reader-window")
            case let .failure(message):
                NativeQACapture.log(
                    "state=failure message=\(message) recent=\(model.hasRecentDocument) elapsed-ms=\(NativeQACapture.elapsedMilliseconds)"
                )
                NativeQACapture.captureWindow(named: "error")
            }
        }
    }

    private var canvas: Color {
        switch model.theme {
        case .system:
            return colorScheme == .light ? DesignTokens.lightCanvas : DesignTokens.darkCanvas
        case .light:
            return DesignTokens.lightCanvas
        case .dark:
            return DesignTokens.darkCanvas
        }
    }

    private var captureName: String {
        switch model.state {
        case .welcome:
            return "welcome"
        case .reading:
            return "reader-ready"
        case .failure:
            return "error"
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch model.theme {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 22) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(DesignTokens.accentBright)

            VStack(spacing: 8) {
                Text("This note could not be opened.")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            HStack(spacing: 12) {
                Button("Open Another File", action: model.openDocument)
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.accent)
                    .accessibilityIdentifier("error-open")
                Button("Home", action: model.goHome)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("error-home")
            }
        }
        .padding(48)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.primary.opacity(0.1))
        }
        .shadow(color: DesignTokens.documentShadow, radius: 32, y: 18)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("error-screen")
    }
}
