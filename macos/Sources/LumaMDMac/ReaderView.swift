import AppKit
import LumaMDCore
import SwiftUI

struct ReaderView: View {
    @ObservedObject var model: AppModel
    let note: ReaderNote

    @Environment(\.colorScheme) private var colorScheme
    @State private var showsOutline = false
    @State private var scrollTarget: ReaderScrollTarget?

    init(model: AppModel, note: ReaderNote) {
        _model = ObservedObject(wrappedValue: model)
        self.note = note
        _showsOutline = State(initialValue: false)
        _scrollTarget = State(
            initialValue: QAEnvironment[.outlineID].map {
                ReaderScrollTarget(headingID: $0)
            }
        )
    }

    private var document: MarkdownDocument {
        MarkdownRenderer().render(note.source, fallbackTitle: note.filename)
    }

    private var pageHTML: String {
        ReaderHTMLBuilder().buildDocument(
            document,
            filename: note.filename,
            fileSize: note.byteCount,
            theme: resolvedReaderTheme,
            typeScale: readerTypeScale
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                readerHeader
                Divider()
                ReaderWebView(
                    html: pageHTML,
                    scrollTarget: scrollTarget,
                    onExternalURL: openExternalURL
                )
            }

            ReaderDockView(
                copyMarkdown: model.copyMarkdown,
                shareMarkdown: model.shareMarkdown,
                showOutline: presentOutline,
                openDocument: model.openDocument
            )
            .padding(.bottom, 18)
            .popover(isPresented: $showsOutline, arrowEdge: .bottom) {
                OutlinePopover(headings: document.headings) { id in
                    NativeQACapture.log("outline-select id=\(id)")
                    scrollTarget = ReaderScrollTarget(headingID: id)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reader-screen")
        .onAppear {
            applyQAPreferences()
            if QAEnvironment[.showActions] == "1" {
                DispatchQueue.main.async {
                    presentOutline()
                }
                NativeQACapture.captureOutline(document.headings)
            }
            if let target = scrollTarget {
                NativeQACapture.log("outline-request id=\(target.headingID)")
            }
        }
    }

    private var readerHeader: some View {
        HStack(spacing: 14) {
            Button(action: model.goHome) {
                HStack(spacing: 9) {
                    Image(systemName: "doc.richtext.fill")
                        .foregroundStyle(DesignTokens.accentBright)
                    Text("Luma MD")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Luma MD home")
            .accessibilityIdentifier("reader-home")

            Divider()
                .frame(height: 20)

            Text(note.filename)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityLabel("Open file \(note.filename)")

            Spacer()

            Button(action: toggleTheme) {
                Label(themeLabel, systemImage: themeSymbol)
                    .labelStyle(.iconOnly)
            }
            .help(themeLabel)
            .accessibilityLabel(themeLabel)
            .accessibilityIdentifier("reader-theme")

            Button(action: model.cycleTypeScale) {
                Label(typeScaleLabel, systemImage: "textformat.size")
                    .labelStyle(.iconOnly)
            }
            .help(typeScaleLabel)
            .accessibilityLabel(typeScaleLabel)
            .accessibilityIdentifier("reader-type")
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(.bar)
    }

    private var resolvedReaderTheme: ReaderTheme {
        switch model.theme {
        case .system:
            return colorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private var readerTypeScale: ReaderTypeScale {
        switch model.typeScale {
        case .small:
            return .small
        case .standard:
            return .standard
        case .large:
            return .large
        }
    }

    private var typeScaleLabel: String {
        switch model.typeScale {
        case .small:
            return "Text Size: Small"
        case .standard:
            return "Text Size: Default"
        case .large:
            return "Text Size: Large"
        }
    }

    private var themeLabel: String {
        resolvedReaderTheme == .dark ? "Use Light Theme" : "Use Dark Theme"
    }

    private var themeSymbol: String {
        resolvedReaderTheme == .dark ? "sun.max" : "moon"
    }

    private func toggleTheme() {
        model.setTheme(resolvedReaderTheme == .dark ? .light : .dark)
    }

    private func presentOutline() {
        showsOutline.toggle()
        NativeQACapture.log("outline-button action=pressed presented=\(showsOutline)")
        if NativeQACapture.isEnabled {
            DispatchQueue.main.async {
                NativeQACapture.captureWindow(named: "outline-open")
            }
        }
    }

    private func openExternalURL(_ url: URL) {
        if NativeQACapture.isEnabled,
           QAEnvironment[.interceptExternal] == "1" {
            NativeQACapture.log(
                "external-url result=PASS scheme=\(url.scheme ?? "none") host=\(url.host ?? "none")"
            )
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func applyQAPreferences() {
        if let value = QAEnvironment[.theme] {
            switch value {
            case "system":
                model.setTheme(.system)
            case "light":
                model.setTheme(.light)
            case "dark":
                model.setTheme(.dark)
            default:
                break
            }
        }
        if let value = QAEnvironment[.typeScale] {
            switch value {
            case "small":
                model.setTypeScale(.small)
            case "standard":
                model.setTypeScale(.standard)
            case "large":
                model.setTypeScale(.large)
            default:
                break
            }
        }
        NativeQACapture.log(
            "preferences theme=\(model.theme) type=\(model.typeScale)"
        )
        if QAEnvironment[.copyMarkdown] == "1" {
            model.copyMarkdown()
            NativeQACapture.log(
                "copy-markdown result=PASS filename=\(note.filename) bytes=\(note.source.utf8.count)"
            )
        }
        if QAEnvironment[.share] == "1" {
            model.shareMarkdown()
            NativeQACapture.log(
                "share-markdown action=invoked filename=\(note.filename) bytes=\(note.source.utf8.count)"
            )
        }
    }
}
