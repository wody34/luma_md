import Foundation
import XCTest
import LumaMDCore

final class ReaderHTMLBuilderTests: XCTestCase {
    private let renderer = MarkdownRenderer()
    private let builder = ReaderHTMLBuilder()

    func testBuildsACompleteDocumentWithEscapedMetadataAndSemanticReaderSurface() {
        let body = Array(repeating: "word", count: 200).joined(separator: " ")
        let document = renderer.render("# Reader\n\n\(body)", fallbackTitle: "fallback.md")

        let html = builder.buildDocument(
            document,
            filename: "notes <final>.md",
            fileSize: 2_048,
            theme: .light,
            typeScale: .standard
        )

        assertContains(html, "<!doctype html>")
        assertContains(html, "<html lang=\"en\" data-theme=\"light\">")
        assertContains(html, "<meta charset=\"utf-8\">")
        assertContains(html, "name=\"viewport\"")
        assertContains(html, "viewport-fit=cover")
        assertContains(html, "<meta name=\"color-scheme\" content=\"dark light\">")
        assertContains(html, "<title>Reader — Luma MD</title>")
        assertContains(html, "LOCAL FILE")
        assertContains(html, "notes &lt;final&gt;.md")
        assertContains(html, "2.0 KB")
        assertContains(html, "2 min read")
        assertContains(html, "<main id=\"reader\"")
        assertContains(html, "<article class=\"reader-surface\" aria-label=\"Markdown document\">")
        assertContains(html, document.html)
        assertNotContainsCaseInsensitive(html, "<aside id=\"outline\"")
        assertNotContainsCaseInsensitive(html, "Back to reader")
    }

    func testEmitsBothThemeTokenSetsAndAllSupportedTypeScales() {
        let document = renderer.render("# Theme", fallbackTitle: "theme.md")

        let compact = builder.buildDocument(
            document,
            filename: "theme.md",
            fileSize: 1,
            theme: .dark,
            typeScale: .compact
        )
        let standard = builder.buildDocument(
            document,
            filename: "theme.md",
            fileSize: 1,
            theme: .dark,
            typeScale: .standard
        )
        let expanded = builder.buildDocument(
            document,
            filename: "theme.md",
            fileSize: 1,
            theme: .light,
            typeScale: .expanded
        )

        assertContains(compact, "data-theme=\"dark\"")
        assertContains(compact, "data-type-scale=\"0.92\"")
        assertContains(compact, "--type-scale:0.92")
        assertContains(standard, "data-type-scale=\"1\"")
        assertContains(standard, "--type-scale:1")
        assertContains(expanded, "data-theme=\"light\"")
        assertContains(expanded, "data-type-scale=\"1.12\"")
        assertContains(expanded, "--type-scale:1.12")
        assertContains(expanded, "--canvas:#0E0D13")
        assertContains(expanded, "[data-theme=light]{--canvas:#F3F0F7")
        assertContains(expanded, "font-size:calc(17px * var(--type-scale))")
        assertContains(expanded, "(var(--type-scale) - 1)*.5")
    }

    func testAdaptsReaderMeasureAcrossViewportWidthsAndRestrictsSelectionToDocumentContent() {
        let document = renderer.render("# Measure\n\nA focused reading column.", fallbackTitle: "measure.md")
        let html = builder.buildDocument(
            document,
            filename: "measure.md",
            fileSize: 128,
            theme: .dark,
            typeScale: .standard
        )

        assertContains(html, "--reader-measure:45rem")
        assertContains(html, "@media(min-width:1200px){:root{--reader-measure:60rem}}")
        assertContains(html, "@media(min-width:1600px){:root{--reader-measure:68rem}}")
        assertContains(html, ".page{width:min(100%,1240px)")
        assertContains(
            html,
            ".document-head,.reader-wrap{width:min(100%,var(--reader-measure))"
        )
        assertContains(html, "body{margin:0")
        assertContains(html, "-webkit-user-select:none;user-select:none")
        assertContains(html, ".reader-surface{-webkit-user-select:text;user-select:text")
        assertContains(html, "overflow-wrap:anywhere")
        assertContains(html, ".table-scroll{overflow-x:auto")
        assertContains(html, ".reader-surface pre{position:relative;overflow:auto")
    }

