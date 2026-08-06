package dev.lumamd.viewer.core;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;

public final class SafeAreaInsetsTest {
    private SafeAreaInsetsTest() {
    }

    public static void main(String[] args) throws IOException {
        resolvesEveryEdgeFromSystemBarsAndDisplayCutouts();
        clampsMissingOrInvalidInsetsToZero();
        activityWiresAllContainerPaddingToWindowInsets();
        System.out.println("SafeAreaInsetsTest all passed");
    }

    private static void resolvesEveryEdgeFromSystemBarsAndDisplayCutouts() {
        SafeAreaInsets insets = SafeAreaInsets.resolve(
                0, 63, 0, 126,
                24, 90, 30, 0);

        assertEquals(24, insets.getLeft());
        assertEquals(90, insets.getTop());
        assertEquals(30, insets.getRight());
        assertEquals(126, insets.getBottom());
    }

    private static void clampsMissingOrInvalidInsetsToZero() {
        SafeAreaInsets insets = SafeAreaInsets.resolve(
                -1, -1, -1, -1,
                -1, -1, -1, -1);

        assertEquals(0, insets.getLeft());
        assertEquals(0, insets.getTop());
        assertEquals(0, insets.getRight());
        assertEquals(0, insets.getBottom());
    }

    private static void activityWiresAllContainerPaddingToWindowInsets() throws IOException {
        String source = new String(
                Files.readAllBytes(Paths.get(
                        "app/src/main/java/dev/lumamd/viewer/MainActivity.java")),
                StandardCharsets.UTF_8);

        assertContains(source, "setOnApplyWindowInsetsListener");
        assertContains(source, "WindowInsets.Type.systemBars()");
        assertContains(source, "WindowInsets.Type.displayCutout()");
        assertContains(source, "SafeAreaInsets.resolve(");
        assertContains(source, "safeInsets.getLeft()");
        assertContains(source, "safeInsets.getTop()");
        assertContains(source, "safeInsets.getRight()");
        assertContains(source, "safeInsets.getBottom()");
    }

    private static void assertContains(String actual, String expected) {
        if (!actual.contains(expected)) {
            throw new AssertionError("Expected source to contain: " + expected);
        }
    }

    private static void assertEquals(int expected, int actual) {
        if (expected != actual) {
            throw new AssertionError("Expected " + expected + " but was " + actual);
        }
    }
}
