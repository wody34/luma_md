import Foundation

indirect enum MathMLNode {
    case row([MathMLNode])
    case identifier(String)
    case number(String)
    case operatorSymbol(String, limits: Bool)
    case text(String)
    case textLiteral(String)
    case fraction(MathMLNode, MathMLNode)
    case squareRoot(MathMLNode)
    case root(MathMLNode, MathMLNode)
    case scripts(MathMLNode, subscript: MathMLNode?, superscript: MathMLNode?)
    case fenced(left: String?, body: MathMLNode, right: String?)
    case accent(MathMLNode, String)
    case style(MathMLNode, variant: String)
    case operatorName(String)
    case table(rows: [[MathMLNode]], alignment: String?, left: String?, right: String?)

    func render() -> String {
        switch self {
        case .row(let nodes):
            let content = nodes.map { $0.render() }.joined()
            if nodes.count == 1 { return content }
            return "<mrow>\(content)</mrow>"
        case .identifier(let value):
            return "<mi>\(escape(value))</mi>"
        case .number(let value):
            return "<mn>\(escape(value))</mn>"
        case .operatorSymbol(let value, _):
            return "<mo>\(escape(value))</mo>"
        case .text(let value):
            return "<mtext>\(escape(value))</mtext>"
        case .textLiteral(let value):
            return renderTextLiteral(value)
        case .fraction(let numerator, let denominator):
            return "<mfrac>\(numerator.render())\(denominator.render())</mfrac>"
        case .squareRoot(let body):
            return "<msqrt>\(body.render())</msqrt>"
        case .root(let body, let index):
            return "<mroot>\(body.render())\(index.render())</mroot>"
        case .scripts(let base, let lower, let upper):
            return renderScripts(base: base, lower: lower, upper: upper)
        case .fenced(let left, let body, let right):
            return "<mrow>\(fence(left))\(body.render())\(fence(right))</mrow>"
        case .accent(let body, let accent):
            return "<mover accent=\"true\">\(body.render())<mo>\(escape(accent))</mo></mover>"
        case .style(let body, let variant):
            return "<mstyle mathvariant=\"\(variant)\">\(body.render())</mstyle>"
        case .operatorName(let value):
            return "<mo>\(escape(value))</mo>"
        case .table(let rows, let alignment, let left, let right):
            let attribute = alignment.map { " columnalign=\"\($0)\"" } ?? ""
            let body = rows.map { row in
                "<mtr>" + row.map { "<mtd>\($0.render())</mtd>" }.joined() + "</mtr>"
            }.joined()
            let table = "<mtable\(attribute)>\(body)</mtable>"
            guard left != nil || right != nil else { return table }
            return "<mrow>\(fence(left))\(table)\(fence(right))</mrow>"
        }
    }

    private var usesLimits: Bool {
        if case .operatorSymbol(_, let limits) = self { return limits }
        return false
    }

    private func renderTextLiteral(_ value: String) -> String {
        var nodes = [String]()
        var text = ""
        for character in value {
            if character == " " {
                if !text.isEmpty {
                    nodes.append("<mtext>\(escape(text))</mtext>")
                    text = ""
                }
                nodes.append("<mspace width=\"0.28em\"></mspace>")
            } else {
                text.append(character)
            }
        }
        if !text.isEmpty {
            nodes.append("<mtext>\(escape(text))</mtext>")
        }
        return nodes.count == 1 ? nodes[0] : "<mrow>\(nodes.joined())</mrow>"
    }

    private func renderScripts(base: MathMLNode, lower: MathMLNode?, upper: MathMLNode?) -> String {
        switch (lower, upper) {
        case let (.some(lower), .some(upper)) where base.usesLimits:
            return "<munderover>\(base.render())\(lower.render())\(upper.render())</munderover>"
        case let (.some(lower), .none) where base.usesLimits:
            return "<munder>\(base.render())\(lower.render())</munder>"
        case let (.none, .some(upper)) where base.usesLimits:
            return "<mover>\(base.render())\(upper.render())</mover>"
        case let (.some(lower), .some(upper)):
            return "<msubsup>\(base.render())\(lower.render())\(upper.render())</msubsup>"
        case let (.some(lower), .none):
            return "<msub>\(base.render())\(lower.render())</msub>"
        case let (.none, .some(upper)):
            return "<msup>\(base.render())\(upper.render())</msup>"
        case (.none, .none):
            return base.render()
        }
    }

    private func fence(_ delimiter: String?) -> String {
        guard let delimiter else { return "" }
        return "<mo fence=\"true\" stretchy=\"true\">\(escape(delimiter))</mo>"
    }

    private func escape(_ value: String) -> String {
        InlineMarkdown.escape(value)
    }
}
