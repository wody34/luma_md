import Foundation

public struct ReaderHTMLBuilder {
    public init() {}

    public func buildDocument(
        _ document: MarkdownDocument,
        filename: String,
        fileSize: Int,
        theme: ReaderTheme,
        typeScale: ReaderTypeScale
    ) -> String {
        let resolvedTheme = theme == .light ? "light" : "dark"
        let scale = scaleValue(typeScale)
        let safeFilename = escapeHTML(filename)
        let safeTitle = escapeHTML(document.title)
        let minutes = max(1, (document.wordCount + 199) / 200)
        let policy = [
            "default-src &#39;none&#39;",
            "script-src &#39;none&#39;",
            "connect-src &#39;none&#39;",
            "img-src &#39;none&#39;",
            "font-src &#39;none&#39;",
            "media-src &#39;none&#39;",
            "object-src &#39;none&#39;",
            "base-uri &#39;none&#39;",
            "form-action &#39;none&#39;",
            "style-src &#39;unsafe-inline&#39;",
        ].joined(separator: " ")

        return """
        <!doctype html>
        <html lang="en" data-theme="\(resolvedTheme)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
        <meta name="color-scheme" content="dark light">
        <meta http-equiv="Content-Security-Policy" content="\(policy)">
        <title>\(safeTitle) — Luma MD</title>
        <style>\(ReaderStyles.css(typeScale: typeScale))</style>
        </head>
        <body data-type-scale="\(scale)">
        <div class="page">
        <header class="document-head">
        <div class="eyebrow">LOCAL FILE</div>
        <h1 class="document-title">\(safeTitle)</h1>
        <div class="metadata">
        <span>\(safeFilename)</span>
        <span>\(minutes) min read</span>
        <span>\(formatBytes(fileSize))</span>
        </div>
        </header>
        <main id="reader" class="reader-wrap">
        <article class="reader-surface" aria-label="Markdown document">\(document.html)</article>
        </main>
        </div>
        </body>
        </html>
        """
    }

    private func formatBytes(_ bytes: Int) -> String {
        guard bytes >= 1_024 else {
            return "\(bytes) B"
        }
        let kilobytes = Double(bytes) / 1_024
        if kilobytes < 1_024 {
            return String(format: "%.1f KB", kilobytes)
        }
        return String(format: "%.1f MB", kilobytes / 1_024)
    }

    private func scaleValue(_ scale: ReaderTypeScale) -> String {
        switch scale {
        case .small:
            return "0.92"
        case .standard:
            return "1"
        case .large:
            return "1.12"
        }
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
