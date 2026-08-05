import Foundation

struct MathMLParser {
    private enum Terminator {
        case end, group, index, rightDelimiter, environment
    }

    private let source: [Character]
    private var cursor = 0
    private var depth = 0
    private var nodeCount = 0

    private static let maximumDepth = 64
    private static let maximumNodeCount = 4_096

    init(_ expression: String) {
        source = Array(expression)
    }

    mutating func render() -> String {
        do {
            let nodes = try sequence(until: .end)
            guard cursor == source.count else { throw ParseError.invalid }
            return MathMLNode.row(nodes).render()
        } catch {
            return MathMLNode.text(String(source)).render()
        }
    }

    private mutating func sequence(until terminator: Terminator) throws -> [MathMLNode] {
        var nodes: [MathMLNode] = []
        while cursor < source.count {
            skipSpaces()
            guard cursor < source.count, !isAt(terminator) else { break }
            let base = try atom()
            nodes.append(try attachingScripts(to: base))
        }
        return nodes
    }

    private mutating func atom() throws -> MathMLNode {
        guard cursor < source.count,
              depth < Self.maximumDepth,
              nodeCount < Self.maximumNodeCount
        else {
            throw ParseError.invalid
        }
        depth += 1
        nodeCount += 1
        defer { depth -= 1 }

        let character = source[cursor]
        switch character {
        case "\\": return try command()
        case "{": return try group()
        case "^", "_", "}": throw ParseError.invalid
        default:
            if character.isNumber { return number() }
            cursor += 1
            if character.isLetter { return .identifier(String(character)) }
            return .operatorSymbol(String(character), limits: false)
        }
    }

    private mutating func number() -> MathMLNode {
        let start = cursor
        while cursor < source.count, source[cursor].isNumber { cursor += 1 }
        return .number(String(source[start..<cursor]))
    }

    private mutating func group() throws -> MathMLNode {
        guard take("{") else { throw ParseError.invalid }
        let nodes = try sequence(until: .group)
        guard take("}") else { throw ParseError.invalid }
        return .row(nodes)
    }

    private mutating func argument() throws -> MathMLNode {
        skipSpaces()
        guard cursor < source.count else { throw ParseError.invalid }
        return source[cursor] == "{" ? try group() : try atom()
    }

    private mutating func attachingScripts(to base: MathMLNode) throws -> MathMLNode {
        var lowerScript: MathMLNode?
        var upperScript: MathMLNode?
        while true {
            skipSpaces()
            guard cursor < source.count, source[cursor] == "_" || source[cursor] == "^" else { break }
            let marker = source[cursor]
            cursor += 1
            let script = try argument()
            if marker == "_" {
                guard lowerScript == nil else { throw ParseError.invalid }
                lowerScript = script
            } else {
                guard upperScript == nil else { throw ParseError.invalid }
                upperScript = script
            }
        }
        guard lowerScript != nil || upperScript != nil else { return base }
        return .scripts(base, subscript: lowerScript, superscript: upperScript)
    }

    private mutating func command() throws -> MathMLNode {
        guard take("\\"), cursor < source.count else { throw ParseError.invalid }
        guard source[cursor].isLetter else {
            let escaped = source[cursor]
            cursor += 1
            if escaped == "!" { return .row([]) }
            guard "{}()[]|%".contains(escaped) else { throw ParseError.invalid }
            return .operatorSymbol(String(escaped), limits: false)
        }
        let name = commandName()
        switch name {
        case "frac", "tfrac": return .fraction(try argument(), try argument())
        case "sqrt": return try squareRoot()
        case "text": return .textLiteral(try textArgument())
        case "mathrm": return .style(try argument(), variant: "normal")
        case "mathbf": return .style(try argument(), variant: "bold")
        case "mathcal": return .style(try argument(), variant: "script")
        case "operatorname": return .operatorName(try textArgument())
        case "hat": return .accent(try argument(), "^")
        case "bar", "overline": return .accent(try argument(), "¯")
        case "vec": return .accent(try argument(), "→")
        case "left": return try delimited()
        case "begin": return try environment(named: environmentName())
        case "right", "end": throw ParseError.invalid
        case "sum": return .operatorSymbol("∑", limits: true)
        case "prod": return .operatorSymbol("∏", limits: true)
        case "int": return .operatorSymbol("∫", limits: true)
        case "sin", "cos", "tan", "log", "ln", "exp", "lim", "max", "min":
            return .operatorName(name)
        default:
            guard let symbol = Self.symbols[name] else { throw ParseError.invalid }
            return Self.identifiers.contains(name)
                ? .identifier(symbol)
                : .operatorSymbol(symbol, limits: false)
        }
    }

    private mutating func squareRoot() throws -> MathMLNode {
        skipSpaces()
        if take("[") {
            let index = MathMLNode.row(try sequence(until: .index))
            guard take("]") else { throw ParseError.invalid }
            return .root(try argument(), index)
        }
        return .squareRoot(try argument())
    }

    private mutating func textArgument() throws -> String {
        skipSpaces()
        guard cursor < source.count else { throw ParseError.invalid }
        guard source[cursor] == "{" else {
            let value = source[cursor]
            cursor += 1
            return String(value)
        }
        return try rawGroup()
    }

    private mutating func rawGroup() throws -> String {
        guard take("{") else { throw ParseError.invalid }
        var depth = 0
        var value = ""
        while cursor < source.count {
            let character = source[cursor]
            cursor += 1
            if character == "{" { depth += 1 }
            if character == "}" {
                if depth == 0 { return value }
                depth -= 1
            }
            value.append(character)
        }
        throw ParseError.invalid
    }

