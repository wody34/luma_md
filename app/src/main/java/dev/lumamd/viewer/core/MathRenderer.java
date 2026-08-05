package dev.lumamd.viewer.core;

final class MathRenderer {
    private MathRenderer() {
    }

    static String renderInline(String expression) {
        return "<span class=\"math-inline\" role=\"math\" aria-label=\""
                + InlineMarkdown.escape(label(expression)) + "\">"
                + math(expression) + "</span>";
    }

    static String renderBlock(String expression) {
        return "<div class=\"math-block\" role=\"math\" aria-label=\""
                + InlineMarkdown.escape(label(expression)) + "\">"
                + math(expression) + "</div>";
    }

    private static String math(String expression) {
        return "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">"
                + new MathMLParser(expression).render()
                + "</math>";
    }

    private static String label(String expression) {
        String value = expression
                .replace("\\frac", "fraction ")
                .replace("\\tfrac", "fraction ")
                .replace("\\sqrt", "square root ")
                .replace("\\sum", "sum ")
                .replace("\\prod", "product ")
                .replace("\\int", "integral ")
                .replace("\\mathrm", "")
                .replace("\\mathbf", "")
                .replace("\\mathcal", "")
                .replace("\\operatorname", "")
                .replace('{', '(')
                .replace('}', ')');
        StringBuilder printable = new StringBuilder(value.length());
        for (int index = 0; index < value.length(); index++) {
            char character = value.charAt(index);
            if (character >= 0x20 && character != 0x7F) {
                printable.append(character);
            }
        }
        String compact = printable.toString().replaceAll("\\s+", " ").trim();
        return compact.isEmpty() ? "formula" : compact;
    }
}
