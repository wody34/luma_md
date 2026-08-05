package dev.lumamd.viewer.core;

import java.util.Arrays;

public final class AppPageBuilderTest {
    private AppPageBuilderTest() {
    }

    public static void main(String[] args) {
        String scope = args.length == 0 ? "all" : args[0];
        if ("layout".equals(scope)) {
            mobileReaderUsesWideContentColumn();
            System.out.println("AppPageBuilderTest layout passed");
            return;
        }
        welcomeExposesPrimaryReadingActions();
        documentExposesMetadataOutlineAndControls();
        System.out.println("AppPageBuilderTest all passed");
    }

    private static void welcomeExposesPrimaryReadingActions() {
        String html = new AppPageBuilder().buildWelcome("dark", 100, false);

        assertContains(html, "data-theme=\"dark\"");
        assertContains(html, "LOCAL MARKDOWN READER");
        assertContains(html, "Give every note a quiet place to land.");
        assertContains(html, "href=\"luma://open\"");
        assertContains(html, "aria-label=\"Open markdown\"");
        assertContains(html, "href=\"luma://theme\"");
        assertContains(html, "Nothing leaves your device.");
        assertContains(html, "--canvas:#0E0D13");
        assertContains(html, ".brand{min-width:0;min-height:48px");
        assertContains(html, ".privacy-note{display:flex");
        assertContains(html, "font-size:12px;font-weight:750");
        assertContains(
                html,
                "Content-Security-Policy\" content=\"default-src 'none'; "
                        + "script-src 'none'; connect-src 'none';");
    }

    private static void documentExposesMetadataOutlineAndControls() {
        MarkdownDocument document = new MarkdownDocument(
                "<h1 id=\"release-notes\">Release Notes</h1><p>Ready to ship.</p>",
                "Release Notes",
                210,
                false,
                Arrays.asList(new MarkdownDocument.Heading(
                        1,
                        "release-notes",
                        "Release Notes")));

        String html = new AppPageBuilder().buildDocument(
                document,
                "luma-release-notes.md",
                2048,
                "light",
                112);

        assertContains(html, "data-theme=\"light\"");
        assertContains(html, "data-type-scale=\"112\"");
        assertContains(html, "LOCAL FILE");
        assertContains(html, "luma-release-notes.md");
        assertContains(html, "2.0 KB");
        assertContains(html, "2 min read");
        assertContains(html, "id=\"outline\"");
        assertContains(html, "href=\"#release-notes\"");
        assertContains(html, "href=\"luma://type\"");
        assertContains(html, "href=\"luma://theme\"");
        assertContains(html, "href=\"luma://open\"");
        assertContains(html, "aria-label=\"Change text size\"");
        assertContains(html, ".tool-dock a{width:66px;min-height:58px");
        assertContains(html, "scroll-margin-top:120px");
        assertContains(html, "--tertiary:#665F70");
        assertContains(html, "--accent-ink:#FFFFFF");
        assertContains(html, "color:var(--accent-ink)");
        assertContains(
                html,
                "Content-Security-Policy\" content=\"default-src 'none'; "
                        + "script-src 'none'; connect-src 'none';");
    }

    private static void mobileReaderUsesWideContentColumn() {
        MarkdownDocument document = new MarkdownDocument(
                "<p>A long document needs room to breathe without wasting phone width.</p>",
                "Dense reading",
                1200,
                false,
                Arrays.<MarkdownDocument.Heading>asList());

        String html = new AppPageBuilder().buildDocument(
                document,
                "long-reading.md",
                16384,
                "dark",
                100);

        assertContains(html,
                ".reader-wrap{width:min(100%,920px);margin:auto;padding:32px 10px 126px}");
        assertContains(html,
                ".reader-surface{padding:24px 16px;border:1px solid var(--border-soft)");
        assertContains(html, ".document-head{padding:0 4px 22px}");
    }

    private static void assertContains(String actual, String expected) {
        if (!actual.contains(expected)) {
            throw new AssertionError("Expected output to contain: " + expected);
        }
    }
}
