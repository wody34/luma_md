package dev.lumamd.viewer.core;

public final class MarkdownRendererTest {
    private static final MarkdownRenderer RENDERER = new MarkdownRenderer();

    private MarkdownRendererTest() {
    }

    public static void main(String[] args) {
        String scope = args.length == 0 ? "all" : args[0];
        if ("all".equals(scope) || "core".equals(scope)) {
            rendersCoreMarkdownAndSanitizesLinks();
        }
        if ("all".equals(scope) || "edge".equals(scope)) {
            handlesEmptyAndMalformedInput();
        }
        if ("all".equals(scope) || "math".equals(scope)) {
            rendersInlineAndBlockMathOffline();
            rendersAdvancedSemanticMath();
            parsesSoftWrappedMathAndPreservesFormulaLikeUnderscores();
            keepsMarkdownLookingLinesInsideOpenInlineMath();
            fallsBackWhenMathExceedsDepthOrNodeBudgets();
            fallsBackWhenUnbracedMathNestingExceedsDepthBudget();
            rejectsMalformedDelimiterCommands();
            preservesSupplementaryUnicodeMath();
            alignsUnbracedArgumentsAndNamedOperators();
        }
        if ("all".equals(scope) || "highlight".equals(scope)) {
            highlightsRecognizedFencedLanguagesSafely();
        }
        if ("all".equals(scope) || "footnote".equals(scope)) {
            linksFootnoteReferencesDefinitionsAndBacklinks();
        }
        System.out.println("MarkdownRendererTest " + scope + " passed");
    }

    private static void rendersCoreMarkdownAndSanitizesLinks() {
        String markdown = "# Release Notes\n\n"
                + "**Bright** and *calm*.\n\n"
                + "- [x] Ready to ship\n"
                + "- [ ] Final review\n\n"
                + "> Local and yours.\n\n"
                + "1. Open a note\n"
                + "2. Keep reading\n\n"
                + "```java\nSystem.out.println(\"safe\");\n```\n\n"
                + "| Status | Owner |\n"
                + "| --- | --- |\n"
                + "| Ready | Team |\n\n"
                + "[Docs](https://example.com) "
                + "[Unsafe](javascript:alert('x'))";

        MarkdownDocument document = RENDERER.render(markdown, "release-notes.md");
        String html = document.getHtml();

        assertContains(html, "<h1 id=\"release-notes\">Release Notes</h1>");
        assertContains(html, "<strong>Bright</strong>");
        assertContains(html, "<em>calm</em>");
        assertContains(html, "<li class=\"task done\">");
        assertContains(html, "<blockquote>");
        assertContains(html, "<ol>");
        assertContains(html, "<pre data-language=\"java\"><code class=\"language-java\">");
        assertContains(html, "<table>");
        assertContains(html, "href=\"https://example.com\"");
        assertNotContains(html, "javascript:");
        assertEquals("Release Notes", document.getTitle());
        assertEquals(1, document.getHeadings().size());
    }

    private static void handlesEmptyAndMalformedInput() {
        MarkdownDocument empty = RENDERER.render("", "empty.md");
        assertTrue(empty.isEmpty(), "empty flag");
        assertContains(empty.getHtml(), "This file is empty");

        String malformed = "**unfinished\n[broken](https://example.com\n<script>alert(1)</script>";
        MarkdownDocument document = RENDERER.render(malformed, "rough.md");
        assertContains(document.getHtml(), "**unfinished");
        assertContains(document.getHtml(), "[broken](https://example.com");
        assertNotContains(document.getHtml(), "<script>");
        assertContains(document.getHtml(), "&lt;script&gt;");
    }

