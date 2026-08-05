import Foundation
import XCTest
import LumaMDCore

final class MarkdownRendererTests: XCTestCase {
    private let renderer = MarkdownRenderer()

    func testRetainsOriginalSourceDerivesTitleAndBuildsUniqueOutlineSlugs() {
        let source = """
        # Luma & Safety\r
        \r
        ## Read Me!\r
        ## Read Me!\r
        ### 한국어 제목\r
        """

        let document = renderer.render(source, fallbackTitle: "fallback.md")

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.title, "Luma & Safety")
        XCTAssertFalse(document.isEmpty)
        XCTAssertGreaterThan(document.wordCount, 0)
        XCTAssertEqual(document.headings.map(\.level), [1, 2, 2, 3])
        XCTAssertEqual(document.headings.map(\.text), [
            "Luma & Safety",
            "Read Me!",
            "Read Me!",
            "한국어 제목",
        ])
        XCTAssertEqual(document.headings.map(\.id), [
            "luma-safety",
            "read-me",
            "read-me-2",
            "한국어-제목",
        ])
        assertContains(document.html, "<h1 id=\"luma-safety\">Luma &amp; Safety</h1>")
        assertContains(document.html, "<h2 id=\"read-me-2\">Read Me!</h2>")
    }

    func testUsesCleanedFallbackTitleWhenDocumentHasNoH1() {
        let document = renderer.render("A body without a document heading.", fallbackTitle: "weekly.plan.markdown")

        XCTAssertEqual(document.title, "weekly.plan")
        XCTAssertTrue(document.headings.isEmpty)
        XCTAssertFalse(document.isEmpty)
    }

    func testRendersParagraphEmphasisAndSafeLinksWhileEscapingNoteAuthoredHTML() {
        let source = """
        First line
        continues as one paragraph.

        **Bright** and *calm*, with `inline code`.

        [Docs](https://example.com/docs?mode=read&from=luma) [Mail](mailto:reader@example.com) [Section](#details) [Unsafe](javascript:alert(1)) [Local file](file:///tmp/note.md)

        <script>alert('x')</script> <b>never trusted</b>
        ![remote preview](https://cdn.example.test/preview.png)
        """

        let html = renderer.render(source, fallbackTitle: "links.md").html

        assertContains(html, "<p>First line continues as one paragraph.</p>")
        assertContains(html, "<strong>Bright</strong>")
        assertContains(html, "<em>calm</em>")
        assertContains(html, "<code>inline code</code>")
        assertContains(html, "href=\"https://example.com/docs?mode=read&amp;from=luma\"")
        assertContains(html, "target=\"_blank\" rel=\"noopener noreferrer\"")
        assertContains(html, "href=\"mailto:reader@example.com\"")
        assertContains(html, "<a href=\"#details\">Section</a>")
        assertContains(html, "<span class=\"unsafe-link\">Unsafe</span>")
        assertContains(html, "<span class=\"unsafe-link\">Local file</span>")
        assertContains(html, "&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;")
        assertContains(html, "&lt;b&gt;never trusted&lt;/b&gt;")
        assertContains(html, "<span class=\"image-alt\">[remote preview]</span>")
        assertNotContains(html, "<script")
        assertNotContains(html, "<b>")
        assertNotContains(html, "javascript:")
        assertNotContains(html, "file://")
        assertNotContains(html, "<img ")
    }

    func testPreservesFormulaLikeUnderscoresWithoutBreakingDelimitedEmphasis() {
        let source = """
        Raw notation: e_{t+1} ≤ τ·e_t + η_t, η_max, p_stay, and ‖z_i−z_j‖.

        _Intentional emphasis_ remains semantic.
        """

        let html = renderer.render(source, fallbackTitle: "notation.md").html

        assertContains(html, "e_{t+1} ≤ τ·e_t + η_t")
        assertContains(html, "η_max")
        assertContains(html, "p_stay")
        assertContains(html, "‖z_i−z_j‖")
        assertContains(html, "<em>Intentional emphasis</em>")
        assertNotContains(html, "<em>{t+1} ≤ τ·e</em>")
        assertNotContains(html, "<em>i−z</em>")
    }

    func testParsesSoftWrappedInlineMathBeforeJoiningParagraphProse() {
        let source = """
        With $M_{(q,a),m} =
        P(r{=}{+}1\\mid q,a,m)$ and $P_\\perp = I$.
        """

        let html = renderer.render(source, fallbackTitle: "soft-wrap.md").html

        assertContains(html, "<msub><mi>M</mi>")
        assertContains(html, "<msub><mi>P</mi><mo>⊥</mo></msub>")
        assertContains(html, "</span> and <span class=\"math-inline\"")
        assertNotContains(html, "aria-label=\" and \"")
        assertNotContains(html, "$M_")
        assertNotContains(html, "I$")
    }

    func testKeepsMarkdownLookingLinesInsideOpenInlineMath() {
        for marker in ["-", "+", ">", "#"] {
            let html = renderer.render(
                "Formula $x =\n\(marker) y$.",
                fallbackTitle: "math-continuation.md"
            ).html

            assertContains(html, "<p>Formula <span class=\"math-inline\"")
            assertNotContains(html, "$x")
            assertNotContains(html, "<ul>")
            assertNotContains(html, "<blockquote>")
            assertNotContains(html, "<h1")
        }
    }

    func testRendersLearningPaperNotationCommandsWithoutTextFallback() {
        let source = """
        $m_t \\in \\{1,\\dots,K\\}$ and $a^\\star = \\mathrm{TAB}[q_t,m_t]$.
        $P_\\perp = I - \\tfrac1K\\mathbf{1}\\mathbf{1}^\\top$.
        $\\mathcal{L}_{\\mathrm{pred}} = -\\sum_t \\log \\hat P_\\theta(r_t \\mid c_t)$.
        $\\max\\lvert \\nabla_{\\mathrm{RTRL}} - \\nabla_{\\mathrm{BPTT}}\\rvert = 10^{-15}$.
        $\\partial\\phi_\\theta / \\partial\\theta$, $\\sim\\!60\\times$, and $81\\%$.
        """

        let html = renderer.render(source, fallbackTitle: "paper-notation.md").html

        assertContains(html, "<mo>∈</mo>")
        assertContains(html, "<mo>…</mo>")
        assertContains(html, "<mo>⋆</mo>")
        assertContains(html, "<mo>⊥</mo>")
        assertContains(html, "<mfrac><mn>1</mn><mi>K</mi></mfrac>")
        assertContains(html, "<mstyle mathvariant=\"bold\"><mn>1</mn></mstyle>")
        assertContains(html, "<mo>⊤</mo>")
        assertContains(html, "<mstyle mathvariant=\"script\"><mi>L</mi></mstyle>")
        assertContains(html, "<mo>|</mo>")
        assertContains(html, "<mi>∇</mi>")
        assertContains(html, "<mi>∂</mi>")
        assertContains(html, "<mo>∼</mo>")
        assertContains(html, "<mo>×</mo>")
        assertContains(html, "<mo>%</mo>")
        assertNotContains(html, "<mtext>")
    }

    func testFallsBackWhenMathExceedsDepthOrNodeBudgets() {
        let nested = String(repeating: "{", count: 65)
            + "x"
            + String(repeating: "}", count: 65)
        let oversized = String(repeating: "x", count: 4_097)
        let html = renderer.render(
            "$\(nested)$\n\n$\(oversized)$",
            fallbackTitle: "bounded-math.md"
        ).html

        XCTAssertEqual(html.components(separatedBy: "<mtext>").count - 1, 2)
        assertContains(html, nested)
        assertContains(html, oversized)
    }

    func testAlignsUnbracedArgumentsAndNamedOperatorsAcrossEditions() {
        let html = renderer.render(
            "$\\sqrt x^2 + \\ln x + \\exp y$",
            fallbackTitle: "math-parity.md"
        ).html

        assertContains(html, "<msup><msqrt><mi>x</mi></msqrt><mn>2</mn></msup>")
        assertContains(html, "<mo>ln</mo>")
        assertContains(html, "<mo>exp</mo>")
        assertNotContains(html, "<mtext>")
    }

    func testRendersListsTasksTablesQuotesAndRulesSemantically() {
        let source = """
        - Plain item
        - [x] Finished without a strikethrough
        - [ ] Still reading

        1. First
        2. Second

        > Local files stay local.

        | Surface | Behavior |
        | --- | --- |
        | Copy | Original source |

        ---
        """

        let html = renderer.render(source, fallbackTitle: "structures.md").html

        assertContains(html, "<ul>")
        assertContains(html, "<li>Plain item</li>")
        assertContains(html, "<li class=\"task done\">")
        assertContains(html, "<li class=\"task\">")
        assertContains(html, "<span class=\"checkbox\" aria-hidden=\"true\">✓</span>")
        assertContains(html, "<ol>")
        assertContains(html, "<blockquote><p>Local files stay local.</p></blockquote>")
        assertContains(html, "<div class=\"table-scroll\"><table>")
        assertContains(html, "<thead><tr><th>Surface</th><th>Behavior</th></tr></thead>")
        assertContains(html, "<tbody><tr><td>Copy</td><td>Original source</td></tr></tbody>")
        assertContains(html, "<hr>")
        assertNotContains(html, "<del>Finished")
    }

    func testLabelsAndHighlightsRecognizedFencedCodeAndEscapesUnknownCode() {
        let source = """
        ```kotlin
        // A local note
        data class Note(val title: String = "Luma", val count: Int = 2)
        ```

        ```plaintext
        <script>alert('safe')</script>
        ```
        """

        let html = renderer.render(source, fallbackTitle: "code.md").html

        assertContains(html, "<pre data-language=\"kotlin\"><code class=\"language-kotlin\">")
        assertContains(html, "<span class=\"tok-comment\">// A local note</span>")
        assertContains(html, "<span class=\"tok-keyword\">data</span>")
        assertContains(html, "<span class=\"tok-type\">Note</span>")
        assertContains(html, "<span class=\"tok-string\">&quot;Luma&quot;</span>")
        assertContains(html, "<span class=\"tok-number\">2</span>")
        assertContains(html, "<pre data-language=\"plaintext\"><code>")
        assertContains(html, "&lt;script&gt;alert(&#39;safe&#39;)&lt;/script&gt;")
        assertNotContains(html, "<script")
    }

    func testRendersAccessibleInlineAndBlockMathWithoutNetworkDependencies() {
        let source = """
        Energy follows $E = mc^2$. Greek symbols remain semantic: $\\alpha \\leq \\Omega$.

        $$
        \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
        $$
        """

        let html = renderer.render(source, fallbackTitle: "equations.md").html

        assertContains(html, "<span class=\"math-inline\" role=\"math\"")
        assertContains(html, "aria-label=\"E = mc^2\"")
        assertContains(html, "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">")
        assertContains(html, "<msup><mi>c</mi><mn>2</mn></msup>")
        assertContains(html, "<mi>α</mi><mo>≤</mo><mi>Ω</mi>")
        assertContains(html, "<div class=\"math-block\" role=\"math\"")
        assertContains(html, "<mfrac>")
        assertContains(html, "<msqrt>")
        assertContains(html, "<mo>±</mo>")
        assertNotContains(html, "<span class=\"frac\">")
        assertNotContains(html, "\\frac")
        assertNotContains(html, "cdn.")
        assertNotContains(html, "<script")
    }

    func testRendersAdvancedTeXSubsetAsSemanticMathML() throws {
        let source = try fixture(named: "advanced-formulas", extension: "md")
        let html = renderer.render(source, fallbackTitle: "advanced-formulas.md").html

        assertContains(html, "<mfrac>")
        assertContains(html, "<mroot><mstyle mathvariant=\"bold\"><mi>y</mi></mstyle><mn>3</mn></mroot>")
        assertContains(html, "<msubsup><mover accent=\"true\"><mi>x</mi><mo>^</mo></mover><mi>i</mi><mn>2</mn></msubsup>")
        assertContains(html, "<munderover><mo>∑</mo>")
        assertContains(html, "<munderover><mo>∏</mo>")
        assertContains(html, "<munderover><mo>∫</mo>")
        assertContains(html, "<mo fence=\"true\" stretchy=\"true\">(</mo>")
        assertContains(html, "<mstyle mathvariant=\"normal\"><mi>d</mi></mstyle>")
        assertContains(html, "<mover accent=\"true\"><mi>y</mi><mo>¯</mo></mover>")
        assertContains(html, "<mover accent=\"true\"><mi>z</mi><mo>→</mo></mover>")
        assertContains(html, "<mo>det</mo>")
        assertContains(html, "<mtable><mtr><mtd><mn>1</mn></mtd><mtd><mn>0</mn></mtd></mtr>")
        assertContains(html, "<mtable columnalign=\"right left\">")
        assertContains(html, "<mo fence=\"true\" stretchy=\"true\">{</mo>")
        assertContains(html, "<mtext>if</mtext><mspace width=\"0.28em\"></mspace>")
        assertNotContains(html, "math-command")
        assertNotContains(html, "<span class=\"frac\">")
    }

    func testPreservesMalformedMathSourceWithoutExecutableMarkup() {
        let html = renderer.render(
            "Unknown $\\danger{<script>alert(1)</script>}$. Broken $\\frac{a$. "
                + "Bad fence $\\left(x\\rightfoo$.",
            fallbackTitle: "unsafe-math.md"
        ).html

        assertContains(html, "<mtext>\\danger{&lt;script&gt;alert(1)&lt;/script&gt;}</mtext>")
        assertContains(html, "<mtext>\\frac{a</mtext>")
        assertContains(html, "<mtext>\\left(x\\rightfoo</mtext>")
        assertNotContains(html, "<script")
        assertNotContains(html, "math-command")
    }

    func testBuildsFootnotesWithRepeatedReferencesAndBacklinks() {
        let source = """
        A grounded note[^source] can cite twice[^source] and remain local[^local]. Unknown[^missing].

        [^source]: A compact local footnote.
        [^local]: **Nothing leaves** the device.
        """

        let html = renderer.render(source, fallbackTitle: "footnotes.md").html

        assertContains(html, "<sup class=\"footnote-ref\"><a id=\"fnref-source\"")
        assertContains(html, "href=\"#fn-source\" aria-label=\"Footnote 1\">1</a></sup>")
        assertContains(html, "id=\"fnref-source-2\"")
        assertContains(html, "<section class=\"footnotes\" aria-label=\"Footnotes\">")
        assertContains(html, "<li id=\"fn-source\">")
        assertContains(html, "<a class=\"footnote-backref\" href=\"#fnref-source\"")
        assertContains(html, "<a class=\"footnote-backref\" href=\"#fnref-source-2\"")
        assertContains(html, "<li id=\"fn-local\">")
        assertContains(html, "<strong>Nothing leaves</strong> the device.")
        assertContains(html, "Unknown[^missing]")
        assertNotContains(html, "[^source]:")
        assertNotContains(html, "[^local]:")
    }

    func testHandlesNilEmptyAndMalformedInputWithoutEmittingExecutableMarkup() {
        let nilDocument = renderer.render(nil, fallbackTitle: nil)
        XCTAssertTrue(nilDocument.isEmpty)
        XCTAssertEqual(nilDocument.source, "")
        XCTAssertEqual(nilDocument.title, "Untitled note")
        assertContains(nilDocument.html, "This file is empty")
        assertContains(nilDocument.html, "href=\"luma://open\"")

        let whitespace = " \r\n\t\r\n"
        let emptyDocument = renderer.render(whitespace, fallbackTitle: "empty.md")
        XCTAssertTrue(emptyDocument.isEmpty)
        XCTAssertEqual(emptyDocument.source, whitespace)
        XCTAssertEqual(emptyDocument.title, "empty")

        let malformed = """
        **unfinished
        [broken](https://example.com
        <script>alert(1)</script>

        ```swift
        let value = "<tag>"
        """
        let html = renderer.render(malformed, fallbackTitle: "rough.md").html

        assertContains(html, "**unfinished")
        assertContains(html, "[broken](https://example.com")
        assertContains(html, "&lt;script&gt;alert(1)&lt;/script&gt;")
        assertContains(html, "&lt;tag&gt;")
        assertNotContains(html, "<script")
        assertNotContains(html, "<tag>")
    }

    func testReleaseNotesFixtureCoversTheCoreReadingPrimitives() throws {
        let source = try fixture(named: "luma-release-notes", extension: "md")
        let document = renderer.render(source, fallbackTitle: "ignored.md")

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.title, "Luma MD Release Notes")
        XCTAssertEqual(document.headings.map(\.id), ["luma-md-release-notes", "reader", "privacy"])
        assertContains(document.html, "<li class=\"task done\">")
        assertContains(document.html, "<blockquote>")
        assertContains(document.html, "<table>")
        assertContains(document.html, "data-language=\"swift\"")
        assertContains(document.html, "href=\"https://example.com\"")
        assertContains(document.html, "<a href=\"#privacy\">Privacy</a>")
        assertContains(document.html, "&lt;script&gt;alert(&quot;no&quot;)&lt;/script&gt;")
    }

    func testFormulaCodeFixtureCoversMathHighlightingAndUnicodeText() throws {
        let source = try fixture(named: "formula-code", extension: "mdx")
        let document = renderer.render(source, fallbackTitle: "formula-code.mdx")

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.title, "Formula and Code")
        assertContains(document.html, "math-inline")
        assertContains(document.html, "math-block")
        assertContains(document.html, "data-language=\"python\"")
        assertContains(document.html, "data-language=\"json\"")
        assertContains(document.html, "<span class=\"tok-keyword\">def</span>")
        assertContains(document.html, "<span class=\"tok-literal\">true</span>")
    }

    func testDenseFootnotesFixtureUsesStableDuplicateSlugsAndFootnoteNavigation() throws {
        let source = try fixture(named: "dense-footnotes", extension: "md")
        let document = renderer.render(source, fallbackTitle: "dense-footnotes.md")

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.title, "Footnote Atlas")
        XCTAssertEqual(document.headings.map(\.id), ["footnote-atlas", "nested-topic", "nested-topic-2"])
        assertContains(document.html, "id=\"fn-one\"")
        assertContains(document.html, "id=\"fn-two\"")
        assertContains(document.html, "footnote-backref")
    }

    func testEmptyFixtureRemainsAnExactEmptyDocument() throws {
        let source = try fixture(named: "empty", extension: "md")
        let document = renderer.render(source, fallbackTitle: "empty.md")

        XCTAssertEqual(document.source, source)
        XCTAssertTrue(document.isEmpty)
        XCTAssertEqual(document.title, "empty")
        XCTAssertEqual(document.wordCount, 0)
        XCTAssertTrue(document.headings.isEmpty)
        assertContains(document.html, "class=\"empty-state\"")
        assertContains(document.html, "This file is empty")
    }

    private func fixture(named name: String, extension fileExtension: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func assertContains(
        _ value: String,
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(value.contains(expected), "Expected output to contain: \(expected)", file: file, line: line)
    }

    private func assertNotContains(
        _ value: String,
        _ unexpected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(value.contains(unexpected), "Expected output not to contain: \(unexpected)", file: file, line: line)
    }
}
