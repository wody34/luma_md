package dev.lumamd.viewer.core;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;

public final class ShareContractTest {
    private ShareContractTest() {
    }

    public static void main(String[] args) throws IOException {
        String activity = read("app/src/main/java/dev/lumamd/viewer/MainActivity.java");
        String manifest = read("app/src/main/AndroidManifest.xml");
        String copy = slice(activity, "private void copyCurrentMarkdown()", "\n    }\n\n");
        String share = slice(activity, "private void shareCurrentMarkdown()", "\n    }\n\n");

        assertContains(copy, "ClipData.newPlainText");

        assertContains(share, "new Intent(Intent.ACTION_SEND)");
        assertContains(share, ".setType(\"text/markdown\")");
        assertContains(share, "Intent.EXTRA_STREAM");
        assertContains(share, "Intent.FLAG_GRANT_READ_URI_PERMISSION");
        assertContains(share, "ClipData.newRawUri");
        assertNotContains(share, "Intent.EXTRA_TEXT");

        String provider = slice(manifest, "<provider", "</provider>");
        assertContains(provider, "android:name=\".MarkdownShareProvider\"");
        assertContains(provider, "android:authorities=\"dev.lumamd.viewer.share\"");
        assertContains(provider, "android:exported=\"false\"");
        assertContains(provider, "android:grantUriPermissions=\"true\"");

        System.out.println("ShareContractTest all passed");
    }

    private static String read(String path) throws IOException {
        return new String(
                Files.readAllBytes(Paths.get(path)),
                StandardCharsets.UTF_8);
    }

    private static String slice(String value, String start, String end) {
        int from = value.indexOf(start);
        int to = value.indexOf(end, from);
        if (from < 0 || to < 0) {
            throw new AssertionError("Missing contract section: " + start);
        }
        return value.substring(from, to + end.length());
    }

    private static void assertContains(String actual, String expected) {
        if (!actual.contains(expected)) {
            throw new AssertionError("Expected contract to contain: " + expected);
        }
    }

    private static void assertNotContains(String actual, String unexpected) {
        if (actual.contains(unexpected)) {
            throw new AssertionError("Expected contract not to contain: " + unexpected);
        }
    }
}