    private mutating func delimited() throws -> MathMLNode {
        let left = try delimiter()
        let body = MathMLNode.row(try sequence(until: .rightDelimiter))
        guard isCommand("right") else { throw ParseError.invalid }
        _ = try consumeCommand(named: "right")
        return .fenced(left: left, body: body, right: try delimiter())
    }

    private mutating func delimiter() throws -> String? {
        skipSpaces()
        guard cursor < source.count else { throw ParseError.invalid }
        if take(".") { return nil }
        if take("\\") {
            guard cursor < source.count else { throw ParseError.invalid }
            if !source[cursor].isLetter {
                let escaped = source[cursor]
                cursor += 1
                return "{}()[]|".contains(escaped) ? String(escaped) : nil
            }
            let name = commandName()
            guard let delimiter = Self.delimiters[name] else { throw ParseError.invalid }
            return delimiter
        }
        let delimiter = source[cursor]
        cursor += 1
        guard "()[]|{}⌈⌉⌊⌋⟨⟩".contains(delimiter) else { throw ParseError.invalid }
        return String(delimiter)
    }

    private mutating func environment(named name: String) throws -> MathMLNode {
        guard ["matrix", "pmatrix", "cases", "aligned"].contains(name) else { throw ParseError.invalid }
        var rows: [[MathMLNode]] = []
        while true {
            var cells: [MathMLNode] = []
            while true {
                cells.append(.row(try sequence(until: .environment)))
                if take("&") { continue }
                break
            }
            rows.append(cells)
            if isRowBreak() {
                cursor += 2
                continue
            }
            guard isCommand("end") else { throw ParseError.invalid }
            _ = try consumeCommand(named: "end")
            guard try environmentName() == name else { throw ParseError.invalid }
            break
        }
        guard rows.allSatisfy({ $0.count == rows.first?.count }) else { throw ParseError.invalid }
        switch name {
        case "pmatrix": return .table(rows: rows, alignment: nil, left: "(", right: ")")
        case "cases": return .table(rows: rows, alignment: nil, left: "{", right: nil)
        case "aligned": return .table(rows: rows, alignment: "right left", left: nil, right: nil)
        default: return .table(rows: rows, alignment: nil, left: nil, right: nil)
        }
    }

    private mutating func environmentName() throws -> String {
        let name = try rawGroup()
        guard !name.isEmpty, name.allSatisfy(\.isLetter) else { throw ParseError.invalid }
        return name
    }

    private mutating func consumeCommand(named expected: String) throws -> String {
        guard take("\\"), cursor < source.count, source[cursor].isLetter else { throw ParseError.invalid }
        let name = commandName()
        guard name == expected else { throw ParseError.invalid }
        return name
    }

    private func isAt(_ terminator: Terminator) -> Bool {
        switch terminator {
        case .end: return false
        case .group: return source[cursor] == "}"
        case .index: return source[cursor] == "]"
        case .rightDelimiter: return isCommand("right")
        case .environment: return source[cursor] == "&" || isRowBreak() || isCommand("end")
        }
    }

    private func isRowBreak() -> Bool {
        cursor + 1 < source.count && source[cursor] == "\\" && source[cursor + 1] == "\\"
    }

    private func isCommand(_ expected: String) -> Bool {
        guard cursor < source.count, source[cursor] == "\\" else { return false }
        var index = cursor + 1
        let start = index
        while index < source.count, source[index].isLetter { index += 1 }
        return index > start && String(source[start..<index]) == expected
    }

    private mutating func commandName() -> String {
        let start = cursor
        while cursor < source.count, source[cursor].isLetter { cursor += 1 }
        return String(source[start..<cursor])
    }

    private mutating func take(_ character: Character) -> Bool {
        guard cursor < source.count, source[cursor] == character else { return false }
        cursor += 1
        return true
    }

    private mutating func skipSpaces() {
        while cursor < source.count, source[cursor].isWhitespace { cursor += 1 }
    }

    private enum ParseError: Error { case invalid }

    private static let symbols = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "theta": "θ",
        "lambda": "λ", "mu": "μ", "pi": "π", "sigma": "σ", "phi": "φ",
        "omega": "ω", "Delta": "Δ", "Lambda": "Λ", "Sigma": "Σ", "Omega": "Ω", "pm": "±",
        "times": "×", "cdot": "·", "le": "≤", "leq": "≤", "ge": "≥",
        "geq": "≥", "neq": "≠", "approx": "≈", "infty": "∞",
        "rightarrow": "→", "leftarrow": "←", "to": "→",
        "in": "∈", "dots": "…", "star": "⋆", "mid": "|", "perp": "⊥",
        "top": "⊤", "partial": "∂", "nabla": "∇", "sim": "∼",
        "vert": "|", "Vert": "∥", "lvert": "|", "rvert": "|",
        "lVert": "∥", "rVert": "∥",
    ]

    private static let identifiers: Set<String> = [
        "alpha", "beta", "gamma", "delta", "theta", "lambda", "mu", "pi", "sigma", "phi",
        "omega", "Delta", "Lambda", "Sigma", "Omega", "partial", "nabla",
    ]

    private static let delimiters = [
        "langle": "⟨", "rangle": "⟩", "lbrace": "{", "rbrace": "}",
        "vert": "|", "Vert": "∥", "lvert": "|", "rvert": "|",
        "lVert": "∥", "rVert": "∥", "lfloor": "⌊", "rfloor": "⌋",
        "lceil": "⌈", "rceil": "⌉",
    ]
}
