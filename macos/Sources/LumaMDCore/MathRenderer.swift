import Foundation

internal enum MathRenderer {
    static func renderInline(_ expression: String) -> String {
        "<span class=\"math-inline\" role=\"math\" aria-label=\"\(escape(label(for: expression)))\">\(math(for: expression))</span>"
    }

    static func renderBlock(_ expression: String) -> String {
        "<div class=\"math-block\" role=\"math\" aria-label=\"\(escape(label(for: expression)))\">\(math(for: expression))</div>"
    }

    private static func math(for expression: String) -> String {
        var parser = MathMLParser(expression)
        return "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(parser.render())</math>"
    }

    private static func label(for expression: String) -> String {
        let replacements = [
            ("\\frac", "fraction "), ("\\sqrt", "square root "),
            ("\\sum", "sum "), ("\\prod", "product "), ("\\int", "integral "),
            ("\\mathrm", ""), ("\\mathbf", ""), ("\\operatorname", ""),
            ("{", "("), ("}", ")"),
        ]
        var value = expression.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F }
            .map(String.init).joined()
        for (source, replacement) in replacements {
            value = value.replacingOccurrences(of: source, with: replacement)
        }
        let compact = value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? "formula" : compact
    }

    private static func escape(_ value: String) -> String {
        InlineMarkdown.escape(value)
    }
}
