import Foundation

internal enum FootnoteProcessor {
    private static let token = "\u{0005}"

    static func extract(_ source: String) -> Result {
        var lines = source.components(separatedBy: "\n")
        let definitions = collectDefinitions(lines)
        var numbers: [String: Int] = [:]
        var occurrences: [String: Int] = [:]
        var references: [Reference] = []
        var inFence = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if isFence(trimmed) {
                inFence.toggle()
                continue
            }
            if !inFence {
                if parseDefinition(lines[index]) != nil {
                    lines[index] = ""
                } else {
                    lines[index] = replaceReferences(
                        in: lines[index],
                        definitions: definitions,
                        numbers: &numbers,
                        occurrences: &occurrences,
                        references: &references
                    )
                }
            }
        }

        return Result(
            source: lines.joined(separator: "\n"),
            definitions: definitions,
            numbers: numbers,
            occurrences: occurrences,
            references: references
        )
    }

    private static func collectDefinitions(_ lines: [String]) -> [String: String] {
        var definitions: [String: String] = [:]
        var inFence = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isFence(trimmed) {
                inFence.toggle()
                continue
            }
            if inFence {
                continue
            }
            if let definition = parseDefinition(line), definitions[definition.key] == nil {
                definitions[definition.key] = definition.value
            }
        }
        return definitions
    }

    private static func replaceReferences(
        in line: String,
        definitions: [String: String],
        numbers: inout [String: Int],
        occurrences: inout [String: Int],
        references: inout [Reference]
    ) -> String {
        let characters = Array(line)
        var output = ""
        var inCode = false
        var cursor = 0
        while cursor < characters.count {
            let current = characters[cursor]
            if current == "`" {
                inCode.toggle()
                output.append(current)
                cursor += 1
                continue
            }
            if !inCode && current == "[" && cursor + 3 < characters.count
                    && characters[cursor + 1] == "^" {
                var end = cursor + 2
                while end < characters.count && characters[end] != "]" {
                    end += 1
                }
                if end > cursor + 2 && end < characters.count {
                    let key = String(characters[(cursor + 2)..<end])
                    if definitions[key] != nil {
                        let number: Int
                        if let existing = numbers[key] {
                            number = existing
                        } else {
                            number = numbers.count + 1
                            numbers[key] = number
                        }
                        let occurrence = (occurrences[key] ?? 0) + 1
                        occurrences[key] = occurrence
                        let reference = Reference(
                            key: key,
                            number: number,
                            occurrence: occurrence,
                            tokenIndex: references.count
                        )
                        references.append(reference)
                        output += token + String(reference.tokenIndex) + token
                        cursor = end + 1
                        continue
                    }
                }
            }
            output.append(current)
            cursor += 1
        }
        return output
    }

    private static func isFence(_ line: String) -> Bool {
        line.hasPrefix("```") || line.hasPrefix("~~~")
    }

    private static func parseDefinition(_ line: String) -> (key: String, value: String)? {
        let characters = Array(line)
        var cursor = 0
        var leadingWhitespace = 0
        while cursor < characters.count && characters[cursor].isWhitespace {
            leadingWhitespace += 1
            cursor += 1
        }
        guard leadingWhitespace <= 3,
              cursor + 2 < characters.count,
              characters[cursor] == "[",
              characters[cursor + 1] == "^" else {
            return nil
        }
        cursor += 2
        let keyStart = cursor
        while cursor < characters.count && characters[cursor] != "]" {
            cursor += 1
        }
        guard cursor > keyStart, cursor < characters.count else {
            return nil
        }
        let key = String(characters[keyStart..<cursor])
        cursor += 1
        while cursor < characters.count && characters[cursor].isWhitespace {
            cursor += 1
        }
        guard cursor < characters.count, characters[cursor] == ":" else {
            return nil
        }
        cursor += 1
        while cursor < characters.count && characters[cursor].isWhitespace {
            cursor += 1
        }
        return (key, String(characters[cursor..<characters.count]))
    }

    private static func safeID(_ key: String) -> String {
        var value = ""
        for character in key.lowercased() {
            if character.isLetter || character.isNumber || character == "_" || character == "-" {
                value.append(character)
            } else {
                value.append("-")
            }
        }
        while value.first == "-" {
            value.removeFirst()
        }
        while value.last == "-" {
            value.removeLast()
        }
        return value.isEmpty ? "note" : value
    }

    internal struct Result {
        let source: String
        let definitions: [String: String]
        let numbers: [String: Int]
        let occurrences: [String: Int]
        private let references: [Reference]

        fileprivate init(
            source: String,
            definitions: [String: String],
            numbers: [String: Int],
            occurrences: [String: Int],
            references: [Reference]
        ) {
            self.source = source
            self.definitions = definitions
            self.numbers = numbers
            self.occurrences = occurrences
            self.references = references
        }

        func finish(
            _ documentHTML: String,
            renderDefinition: ((String) -> String)? = nil
        ) -> String {
            var html = documentHTML
            for reference in references {
                html = html.replacingOccurrences(
                    of: FootnoteProcessor.token + String(reference.tokenIndex) + FootnoteProcessor.token,
                    with: referenceHTML(reference)
                )
            }
            return html + sectionHTML(renderDefinition: renderDefinition)
        }

        private func referenceHTML(_ reference: Reference) -> String {
            let id = FootnoteProcessor.safeID(reference.key)
            let referenceID = "fnref-" + id
                + (reference.occurrence > 1 ? "-" + String(reference.occurrence) : "")
            return "<sup class=\"footnote-ref\"><a id=\""
                + FootnoteProcessor.escape(referenceID)
                + "\" href=\"#"
                + FootnoteProcessor.escape("fn-" + id)
                + "\" aria-label=\"Footnote "
                + String(reference.number)
                + "\">"
                + String(reference.number)
                + "</a></sup>"
        }

        private func sectionHTML(renderDefinition: ((String) -> String)?) -> String {
            guard !numbers.isEmpty else { return "" }
            var html = "<section class=\"footnotes\" aria-label=\"Footnotes\"><hr><ol>"
            for (key, _) in numbersInReferenceOrder() {
                let id = FootnoteProcessor.safeID(key)
                html += "<li id=\"fn-" + FootnoteProcessor.escape(id) + "\"><span class=\"footnote-content\">"
                let definition = definitions[key] ?? ""
                html += renderDefinition?(definition) ?? FootnoteProcessor.renderInline(definition)
                html += "</span><span class=\"footnote-backlinks\">"
                let count = occurrences[key] ?? 0
                if count > 0 {
                    for occurrence in 1...count {
                        let referenceID = "fnref-" + id
                            + (occurrence > 1 ? "-" + String(occurrence) : "")
                        html += "<a class=\"footnote-backref\" href=\"#"
                            + FootnoteProcessor.escape(referenceID)
                            + "\" aria-label=\"Back to footnote reference "
                            + String(occurrence)
                            + "\">↩</a>"
                    }
                }
                html += "</span></li>"
            }
            return html + "</ol></section>"
        }

        private func numbersInReferenceOrder() -> [(String, Int)] {
            numbers.sorted { left, right in
                if left.value == right.value {
                    return left.key < right.key
                }
                return left.value < right.value
            }
        }
    }

    fileprivate struct Reference {
        let key: String
        let number: Int
        let occurrence: Int
        let tokenIndex: Int
    }

    private static func renderInline(_ source: String) -> String {
        let escaped = escape(source)
        var output = escaped
        output = replaceDelimited(output, marker: "**", open: "<strong>", close: "</strong>")
        output = replaceDelimited(output, marker: "*", open: "<em>", close: "</em>")
        output = replaceDelimited(output, marker: "`", open: "<code>", close: "</code>")
        return output
    }

    private static func replaceDelimited(
        _ source: String,
        marker: String,
        open: String,
        close: String
    ) -> String {
        var output = ""
        var remainder = source
        while let start = remainder.range(of: marker),
              let end = remainder.range(of: marker, range: start.upperBound..<remainder.endIndex) {
            output += remainder[..<start.lowerBound]
            output += open
            output += remainder[start.upperBound..<end.lowerBound]
            output += close
            remainder = String(remainder[end.upperBound...])
        }
        return output + remainder
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
