package dev.lumamd.viewer.core;

final class AppIcons {
    private static final String START = "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\">";
    private static final String END = "</svg>";

    private AppIcons() {
    }

    static String mark() {
        return "<svg class=\"app-mark\" viewBox=\"0 0 40 40\" aria-hidden=\"true\">"
                + "<rect x=\"1\" y=\"1\" width=\"38\" height=\"38\" rx=\"12\" fill=\"currentColor\"/>"
                + "<path d=\"M12 10h11l6 6v14H12z\" fill=\"none\" stroke=\"white\" "
                + "stroke-width=\"2.2\" stroke-linejoin=\"round\"/>"
                + "<path d=\"M23 10v7h6M16 21h9M16 25h7\" fill=\"none\" stroke=\"white\" "
                + "stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
                + "</svg>";
    }

    static String folder() {
        return START + "<path d=\"M3 7.5h6l2 2h10v8.5a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"
                + "M3 10h18\"/>" + END;
    }

    static String file() {
        return START + "<path d=\"M6 3h8l4 4v14H6zM14 3v5h4M9 13h6M9 17h4\"/>" + END;
    }

    static String focus() {
        return START + "<path d=\"M8 3H4a1 1 0 0 0-1 1v4M16 3h4a1 1 0 0 1 1 1v4"
                + "M8 21H4a1 1 0 0 1-1-1v-4M16 21h4a1 1 0 0 0 1-1v-4"
                + "M8 12h8\"/>" + END;
    }

    static String shield() {
        return START + "<path d=\"M12 3 5 6v5c0 4.6 2.8 8 7 10 4.2-2 7-5.4 7-10V6z"
                + "M9 12l2 2 4-5\"/>" + END;
    }

    static String lock() {
        return START + "<rect x=\"5\" y=\"10\" width=\"14\" height=\"10\" rx=\"2\"/>"
                + "<path d=\"M8 10V7a4 4 0 0 1 8 0v3\"/>" + END;
    }

    static String clock() {
        return START + "<circle cx=\"12\" cy=\"12\" r=\"9\"/>"
                + "<path d=\"M12 7v5l3 2\"/>" + END;
    }

    static String storage() {
        return START + "<ellipse cx=\"12\" cy=\"6\" rx=\"8\" ry=\"3\"/>"
                + "<path d=\"M4 6v6c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6\"/>"
                + END;
    }

    static String outline() {
        return START + "<path d=\"M9 6h12M9 12h12M9 18h12M3 6h.01M3 12h.01M3 18h.01\"/>"
                + END;
    }

    static String type() {
        return START + "<path d=\"M4 6V4h10v2M9 4v16M6 20h6M15 10v-1h6v1M18 9v11M16 20h4\"/>" + END;
    }

    static String theme(String theme) {
        if ("light".equals(theme)) {
            return START + "<path d=\"M20 15.5A8 8 0 0 1 8.5 4 8 8 0 1 0 20 15.5Z\"/>" + END;
        }
        return START + "<circle cx=\"12\" cy=\"12\" r=\"4\"/>"
                + "<path d=\"M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4"
                + "M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4\"/>" + END;
    }

    static String close() {
        return START + "<path d=\"m6 6 12 12M18 6 6 18\"/>" + END;
    }

    static String actions() {
        return START + "<circle cx=\"5\" cy=\"12\" r=\"1\"/>"
                + "<circle cx=\"12\" cy=\"12\" r=\"1\"/>"
                + "<circle cx=\"19\" cy=\"12\" r=\"1\"/>" + END;
    }

    static String copy() {
        return START + "<rect x=\"8\" y=\"8\" width=\"11\" height=\"12\" rx=\"2\"/>"
                + "<path d=\"M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v10"
                + "a2 2 0 0 0 2 2h2\"/>" + END;
    }

    static String clipboard() {
        return START + "<path d=\"M9 5H6a2 2 0 0 0-2 2v13h16V7a2 2 0 0 0-2-2h-3\"/>"
                + "<rect x=\"8\" y=\"3\" width=\"8\" height=\"4\" rx=\"2\"/>"
                + "<path d=\"M8 12h8M8 16h6\"/>" + END;
    }

    static String share() {
        return START + "<circle cx=\"18\" cy=\"5\" r=\"3\"/>"
                + "<circle cx=\"6\" cy=\"12\" r=\"3\"/>"
                + "<circle cx=\"18\" cy=\"19\" r=\"3\"/>"
                + "<path d=\"m8.6 10.5 6.8-4M8.6 13.5l6.8 4\"/>" + END;
    }
}
