package dev.lumamd.viewer.core;

public final class SafeAreaInsets {
    private final int left;
    private final int top;
    private final int right;
    private final int bottom;

    private SafeAreaInsets(int left, int top, int right, int bottom) {
        this.left = left;
        this.top = top;
        this.right = right;
        this.bottom = bottom;
    }

    public static SafeAreaInsets none() {
        return new SafeAreaInsets(0, 0, 0, 0);
    }

    public static SafeAreaInsets resolve(
            int systemLeft,
            int systemTop,
            int systemRight,
            int systemBottom,
            int cutoutLeft,
            int cutoutTop,
            int cutoutRight,
            int cutoutBottom) {
        return new SafeAreaInsets(
                edge(systemLeft, cutoutLeft),
                edge(systemTop, cutoutTop),
                edge(systemRight, cutoutRight),
                edge(systemBottom, cutoutBottom));
    }

    public int getLeft() {
        return left;
    }

    public int getTop() {
        return top;
    }

    public int getRight() {
        return right;
    }

    public int getBottom() {
        return bottom;
    }

    private static int edge(int systemInset, int displayCutoutInset) {
        return Math.max(0, Math.max(systemInset, displayCutoutInset));
    }
}
