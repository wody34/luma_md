package dev.lumamd.viewer.core;

import java.lang.reflect.Method;

public final class ReaderActionsTest {
    private ReaderActionsTest() {
    }

    public static void main(String[] args) throws Exception {
        MarkdownDocument document = new MarkdownRenderer().render(
                "# Shared note\n\nOriginal **Markdown** stays intact.",
                "shared-note.md");
        AppPageBuilder builder = new AppPageBuilder();

        String welcome = builder.buildWelcome("dark", 100, true);
        assertContains(welcome, "href=\"luma://paste\"");
        assertContains(welcome, "aria-label=\"New memo from clipboard\"");

        String reader = builder.buildDocument(
                document,
                "shared-note.md",
                49,
                "dark",
                100);
        StringBuilder interactionFailures = new StringBuilder();
        String brand = slice(reader, "<a class=\"brand\"", "</a>");
        expectContains(brand, "href=\"luma://home\"", interactionFailures);
        expectContains(
                reader,
                "body{margin:0;min-height:100vh;-webkit-user-select:none;user-select:none;",
                interactionFailures);
        expectContains(
                reader,
                ".reader-surface{-webkit-user-select:text;user-select:text;",
                interactionFailures);
        assertContains(reader, "href=\"#actions\"");
        assertContains(reader, "aria-label=\"More reading tools\"");
        assertContains(reader, "id=\"actions\"");
        assertContains(reader, "aria-label=\"Reading tools\"");
        assertContains(reader, "href=\"luma://copy\"");
        assertContains(reader, "aria-label=\"Copy Markdown\"");
        assertContains(reader, "href=\"luma://paste\"");
        assertContains(reader, "aria-label=\"New memo from clipboard\"");
        assertContains(reader, "href=\"luma://share\"");
        assertContains(reader, "aria-label=\"Share Markdown\"");

        String dock = slice(reader, "<nav class=\"tool-dock\"", "</nav>");
        assertContains(dock, "href=\"luma://copy\"");
        assertContains(dock, "href=\"luma://share\"");
        assertContains(dock, "href=\"#actions\"");
        assertContains(dock, "href=\"luma://open\"");
        assertNotContains(dock, "href=\"#outline\"");
        assertNotContains(dock, "href=\"luma://type\"");

        String actions = slice(reader, "<aside id=\"actions\"", "</aside>");
        assertContains(actions, "href=\"#outline\"");
        assertContains(actions, "href=\"luma://type\"");
        assertContains(actions, "href=\"luma://paste\"");
        assertNotContains(actions, "href=\"luma://copy\"");
        assertNotContains(actions, "href=\"luma://share\"");

        Method getSource = MarkdownDocument.class.getMethod("getSource");
        String source = (String) getSource.invoke(document);
        assertEquals(
                "# Shared note\n\nOriginal **Markdown** stays intact.",
                source);
        assertNoFailures(interactionFailures);

        System.out.println("ReaderActionsTest all passed");
    }

    private static void assertContains(String actual, String expected) {
        if (!actual.contains(expected)) {
            throw new AssertionError("Expected output to contain: " + expected);
        }
    }

    private static void assertNotContains(String actual, String unexpected) {
        if (actual.contains(unexpected)) {
            throw new AssertionError("Expected output not to contain: " + unexpected);
        }
    }

    private static String slice(String value, String start, String end) {
        int from = value.indexOf(start);
        int to = value.indexOf(end, from);
        if (from < 0 || to < 0) {
            throw new AssertionError("Missing slice: " + start + " … " + end);
        }
        return value.substring(from, to + end.length());
    }

    private static void assertEquals(String expected, String actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError(
                    "Expected source:\n" + expected + "\nActual source:\n" + actual);
        }
    }

    private static void expectContains(
            String actual,
            String expected,
            StringBuilder failures) {
        if (!actual.contains(expected)) {
            failures.append("Expected interaction contract to contain: ")
                    .append(expected)
                    .append('\n');
        }
    }

    private static void assertNoFailures(StringBuilder failures) {
        if (failures.length() > 0) {
            throw new AssertionError(failures.toString());
        }
    }
}
