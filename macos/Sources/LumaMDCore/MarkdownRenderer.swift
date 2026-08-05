import Foundation

public struct MarkdownRenderer: Sendable {
    public init() {}

    public func render(_ markdown: String?, fallbackTitle: String?) -> MarkdownDocument {
        let originalSource = markdown ?? ""
        var source = originalSource
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let fallback = cleanFallbackTitle(fallbackTitle)
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return emptyDocument(title: fallback, source: originalSource)
        }

        let footnotes = Footnotes.extract(source)
        source = footnotes.source
        let lines = source.components(separatedBy: "\n")
        var html = ""
        var headings: [MarkdownDocument.Heading] = []
        var slugCounts: [String: Int] = [:]
        var paragraph: [String] = []
        var openList: String?
        var title = fallback
        var foundTitle = false
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html += "<p>" + InlineMarkdown.render(paragraph.joined(separator: " ")) + "</p>"
            paragraph.removeAll(keepingCapacity: true)
        }
        func closeList() {
            if let openList { html += "</\(openList)>" }
            openList = nil
        }

        while index < lines.count {
            let line = lines[index]

            if hasOpenInlineMath(paragraph),
               !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                paragraph.append(line)
                index += 1
                continue
            }

            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                flushParagraph()
                closeList()
                let fence = line.first!
                let end = findFenceEnd(lines, startingAt: index + 1, fence: fence)
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                html += renderCodeBlock(lines, start: index + 1, end: end, language: language)
                index = end < lines.count ? end + 1 : lines.count
                continue
            }

            if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("$$"),
               let end = findMathEnd(lines, startingAt: index) {
                flushParagraph()
                closeList()
                html += MathRenderer.renderBlock(mathExpression(lines, start: index, end: end))
                index = end + 1
                continue
            }

            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flushParagraph()
                closeList()
                index += 1
                continue
            }

            if let groups = firstMatch(in: line, pattern: #"^(#{1,6})\s+(.+?)\s*#*\s*$"#) {
                flushParagraph()
                closeList()
                let level = groups[1].count
                let headingSource = groups[2]
                let text = InlineMarkdown.plainText(headingSource)
                let id = uniqueSlug(text, counts: &slugCounts)
                headings.append(.init(level: level, id: id, text: text))
                html += "<h\(level) id=\"\(InlineMarkdown.escape(id))\">\(InlineMarkdown.render(headingSource))</h\(level)>"
                if !foundTitle, level == 1 {
                    title = text
                    foundTitle = true
                }
                index += 1
                continue
            }

            if index + 1 < lines.count, line.contains("|"), isTableDivider(lines[index + 1]) {
                flushParagraph()
                closeList()
                let result = renderTable(lines, startingAt: index)
                html += result.html
                index = result.nextIndex
                continue
            }

            let unordered = firstMatch(in: line, pattern: #"^\s*[-+*]\s+(.+)$"#)
            let ordered = firstMatch(in: line, pattern: #"^\s*\d+[.)]\s+(.+)$"#)
            if let item = unordered ?? ordered {
                flushParagraph()
                let target = unordered == nil ? "ol" : "ul"
                if openList != target {
                    closeList()
                    html += "<\(target)>"
                    openList = target
                }
                html += renderListItem(item[1])
                index += 1
                continue
            }

            if line.hasPrefix(">") {
                flushParagraph()
                closeList()
                let quote = line.hasPrefix("> ") ? String(line.dropFirst(2)) : String(line.dropFirst())
                html += "<blockquote><p>\(InlineMarkdown.render(quote))</p></blockquote>"
                index += 1
                continue
            }

            if isRule(line) {
                flushParagraph()
                closeList()
                html += "<hr>"
                index += 1
                continue
            }

            paragraph.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            index += 1
        }

        flushParagraph()
        closeList()
        return MarkdownDocument(
            html: footnotes.finish(html),
            source: originalSource,
            title: title,
            wordCount: countWords(originalSource),
            isEmpty: false,
            headings: headings
        )
    }

    private func emptyDocument(title: String, source: String) -> MarkdownDocument {
        let html = "<section class=\"empty-state\" role=\"status\">"
            + "<span class=\"empty-icon\" aria-hidden=\"true\"></span>"
            + "<h2>This file is empty</h2>"
            + "<p>Add some Markdown in your editor, then open it here again.</p>"
            + "<a class=\"button secondary\" href=\"luma://open\">Open another file</a>"
            + "</section>"
        return MarkdownDocument(
            html: html,
            source: source,
            title: title,
            wordCount: 0,
            isEmpty: true,
            headings: []
        )
    }

    private func cleanFallbackTitle(_ fallbackTitle: String?) -> String {
        let trimmed = fallbackTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let value = trimmed.isEmpty ? "Untitled note" : trimmed
        return value.replacingOccurrences(
            of: #"\.(md|markdown|txt)$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private func countWords(_ source: String) -> Int {
        let plain = source.replacingOccurrences(
            of: #"[#>*_~`|\[\]()!-]"#,
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return 0 }
        return plain.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    private func uniqueSlug(_ text: String, counts: inout [String: Int]) -> String {
        var base = ""
        var needsSeparator = false
        for character in text.lowercased() {
            let valid = character.unicodeScalars.allSatisfy {
                CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
            }
            if valid {
                if needsSeparator, !base.isEmpty { base.append("-") }
                base.append(character)
                needsSeparator = false
            } else if !base.isEmpty {
                needsSeparator = true
            }
        }
        if base.isEmpty { base = "section" }
        let count = (counts[base] ?? 0) + 1
        counts[base] = count
        return count == 1 ? base : "\(base)-\(count)"
    }

    private func findFenceEnd(_ lines: [String], startingAt start: Int, fence: Character) -> Int {
        guard start < lines.count else { return lines.count }
        let marker = String(repeating: String(fence), count: 3)
        for index in start..<lines.count where lines[index].hasPrefix(marker) { return index }
        return lines.count
    }

    private func findMathEnd(_ lines: [String], startingAt start: Int) -> Int? {
        let first = lines[start].trimmingCharacters(in: .whitespacesAndNewlines)
        if first.count > 4, first.hasSuffix("$$") { return start }
        guard first == "$$" else { return nil }
        guard start + 1 < lines.count else { return nil }
        for index in (start + 1)..<lines.count
        where lines[index].trimmingCharacters(in: .whitespacesAndNewlines) == "$$" {
            return index
        }
        return nil
    }

    private func mathExpression(_ lines: [String], start: Int, end: Int) -> String {
        let first = lines[start].trimmingCharacters(in: .whitespacesAndNewlines)
        if start == end { return String(first.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces) }
        return lines[(start + 1)..<end]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
    }

    private func renderCodeBlock(_ lines: [String], start: Int, end: Int, language: String) -> String {
        let upperBound = min(end, lines.count)
        let code = start < upperBound ? lines[start..<upperBound].joined(separator: "\n") : ""
        let lowered = language.lowercased()
        let canonical = CodeHTML.canonicalLanguage(language)
        let languageAttribute = language.isEmpty
            ? ""
            : " data-language=\"\(InlineMarkdown.escape(lowered))\""
        let classAttribute = canonical.isEmpty ? "" : " class=\"language-\(canonical)\""
        return "<pre\(languageAttribute)><code\(classAttribute)>\(CodeHTML.highlight(language, source: code))</code></pre>"
    }

    private func renderListItem(_ content: String) -> String {
        guard let task = firstMatch(in: content, pattern: #"^\[([ xX])\]\s+(.+)$"#) else {
            return "<li>\(InlineMarkdown.render(content))</li>"
        }
        let done = task[1] != " "
        let className = done ? "task done" : "task"
        let check = done ? "✓" : ""
        return "<li class=\"\(className)\"><span class=\"checkbox\" aria-hidden=\"true\">\(check)</span><span>\(InlineMarkdown.render(task[2]))</span></li>"
    }

    private func isRule(_ line: String) -> Bool {
        firstMatch(in: line, pattern: #"^\s{0,3}((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$"#) != nil
    }

    private func isTableDivider(_ line: String) -> Bool {
        var row = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if row.hasPrefix("|") { row.removeFirst() }
        if row.hasSuffix("|") { row.removeLast() }
        let cells = row.split(separator: "|", omittingEmptySubsequences: false)
        guard cells.count >= 2 else { return false }
        return cells.allSatisfy {
            let cell = $0.trimmingCharacters(in: .whitespaces)
            return firstMatch(in: cell, pattern: #"^:?-{3,}:?$"#) != nil
        }
    }

    private func tableCells(_ line: String) -> [String] {
        var row = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if row.hasPrefix("|") { row.removeFirst() }
        if row.hasSuffix("|") { row.removeLast() }
        return row.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func renderTable(_ lines: [String], startingAt start: Int) -> (html: String, nextIndex: Int) {
        var html = "<div class=\"table-scroll\"><table><thead><tr>"
        html += tableCells(lines[start]).map { "<th>\(InlineMarkdown.render($0))</th>" }.joined()
        html += "</tr></thead><tbody>"
        var index = start + 2
        while index < lines.count,
              !lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              lines[index].contains("|") {
            html += "<tr>" + tableCells(lines[index]).map { "<td>\(InlineMarkdown.render($0))</td>" }.joined() + "</tr>"
            index += 1
        }
        html += "</tbody></table></div>"
        return (html, index)
    }

    private func firstMatch(in source: String, pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = expression.firstMatch(in: source, range: range), match.range == range else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: source) else { return "" }
            return String(source[swiftRange])
        }
    }

    private func hasOpenInlineMath(_ lines: [String]) -> Bool {
        var delimiterCount = 0
        for line in lines {
            var previous: Character?
            for character in line {
                if character == "$", previous != "\\" {
                    delimiterCount += 1
                }
                previous = character
            }
        }
        return delimiterCount.isMultiple(of: 2) == false
    }
}

private final class Footnotes {
    struct Reference {
        let key: String
        let number: Int
        let occurrence: Int
        let tokenIndex: Int
    }

    let source: String
    private let definitions: [String: String]
    private let orderedKeys: [String]
    private let occurrences: [String: Int]
    private let references: [Reference]

    private init(
        source: String,
        definitions: [String: String],
        orderedKeys: [String],
        occurrences: [String: Int],
        references: [Reference]
    ) {
        self.source = source
        self.definitions = definitions
        self.orderedKeys = orderedKeys
        self.occurrences = occurrences
        self.references = references
    }

    static func extract(_ source: String) -> Footnotes {
        var lines = source.components(separatedBy: "\n")
        var definitions: [String: String] = [:]
        var definitionOrder: [String] = []
        var inFence = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isFence(trimmed) { inFence.toggle(); continue }
            guard !inFence, let definition = definition(in: line), definitions[definition.key] == nil else { continue }
            definitions[definition.key] = definition.value
            definitionOrder.append(definition.key)
        }

        var numbers: [String: Int] = [:]
        var orderedKeys: [String] = []
        var occurrences: [String: Int] = [:]
        var references: [Reference] = []
        inFence = false
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if isFence(trimmed) { inFence.toggle(); continue }
            guard !inFence else { continue }
            if definition(in: lines[index]) != nil {
                lines[index] = ""
                continue
            }
            lines[index] = replaceReferences(
                in: lines[index],
                definitions: definitions,
                numbers: &numbers,
                orderedKeys: &orderedKeys,
                occurrences: &occurrences,
                references: &references
            )
        }
        _ = definitionOrder
        return Footnotes(
            source: lines.joined(separator: "\n"),
            definitions: definitions,
            orderedKeys: orderedKeys,
            occurrences: occurrences,
            references: references
        )
    }

    func finish(_ documentHTML: String) -> String {
        var html = documentHTML
        for reference in references {
            html = html.replacingOccurrences(
                of: Self.token(reference.tokenIndex),
                with: referenceHTML(reference)
            )
        }
        guard !orderedKeys.isEmpty else { return html }
        html += "<section class=\"footnotes\" aria-label=\"Footnotes\"><hr><ol>"
        for (offset, key) in orderedKeys.enumerated() {
            let id = Self.safeID(key)
            html += "<li id=\"fn-\(InlineMarkdown.escape(id))\"><span class=\"footnote-content\">"
            html += InlineMarkdown.render(definitions[key] ?? "")
            html += "</span><span class=\"footnote-backlinks\">"
            for occurrence in 1...(occurrences[key] ?? 1) {
                let suffix = occurrence > 1 ? "-\(occurrence)" : ""
                html += "<a class=\"footnote-backref\" href=\"#fnref-\(InlineMarkdown.escape(id))\(suffix)\" aria-label=\"Back to footnote reference \(occurrence)\">↩</a>"
            }
            html += "</span></li>"
            _ = offset
        }
        return html + "</ol></section>"
    }

    private func referenceHTML(_ reference: Reference) -> String {
        let id = Self.safeID(reference.key)
        let suffix = reference.occurrence > 1 ? "-\(reference.occurrence)" : ""
        return "<sup class=\"footnote-ref\"><a id=\"fnref-\(InlineMarkdown.escape(id))\(suffix)\" href=\"#fn-\(InlineMarkdown.escape(id))\" aria-label=\"Footnote \(reference.number)\">\(reference.number)</a></sup>"
    }

    private static func replaceReferences(
        in line: String,
        definitions: [String: String],
        numbers: inout [String: Int],
        orderedKeys: inout [String],
        occurrences: inout [String: Int],
        references: inout [Reference]
    ) -> String {
        let characters = Array(line)
        var output = ""
        var cursor = 0
        var inCode = false
        while cursor < characters.count {
            if characters[cursor] == "`" {
                inCode.toggle()
                output.append(characters[cursor])
                cursor += 1
                continue
            }
            if !inCode, characters[cursor] == "[", cursor + 3 < characters.count, characters[cursor + 1] == "^",
               let end = characters[(cursor + 2)...].firstIndex(of: "]"), end > cursor + 2 {
                let key = String(characters[(cursor + 2)..<end])
                if definitions[key] != nil {
                    let number: Int
                    if let existing = numbers[key] {
                        number = existing
                    } else {
                        number = numbers.count + 1
                        numbers[key] = number
                        orderedKeys.append(key)
                    }
                    let occurrence = (occurrences[key] ?? 0) + 1
                    occurrences[key] = occurrence
                    let reference = Reference(key: key, number: number, occurrence: occurrence, tokenIndex: references.count)
                    references.append(reference)
                    output += token(reference.tokenIndex)
                    cursor = end + 1
                    continue
                }
            }
            output.append(characters[cursor])
            cursor += 1
        }
        return output
    }

    private static func definition(in line: String) -> (key: String, value: String)? {
        guard let expression = try? NSRegularExpression(pattern: #"^\s{0,3}\[\^([^]]+)\]\s*:\s*(.*)$"#) else { return nil }
        let full = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = expression.firstMatch(in: line, range: full), match.range == full,
              let keyRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else { return nil }
        return (String(line[keyRange]), String(line[valueRange]))
    }

    private static func isFence(_ line: String) -> Bool {
        line.hasPrefix("```") || line.hasPrefix("~~~")
    }

    private static func token(_ index: Int) -> String { "\u{0005}\(index)\u{0005}" }

    private static func safeID(_ key: String) -> String {
        var value = ""
        var separator = false
        for character in key.lowercased() {
            let valid = character == "_" || character == "-" || character.unicodeScalars.allSatisfy {
                CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
            }
            if valid {
                if separator, !value.isEmpty { value.append("-") }
                value.append(character)
                separator = false
            } else if !value.isEmpty {
                separator = true
            }
        }
        while value.hasSuffix("-") { value.removeLast() }
        return value.isEmpty ? "note" : value
    }
}

private enum CodeHTML {
    private static let jvmKeywords = words("abstract actual annotation as break by catch class companion const constructor continue data do else enum expect extends false final finally for fun if implements import in infix inline interface internal is lateinit native new object open operator out override package private protected public reified return sealed static strictfp super suspend synchronized this throw throws transient true try typealias typeof val var void volatile when while")
    private static let scriptKeywords = words("async await break case catch class const continue debugger default delete do else export extends finally for from function get if implements import in instanceof interface let new of package private protected public return set static super switch this throw try typeof var void while with yield")
    private static let pythonKeywords = words("and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield")
    private static let bashKeywords = words("case do done elif else esac fi for function if in select then time until while")
    private static let literals = words("true false null undefined NaN Infinity None True False")

    static func canonicalLanguage(_ language: String) -> String {
        let value = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aliases = ["kt": "kotlin", "js": "javascript", "ts": "typescript", "tsx": "typescript", "py": "python", "sh": "bash", "shell": "bash", "zsh": "bash", "html": "xml", "svg": "xml", "md": "markdown"]
        if let alias = aliases[value] { return alias }
        let recognized: Set<String> = ["kotlin", "java", "javascript", "typescript", "python", "bash", "json", "xml", "css", "markdown"]
        return recognized.contains(value) ? value : ""
    }

    static func highlight(_ language: String, source: String) -> String {
        let canonical = canonicalLanguage(language)
        guard !canonical.isEmpty else { return InlineMarkdown.escape(source) }
        if canonical == "xml" { return highlightMarkup(source) }
        if canonical == "markdown" { return highlightMarkdown(source) }
        return highlightCode(canonical, source: source)
    }

    private static func highlightCode(_ language: String, source: String) -> String {
        let characters = Array(source)
        var output = ""
        var cursor = 0
        while cursor < characters.count {
            if startsLineComment(language, characters, cursor) {
                var end = cursor
                while end < characters.count, characters[end] != "\n" { end += 1 }
                output += span("comment", String(characters[cursor..<end]))
                cursor = end
            } else if supportsSlashComments(language), startsWith(characters, cursor, "/*") {
                var end = cursor + 2
                while end + 1 < characters.count, !(characters[end] == "*" && characters[end + 1] == "/") { end += 1 }
                end = end + 1 < characters.count ? end + 2 : characters.count
                output += span("comment", String(characters[cursor..<end]))
                cursor = end
            } else if characters[cursor] == "\"" || characters[cursor] == "'" || (characters[cursor] == "`" && (language == "javascript" || language == "typescript")) {
                let quote = characters[cursor]
                var end = cursor + 1
                while end < characters.count {
                    if characters[end] == "\\" { end = min(end + 2, characters.count); continue }
                    if characters[end] == quote { end += 1; break }
                    end += 1
                }
                output += span("string", String(characters[cursor..<end]))
                cursor = end
            } else if characters[cursor].isNumber {
                var end = cursor + 1
                while end < characters.count, characters[end].isNumber || ".xabcdefABCDEF_".contains(characters[end]) { end += 1 }
                output += span("number", String(characters[cursor..<end]))
                cursor = end
            } else if isIdentifierStart(characters[cursor]) {
                var end = cursor + 1
                while end < characters.count, isIdentifierPart(characters[end]) { end += 1 }
                let word = String(characters[cursor..<end])
                output += highlightWord(language, word)
                cursor = end
            } else if characters[cursor] == "$", language == "bash" {
                var end = cursor + 1
                while end < characters.count, characters[end].isLetter || characters[end].isNumber || characters[end] == "_" { end += 1 }
                output += span("variable", String(characters[cursor..<end]))
                cursor = end
            } else {
                output += InlineMarkdown.escape(String(characters[cursor]))
                cursor += 1
            }
        }
        return output
    }

    private static func highlightWord(_ language: String, _ word: String) -> String {
        if literals.contains(word) { return span("literal", word) }
        let keywords: Set<String>
        switch language {
        case "kotlin", "java": keywords = jvmKeywords
        case "javascript", "typescript": keywords = scriptKeywords
        case "python": keywords = pythonKeywords
        case "bash": keywords = bashKeywords
        default: keywords = []
        }
        if keywords.contains(word) { return span("keyword", word) }
        if word.first?.isUppercase == true { return span("type", word) }
        return InlineMarkdown.escape(word)
    }

    private static func highlightMarkup(_ source: String) -> String {
        let characters = Array(source)
        var output = ""
        var cursor = 0
        while cursor < characters.count {
            if startsWith(characters, cursor, "<!--") {
                var end = cursor + 4
                while end + 2 < characters.count, String(characters[end...min(end + 2, characters.count - 1)]) != "-->" { end += 1 }
                end = end + 2 < characters.count ? end + 3 : characters.count
                output += span("comment", String(characters[cursor..<end]))
                cursor = end
            } else if characters[cursor] == "<" {
                var end = cursor + 1
                while end < characters.count, characters[end] != ">" { end += 1 }
                if end < characters.count { end += 1 }
                output += span("keyword", String(characters[cursor..<end]))
                cursor = end
            } else {
                var end = cursor
                while end < characters.count, characters[end] != "<" { end += 1 }
                output += InlineMarkdown.escape(String(characters[cursor..<end]))
                cursor = end
            }
        }
        return output
    }

    private static func highlightMarkdown(_ source: String) -> String {
        source.components(separatedBy: "\n").map { line in
            let marker: String
            if line.hasPrefix("#") {
                marker = String(line.prefix { $0 == "#" })
            } else if line.hasPrefix("> ") || line.hasPrefix("- ") || line.hasPrefix("* ") {
                marker = String(line.prefix(1))
            } else {
                marker = ""
            }
            guard !marker.isEmpty else { return InlineMarkdown.escape(line) }
            return span("keyword", marker) + InlineMarkdown.escape(String(line.dropFirst(marker.count)))
        }.joined(separator: "\n")
    }

    private static func startsLineComment(_ language: String, _ source: [Character], _ cursor: Int) -> Bool {
        (supportsSlashComments(language) && startsWith(source, cursor, "//"))
            || ((language == "python" || language == "bash") && source[cursor] == "#")
    }

    private static func supportsSlashComments(_ language: String) -> Bool {
        ["kotlin", "java", "javascript", "typescript", "css"].contains(language)
    }

    private static func startsWith(_ source: [Character], _ cursor: Int, _ value: String) -> Bool {
        let expected = Array(value)
        guard cursor + expected.count <= source.count else { return false }
        return Array(source[cursor..<(cursor + expected.count)]) == expected
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private static func isIdentifierPart(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }

    private static func span(_ kind: String, _ value: String) -> String {
        "<span class=\"tok-\(kind)\">\(InlineMarkdown.escape(value))</span>"
    }

    private static func words(_ source: String) -> Set<String> {
        Set(source.split(separator: " ").map(String.init))
    }
}