    private static void rendersInlineAndBlockMathOffline() {
        String markdown = "Energy follows $E = mc^2$ in the simplest case.\n\n"
                + "$$\n"
                + "\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\n"
                + "$$";

        MarkdownDocument document = RENDERER.render(markdown, "equations.md");
        String html = document.getHtml();

        assertContains(html, "<span class=\"math-inline\" role=\"math\"");
        assertContains(html, "aria-label=\"E = mc^2\"");
        assertContains(html, "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">");
        assertContains(html, "<msup><mi>c</mi><mn>2</mn></msup>");
        assertContains(html, "<div class=\"math-block\" role=\"math\"");
        assertContains(html, "<mfrac>");
        assertContains(html, "<msqrt>");
        assertContains(html, "<mo>±</mo>");
        assertNotContains(html, "\\frac");
        assertNotContains(html, "cdn.");
        assertNotContains(html, "<script");
    }

    private static void rendersAdvancedSemanticMath() {
        String markdown = "$\\frac{\\hat{x}_{t+1}}{\\sqrt[3]{y}}$ "
                + "$\\sum_{i=1}^{n} i$ "
                + "$\\left(\\mathbf{x}\\right)$ "
                + "$\\begin{pmatrix}a & b \\\\ c & d\\end{pmatrix}$\n\n"
                + "$\\begin{cases}x & \\text{if } x \\ge 0 \\\\ "
                + "-x & \\text{otherwise}\\end{cases}$\n\n"
                + "$m_t \\in \\{1,\\dots,K\\}$ "
                + "$P_\\perp = I - \\tfrac1K\\mathbf{1}\\mathbf{1}^\\top$ "
                + "$\\mathcal{L} = -\\nabla_\\theta \\log P(r_t \\mid c_t)$ "
                + "$\\sim\\!60\\times$ and $81\\%$.";

        String html = RENDERER.render(markdown, "advanced-math.md").getHtml();

        assertContains(html, "<mfrac>");
        assertContains(html, "<mover accent=\"true\">");
        assertContains(html, "<mroot><mrow><mi>y</mi></mrow><mrow><mn>3</mn></mrow></mroot>");
        assertContains(html, "<munderover>");
        assertContains(html, "<mo fence=\"true\" stretchy=\"true\">(</mo>");
        assertContains(html, "<mo fence=\"true\" stretchy=\"true\">)</mo>");
        assertContains(
                html,
                "<mtable class=\"math-fence\" rowspacing=\"0\" columnspacing=\"0\">"
                        + "<mtr><mtd><mo fence=\"true\">⎛</mo></mtd></mtr>"
                        + "<mtr><mtd><mo fence=\"true\">⎝</mo></mtd></mtr></mtable>");
        assertContains(html, "<mo class=\"math-fence-mirror\" fence=\"true\">⎛</mo>");
        assertContains(html, "<mo class=\"math-fence-mirror\" fence=\"true\">⎝</mo>");
        assertContains(html, "<mo fence=\"true\">⎧</mo>");
        assertContains(html, "<mo fence=\"true\">⎩</mo>");
        assertContains(html, "<mtable>");
        assertContains(html, "<mtext>if</mtext><mspace width=\"0.28em\"></mspace>");
        assertContains(html, "<mo>∈</mo>");
        assertContains(html, "<mo>…</mo>");
        assertContains(html, "<mo>⊥</mo>");
        assertContains(html, "<mo>⊤</mo>");
        assertContains(html, "<mstyle mathvariant=\"script\"><mrow><mi>L</mi></mrow></mstyle>");
        assertContains(html, "<mi>∇</mi>");
        assertContains(html, "<mo>|</mo>");
        assertContains(html, "<mo>∼</mo>");
        assertContains(html, "<mo>×</mo>");
        assertContains(html, "<mo>%</mo>");
        assertNotContains(html, "<mfenced");
        assertNotContains(html, "<mtext>\\");
    }

    private static void parsesSoftWrappedMathAndPreservesFormulaLikeUnderscores() {
        String markdown = "With $M_{(q,a),m} =\n"
                + "P(r{=}{+}1\\mid q,a,m)$ and $P_\\perp = I$.\n\n"
                + "Raw notation: e_{t+1} ≤ τ·e_t + η_t, η_max, p_stay, and ‖z_i−z_j‖.\n\n"
                + "_Intentional emphasis_ remains semantic.";

        String html = RENDERER.render(markdown, "soft-wrap.md").getHtml();

        assertContains(html, "<msub><mi>M</mi>");
        assertContains(html, "<msub><mi>P</mi><mo>⊥</mo></msub>");
        assertContains(html, "</span> and <span class=\"math-inline\"");
        assertContains(html, "e_{t+1} ≤ τ·e_t + η_t");
        assertContains(html, "η_max");
        assertContains(html, "p_stay");
        assertContains(html, "‖z_i−z_j‖");
        assertContains(html, "<em>Intentional emphasis</em>");
        assertNotContains(html, "aria-label=\" and \"");
        assertNotContains(html, "<em>{t+1} ≤ τ·e</em>");
        assertNotContains(html, "<em>i−z</em>");
    }

    private static void fallsBackWhenMathExceedsDepthOrNodeBudgets() {
        String nested = repeat("{", 65) + "x" + repeat("}", 65);
        String oversized = repeat("x", 4097);
        String html = RENDERER.render(
                "$" + nested + "$\n\n$" + oversized + "$",
                "bounded-math.md").getHtml();

        assertEquals(2, occurrences(html, "<mtext>"));
        assertContains(html, nested);
        assertContains(html, oversized);
    }

    private static void fallsBackWhenUnbracedMathNestingExceedsDepthBudget() {
        String nested = repeat("\\sqrt", 20000) + "x";
        String html = RENDERER.render("$" + nested + "$", "unbraced-depth.md").getHtml();

        assertContains(html, "<mtext>" + nested + "</mtext>");
        assertNotContains(html, "<msqrt>");
    }

    private static void keepsMarkdownLookingLinesInsideOpenInlineMath() {
        String[] markers = {"-", "+", ">", "#"};
        for (String marker : markers) {
            String html = RENDERER.render(
                    "Formula $x =\n" + marker + " y$.",
                    "math-continuation.md").getHtml();

            assertContains(html, "<p>Formula <span class=\"math-inline\"");
            assertNotContains(html, "$x");
            assertNotContains(html, "<ul>");
            assertNotContains(html, "<blockquote>");
            assertNotContains(html, "<h1");
        }
    }

    private static void rejectsMalformedDelimiterCommands() {
        String html = RENDERER.render(
                "Bad fence $\\left(x\\rightfoo$.",
                "malformed-fence.md").getHtml();

        assertContains(html, "<mtext>\\left(x\\rightfoo</mtext>");
        assertNotContains(html, "<script");
    }

    private static void preservesSupplementaryUnicodeMath() {
        String html = RENDERER.render(
                "$𝛼 + 𝟙$",
                "unicode-math.md").getHtml();

        assertContains(html, "<mi>𝛼</mi><mo>+</mo><mn>𝟙</mn>");
        assertNotContains(html, "�");
    }

    private static void alignsUnbracedArgumentsAndNamedOperators() {
        String html = RENDERER.render(
                "$\\sqrt x^2 + \\ln x + \\exp y$",
                "math-parity.md").getHtml();

        assertContains(html, "<msup><msqrt><mi>x</mi></msqrt><mn>2</mn></msup>");
        assertContains(html, "<mo>ln</mo>");
        assertContains(html, "<mo>exp</mo>");
        assertNotContains(html, "<mtext>");
    }

    private static String repeat(String value, int count) {
        StringBuilder output = new StringBuilder(value.length() * count);
        for (int index = 0; index < count; index++) {
            output.append(value);
        }
        return output.toString();
    }

    private static int occurrences(String value, String needle) {
        int count = 0;
        int cursor = 0;
        while ((cursor = value.indexOf(needle, cursor)) >= 0) {
            count++;
            cursor += needle.length();
        }
        return count;
    }

    private static void highlightsRecognizedFencedLanguagesSafely() {
        String markdown = "```kotlin\n"
                + "// A local note\n"
                + "data class Note(val title: String = \"Luma\", val count: Int = 2)\n"
                + "```\n\n"
                + "```json\n"
                + "{\"ready\": true, \"count\": 3}\n"
                + "```\n\n"
                + "```plaintext\n"
                + "<script>alert('safe')</script>\n"
                + "```";

        String html = RENDERER.render(markdown, "code.md").getHtml();

        assertContains(html, "<code class=\"language-kotlin\">");
        assertContains(html, "<span class=\"tok-keyword\">data</span>");
        assertContains(html, "<span class=\"tok-type\">Note</span>");
        assertContains(html, "<span class=\"tok-comment\">// A local note</span>");
        assertContains(html, "<span class=\"tok-string\">&quot;Luma&quot;</span>");
        assertContains(html, "<span class=\"tok-number\">2</span>");
        assertContains(html, "<code class=\"language-json\">");
        assertContains(html, "<span class=\"tok-literal\">true</span>");
        assertContains(html, "&lt;script&gt;alert(&#39;safe&#39;)&lt;/script&gt;");
        assertNotContains(html, "<script>");
    }

    private static void linksFootnoteReferencesDefinitionsAndBacklinks() {
        String markdown = "A grounded note[^source] can cite twice[^source] "
                + "and remain local[^local]. Unknown[^missing].\n\n"
                + "[^source]: Android’s document provider grants one file at a time.\n"
                + "[^local]: **Nothing leaves** the device.";

        String html = RENDERER.render(markdown, "footnotes.md").getHtml();

        assertContains(html, "<sup class=\"footnote-ref\"><a id=\"fnref-source\"");
        assertContains(html, "href=\"#fn-source\" aria-label=\"Footnote 1\">1</a></sup>");
        assertContains(html, "id=\"fnref-source-2\"");
        assertContains(html, "<section class=\"footnotes\" aria-label=\"Footnotes\">");
        assertContains(html, "<li id=\"fn-source\">");
        assertContains(html, "Android’s document provider grants one file at a time.");
        assertContains(html, "<a class=\"footnote-backref\" href=\"#fnref-source\"");
        assertContains(html, "<a class=\"footnote-backref\" href=\"#fnref-source-2\"");
        assertContains(html, "<li id=\"fn-local\">");
        assertContains(html, "<strong>Nothing leaves</strong> the device.");
        assertContains(html, "Unknown[^missing]");
        assertNotContains(html, "[^source]:");
        assertNotContains(html, "[^local]:");
    }

    private static void assertContains(String actual, String expected) {
        if (!actual.contains(expected)) {
            throw new AssertionError("Expected output to contain: " + expected
                    + "\nActual output:\n" + actual);
        }
    }

    private static void assertNotContains(String actual, String unexpected) {
        if (actual.contains(unexpected)) {
            throw new AssertionError("Expected output not to contain: " + unexpected
                    + "\nActual output:\n" + actual);
        }
    }

    private static void assertEquals(Object expected, Object actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("Expected <" + expected + "> but was <" + actual + ">");
        }
    }

    private static void assertTrue(boolean value, String label) {
        if (!value) {
            throw new AssertionError("Expected true: " + label);
        }
    }
}