    func testCSPAndRenderedMarkupForbidScriptsAndRemoteSubresources() {
        let document = renderer.render(
            """
            # Untrusted note

            <script src="https://evil.example.test/payload.js"></script>
            <link rel="stylesheet" href="https://evil.example.test/note.css">
            ![remote](https://evil.example.test/image.png)
            """,
            fallbackTitle: "untrusted.md"
        )
        let html = builder.buildDocument(
            document,
            filename: "untrusted.md",
            fileSize: 512,
            theme: .dark,
            typeScale: .standard
        )

        assertContains(html, "http-equiv=\"Content-Security-Policy\"")
        assertContains(html, "default-src &#39;none&#39;")
        assertContains(html, "script-src &#39;none&#39;")
        assertContains(html, "connect-src &#39;none&#39;")
        assertContains(html, "img-src &#39;none&#39;")
        assertContains(html, "font-src &#39;none&#39;")
        assertContains(html, "media-src &#39;none&#39;")
        assertContains(html, "object-src &#39;none&#39;")
        assertContains(html, "base-uri &#39;none&#39;")
        assertContains(html, "form-action &#39;none&#39;")
        assertContains(html, "style-src &#39;unsafe-inline&#39;")
        assertNotContainsCaseInsensitive(html, "<script")
        assertNotContainsCaseInsensitive(html, "<link")
        assertNotContainsCaseInsensitive(html, "src=\"http")
        assertNotContainsCaseInsensitive(html, "url(http")
        assertNotContainsCaseInsensitive(html, "@import")
    }

    func testSafeExternalLinksPreserveNavigationMarkupWithoutOpeningUnsafeSchemes() {
        let document = renderer.render(
            """
            # Links

            [External](https://example.com/guide?source=luma&mode=read)
            [Anchor](#links)
            [Mail](mailto:hello@example.com)
            [Unsafe](javascript:alert(1))
            """,
            fallbackTitle: "links.md"
        )
        let html = builder.buildDocument(
            document,
            filename: "links.md",
            fileSize: 256,
            theme: .light,
            typeScale: .standard
        )

        assertContains(html, "href=\"https://example.com/guide?source=luma&amp;mode=read\"")
        assertContains(html, "target=\"_blank\" rel=\"noopener noreferrer\"")
        assertContains(html, "<a href=\"#links\">Anchor</a>")
        assertContains(html, "href=\"mailto:hello@example.com\"")
        assertContains(html, "<span class=\"unsafe-link\">Unsafe</span>")
        assertNotContainsCaseInsensitive(html, "href=\"javascript:")
        assertNotContainsCaseInsensitive(html, "href=\"file:")
        assertNotContainsCaseInsensitive(html, "href=\"data:")
    }

    func testStylesFractionsRadicalsAndMathBlocksAsReadableLayout() {
        let document = renderer.render(
            """
            Inline $E = mc^2$.

            $$
            \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
            $$
            """,
            fallbackTitle: "math.md"
        )
        let html = builder.buildDocument(
            document,
            filename: "math.md",
            fileSize: 64,
            theme: .light,
            typeScale: .standard
        )

        assertContains(html, ".math-inline{")
        assertContains(html, ".math-block{")
        assertContains(html, ".math-inline math{font-size:1.08em;max-width:100%}")
        assertContains(html, ".math-block math{display:block;min-width:max-content;")
        assertNotContainsCaseInsensitive(html, ".frac{")
        assertNotContainsCaseInsensitive(html, ".sqrt::before")
    }

    private func assertContains(
        _ value: String,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(value.contains(expected), "Expected output to contain: \(expected)", file: file, line: line)
    }

    private func assertNotContainsCaseInsensitive(
        _ value: String,
        _ unexpected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            value.range(of: unexpected, options: .caseInsensitive) != nil,
            "Expected output not to contain: \(unexpected)",
            file: file,
            line: line
        )
    }
}
