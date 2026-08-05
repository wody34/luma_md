package dev.lumamd.viewer.core;

public final class WebNavigationPolicy {
    public enum Decision {
        ALLOW_INTERNAL,
        NATIVE_ACTION,
        OPEN_EXTERNAL,
        BLOCK
    }

    private WebNavigationPolicy() {
    }

    public static Decision decide(String scheme, String host) {
        if (scheme == null || scheme.isEmpty()) {
            return Decision.ALLOW_INTERNAL;
        }
        if ("luma".equals(scheme)) {
            return Decision.NATIVE_ACTION;
        }
        if ("https".equals(scheme) && "luma.local".equals(host)) {
            return Decision.ALLOW_INTERNAL;
        }
        if ("http".equals(scheme) || "https".equals(scheme) || "mailto".equals(scheme)) {
            return Decision.OPEN_EXTERNAL;
        }
        return Decision.BLOCK;
    }
}
