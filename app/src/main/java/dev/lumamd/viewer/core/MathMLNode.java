package dev.lumamd.viewer.core;

import java.util.List;

final class MathMLNode {
    private final String html;
    private final boolean limits;

    private MathMLNode(String html, boolean limits) {
        this.html = html;
        this.limits = limits;
    }

    static MathMLNode row(List<MathMLNode> nodes) {
        StringBuilder html = new StringBuilder("<mrow>");
        for (MathMLNode node : nodes) {
            html.append(node.render());
        }
        return new MathMLNode(html.append("</mrow>").toString(), false);
    }

    static MathMLNode identifier(String value) {
        return element("mi", value, false);
    }

    static MathMLNode number(String value) {
        return element("mn", value, false);
    }

    static MathMLNode operator(String value) {
        return element("mo", value, false);
    }

    static MathMLNode limitOperator(String value) {
        return element("mo", value, true);
    }

    static MathMLNode text(String value) {
        return element("mtext", value, false);
    }

    static MathMLNode spacedText(String value) {
        List<MathMLNode> nodes = new java.util.ArrayList<MathMLNode>();
        StringBuilder text = new StringBuilder();
        for (int index = 0; index < value.length(); index++) {
            char character = value.charAt(index);
            if (character == ' ') {
                if (text.length() > 0) {
                    nodes.add(text(text.toString()));
                    text.setLength(0);
                }
                nodes.add(new MathMLNode("<mspace width=\"0.28em\"></mspace>", false));
            } else {
                text.append(character);
            }
        }
        if (text.length() > 0) {
            nodes.add(text(text.toString()));
        }
        return nodes.size() == 1 ? nodes.get(0) : row(nodes);
    }

    static MathMLNode fraction(MathMLNode numerator, MathMLNode denominator) {
        return composite("mfrac", numerator, denominator);
    }

    static MathMLNode squareRoot(MathMLNode content) {
        return composite("msqrt", content);
    }

    static MathMLNode indexedRoot(MathMLNode content, MathMLNode index) {
        return composite("mroot", content, index);
    }

    static MathMLNode subscript(MathMLNode base, MathMLNode script) {
        return composite("msub", base, script);
    }

    static MathMLNode superscript(MathMLNode base, MathMLNode script) {
        return composite("msup", base, script);
    }

    static MathMLNode subSuperscript(
            MathMLNode base,
            MathMLNode subscript,
            MathMLNode superscript) {
        return composite("msubsup", base, subscript, superscript);
    }

    static MathMLNode under(MathMLNode base, MathMLNode script) {
        return composite("munder", base, script);
    }

    static MathMLNode over(MathMLNode base, MathMLNode script) {
        return composite("mover", base, script);
    }

    static MathMLNode underOver(
            MathMLNode base,
            MathMLNode underscript,
            MathMLNode overscript) {
        return composite("munderover", base, underscript, overscript);
    }

    static MathMLNode fenced(String open, String close, MathMLNode content) {
        return fenced(open, close, content, null);
    }

    static MathMLNode fenced(
            String open,
            String close,
            MathMLNode content,
            String minimumSize) {
        StringBuilder html = new StringBuilder("<mrow>");
        if (!open.isEmpty()) {
            html.append("<mo fence=\"true\" stretchy=\"true\"");
            if (minimumSize != null) {
                html.append(" minsize=\"")
                        .append(InlineMarkdown.escape(minimumSize))
                        .append("\"");
            }
            html.append(">")
                    .append(InlineMarkdown.escape(open))
                    .append("</mo>");
        }
        html.append(content.render());
        if (!close.isEmpty()) {
            html.append("<mo fence=\"true\" stretchy=\"true\"");
            if (minimumSize != null) {
                html.append(" minsize=\"")
                        .append(InlineMarkdown.escape(minimumSize))
                        .append("\"");
            }
            html.append(">")
                    .append(InlineMarkdown.escape(close))
                    .append("</mo>");
        }
        return new MathMLNode(html.append("</mrow>").toString(), false);
    }

    static MathMLNode environmentFenced(
            String open,
            String close,
            MathMLNode content,
            int rowCount) {
        return new MathMLNode(
                "<mrow>" + fenceTable(open, rowCount, true)
                        + content.render()
                        + fenceTable(close, rowCount, false)
                        + "</mrow>",
                false);
    }

    static MathMLNode accent(MathMLNode base, String mark) {
        return new MathMLNode(
                "<mover accent=\"true\">" + base.render() + operator(mark).render() + "</mover>",
                false);
    }

    static MathMLNode style(MathMLNode content, String variant) {
        return new MathMLNode(
                "<mstyle mathvariant=\"" + InlineMarkdown.escape(variant) + "\">"
                        + content.render() + "</mstyle>",
                false);
    }

    static MathMLNode table(List<List<MathMLNode>> rows) {
        StringBuilder html = new StringBuilder("<mtable>");
        for (List<MathMLNode> row : rows) {
            html.append("<mtr>");
            for (MathMLNode cell : row) {
                html.append("<mtd>").append(cell.render()).append("</mtd>");
            }
            html.append("</mtr>");
        }
        return new MathMLNode(html.append("</mtable>").toString(), false);
    }

    boolean hasLimits() {
        return limits;
    }

    String render() {
        return html;
    }

    private static MathMLNode element(String tag, String value, boolean limits) {
        return new MathMLNode(
                "<" + tag + ">" + InlineMarkdown.escape(value) + "</" + tag + ">",
                limits);
    }

    private static MathMLNode composite(String tag, MathMLNode... nodes) {
        StringBuilder html = new StringBuilder("<").append(tag).append('>');
        for (MathMLNode node : nodes) {
            html.append(node.render());
        }
        return new MathMLNode(html.append("</").append(tag).append('>').toString(), false);
    }

    private static String fenceTable(String delimiter, int rowCount, boolean opening) {
        if (delimiter.isEmpty()) {
            return "";
        }
        String top;
        String middle;
        String bottom;
        boolean mirrored = ")".equals(delimiter);
        if ("(".equals(delimiter) || mirrored) {
            top = "⎛";
            middle = "⎜";
            bottom = "⎝";
        } else if ("{".equals(delimiter)) {
            top = opening ? "⎧" : "⎫";
            middle = opening ? "⎨" : "⎬";
            bottom = opening ? "⎩" : "⎭";
        } else {
            return operator(delimiter).render();
        }

        int safeRows = Math.max(2, rowCount);
        StringBuilder html = new StringBuilder(
                "<mtable class=\"math-fence\" rowspacing=\"0\" columnspacing=\"0\">");
        for (int row = 0; row < safeRows; row++) {
            String piece;
            if (row == 0) {
                piece = top;
            } else if (row == safeRows - 1) {
                piece = bottom;
            } else if ("{".equals(delimiter) && row == safeRows / 2) {
                piece = middle;
            } else {
                piece = "(".equals(delimiter) || mirrored ? middle : "⎪";
            }
            html.append("<mtr><mtd><mo")
                    .append(mirrored ? " class=\"math-fence-mirror\"" : "")
                    .append(" fence=\"true\">")
                    .append(piece)
                    .append("</mo></mtd></mtr>");
        }
        return html.append("</mtable>").toString();
    }
}
