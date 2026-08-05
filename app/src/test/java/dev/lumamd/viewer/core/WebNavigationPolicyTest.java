package dev.lumamd.viewer.core;

public final class WebNavigationPolicyTest {
    private WebNavigationPolicyTest() {
    }

    public static void main(String[] args) {
        assertDecision(WebNavigationPolicy.Decision.NATIVE_ACTION, "luma", "open");
        assertDecision(WebNavigationPolicy.Decision.ALLOW_INTERNAL, "https", "luma.local");
        assertDecision(WebNavigationPolicy.Decision.ALLOW_INTERNAL, null, null);
        assertDecision(WebNavigationPolicy.Decision.OPEN_EXTERNAL, "https", "example.com");
        assertDecision(WebNavigationPolicy.Decision.OPEN_EXTERNAL, "http", "example.com");
        assertDecision(WebNavigationPolicy.Decision.OPEN_EXTERNAL, "mailto", null);
        assertDecision(WebNavigationPolicy.Decision.BLOCK, "javascript", null);
        assertDecision(WebNavigationPolicy.Decision.BLOCK, "file", null);
        assertDecision(WebNavigationPolicy.Decision.BLOCK, "content", null);
        assertDecision(WebNavigationPolicy.Decision.BLOCK, "intent", null);
        System.out.println("WebNavigationPolicyTest passed");
    }

    private static void assertDecision(
            WebNavigationPolicy.Decision expected,
            String scheme,
            String host) {
        WebNavigationPolicy.Decision actual = WebNavigationPolicy.decide(scheme, host);
        if (actual != expected) {
            throw new AssertionError(
                    "Expected " + expected + " for " + scheme + "://" + host
                            + " but was " + actual);
        }
    }
}
