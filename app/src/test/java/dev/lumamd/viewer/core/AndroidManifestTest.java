package dev.lumamd.viewer.core;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;

public final class AndroidManifestTest {
    private AndroidManifestTest() {
    }

    public static void main(String[] args) throws IOException {
        String manifest = new String(
                Files.readAllBytes(Paths.get("app/src/main/AndroidManifest.xml")),
                StandardCharsets.UTF_8);

        assertContains(manifest, "android.intent.action.VIEW");
        assertContains(manifest, "android:mimeType=\"text/markdown\"");
        assertContains(manifest, "android:mimeType=\"text/x-markdown\"");
        assertContains(manifest, "android:mimeType=\"text/plain\"");
        assertContains(manifest, "android:scheme=\"content\"");
        assertContains(manifest, "android:scheme=\"file\"");
        for (String extension : new String[]{"md", "markdown", "mdown", "mkd", "mdx"}) {
            assertContains(manifest, "android:pathPattern=\".*\\\\." + extension + "\"");
        }

        System.out.println("AndroidManifestTest all passed");
    }

    private static void assertContains(String actual, String expected) {
        if (!actual.contains(expected)) {
            throw new AssertionError("Expected manifest to contain: " + expected);
        }
    }
}
