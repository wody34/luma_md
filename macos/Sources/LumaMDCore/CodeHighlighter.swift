import Foundation

internal enum CodeHighlighter {
    private static let jvmKeywords = words(
        "abstract actual annotation as break by catch class companion const constructor "
            + "continue data do else enum expect extends false final finally for fun if "
            + "implements import in infix inline interface internal is lateinit native new "
            + "object open operator out override package private protected public reified "
            + "return sealed static strictfp super suspend synchronized this throw throws "
            + "transient true try typealias typeof val var void volatile when while"
    )
    private static let scriptKeywords = words(
        "async await break case catch class const continue debugger default delete do else "
            + "export extends finally for from function get if implements import in "
            + "instanceof interface let new of package private protected public return "
            + "set static super switch this throw try typeof var void while with yield"
    )
    private static let pythonKeywords = words(
        "and as assert async await break class continue def del elif else except False finally "
            + "for from global if import in is lambda None nonlocal not or pass raise "
            + "return True try while with yield"
    )
    private static let bashKeywords = words(
        "case do done elif else esac fi for function if in select then time until while"
    )
    private static let literals = words(
        "true false null undefined NaN Infinity None True False"
    )

    static func canonicalLanguage(_ language: String?) -> String {
        let value = (language ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch value {
        case "kt": return "kotlin"
        case "js": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "sh", "shell", "zsh": return "bash"
        case "html", "svg": return "xml"
        case "md": return "markdown"
        case "kotlin", "java", "javascript", "typescript", "python", "bash",
             "json", "xml", "css", "markdown":
            return value
        default:
            return ""
        }
    }

    static func highlight(_ language: String?, _ source: String) -> String {
        let canonical = canonicalLanguage(language)
        if canonical.isEmpty {
            return escape(source)
        }
        if canonical == "xml" {
            return highlightMarkup(source)
        }
        if canonical == "markdown" {
            return highlightMarkdown(source)
        }
        return highlightCode(canonical, source)
    }

    private static func highlightCode(_ language: String, _ source: String) -> String {
        let characters = Array(source)
        var html = ""
        var cursor = 0
        while cursor < characters.count {
            let current = characters[cursor]
            if startsLineComment(language, characters, cursor) {
                let end = lineEnd(characters, cursor)
                html += span("comment", String(characters[cursor..<end]))
                cursor = end
            } else if hasPrefix("/*", in: characters, at: cursor) && supportsSlashComments(language) {
                var end = indexOf("*/", in: characters, from: cursor + 2)
                if end < 0 {
                    end = characters.count
                } else {
                    end += 2
                }
                html += span("comment", String(characters[cursor..<end]))
                cursor = end
            } else if current == "\"" || current == "'"
                        || (current == "`" && supportsBackticks(language)) {
                let end = quotedEnd(characters, cursor, current)
                html += span("string", String(characters[cursor..<end]))
                cursor = end
            } else if current.isNumber {
                var end = cursor + 1
                while end < characters.count
                        && (characters[end].isNumber || ".xabcdefABCDEF_".contains(characters[end])) {
                    end += 1
                }
                html += span("number", String(characters[cursor..<end]))
                cursor = end
            } else if isIdentifierStart(current) {
                var end = cursor + 1
                while end < characters.count && isIdentifierPart(characters[end]) {
                    end += 1
                }
                let word = String(characters[cursor..<end])
                html += highlightWord(language, word)
                cursor = end
            } else if current == "$" && language == "bash" {
                var end = cursor + 1
                while end < characters.count
                        && (characters[end].isNumber || characters[end].isLetter
                            || characters[end] == "_") {
                    end += 1
                }
                html += span("variable", String(characters[cursor..<end]))
                cursor = end
            } else {
                html += escape(String(current))
                cursor += 1
            }
        }
        return html
    }

    private static func highlightWord(_ language: String, _ word: String) -> String {
        if literals.contains(word) {
            return span("literal", word)
        }
        let keywords: Set<String>
        if language == "kotlin" || language == "java" {
            keywords = jvmKeywords
        } else if language == "javascript" || language == "typescript" {
            keywords = scriptKeywords
        } else if language == "python" {
            keywords = pythonKeywords
        } else if language == "bash" {
            keywords = bashKeywords
        } else {
            keywords = []
        }
        if keywords.contains(word) {
            return span("keyword", word)
        }
        if let first = word.first, first.isUppercase {
            return span("type", word)
        }
        return escape(word)
    }

    private static func highlightMarkup(_ source: String) -> String {
        let characters = Array(source)
        var html = ""
        var cursor = 0
        while cursor < characters.count {
            if hasPrefix("<!--", in: characters, at: cursor) {
                var end = indexOf("-->", in: characters, from: cursor + 4)
                if end < 0 {
                    end = characters.count
                } else {
                    end += 3
                }
                html += span("comment", String(characters[cursor..<end]))
                cursor = end
            } else if characters[cursor] == "<" {
                var end = indexOf(">", in: characters, from: cursor + 1)
                if end < 0 {
                    end = characters.count
                } else {
                    end += 1
                }
                html += span("keyword", String(characters[cursor..<end]))
                cursor = end
            } else {
                var end = indexOf("<", in: characters, from: cursor)
                if end < 0 {
                    end = characters.count
                }
                html += escape(String(characters[cursor..<end]))
                cursor = end
            }
        }
        return html
    }

    private static func highlightMarkdown(_ source: String) -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        var html = ""
        for index in lines.indices {
            let line = String(lines[index])
            let markerEnd = markdownMarkerEnd(line)
            if markerEnd > 0 {
                let marker = String(line.prefix(markerEnd))
                let remainder = String(line.dropFirst(markerEnd))
                html += span("keyword", marker) + escape(remainder)
            } else {
                html += escape(line)
            }
            if index != lines.indices.last {
                html += "\n"
            }
        }
        return html
    }

    private static func markdownMarkerEnd(_ line: String) -> Int {
        let characters = Array(line)
        if line.hasPrefix("#") {
            var end = 0
            while end < characters.count && characters[end] == "#" {
                end += 1
            }
            return end < characters.count && characters[end] == " " ? end : 0
        }
        return line.hasPrefix("> ") || line.hasPrefix("- ") || line.hasPrefix("* ") ? 1 : 0
    }

    private static func startsLineComment(
        _ language: String,
        _ source: [Character],
        _ cursor: Int
    ) -> Bool {
        if supportsSlashComments(language) && hasPrefix("//", in: source, at: cursor) {
            return true
        }
        return (language == "python" || language == "bash") && source[cursor] == "#"
    }

    private static func supportsSlashComments(_ language: String) -> Bool {
        language == "kotlin" || language == "java" || language == "javascript"
            || language == "typescript" || language == "css"
    }

    private static func supportsBackticks(_ language: String) -> Bool {
        language == "javascript" || language == "typescript"
    }

    private static func lineEnd(_ source: [Character], _ start: Int) -> Int {
        indexOf("\n", in: source, from: start) < 0
            ? source.count
            : indexOf("\n", in: source, from: start)
    }

    private static func quotedEnd(
        _ source: [Character],
        _ start: Int,
        _ quote: Character
    ) -> Int {
        var cursor = start + 1
        while cursor < source.count {
            if source[cursor] == "\\" {
                cursor += 2
            } else if source[cursor] == quote {
                return cursor + 1
            } else {
                cursor += 1
            }
        }
        return source.count
    }

    private static func span(_ kind: String, _ value: String) -> String {
        "<span class=\"tok-\(kind)\">\(escape(value))</span>"
    }

    private static func words(_ source: String) -> Set<String> {
        Set(source.split(separator: " ").map(String.init))
    }

    private static func isIdentifierStart(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private static func isIdentifierPart(_ character: Character) -> Bool {
        isIdentifierStart(character) || character.isNumber
    }

    private static func hasPrefix(
        _ prefix: String,
        in source: [Character],
        at start: Int
    ) -> Bool {
        let prefixCharacters = Array(prefix)
        guard start >= 0, start + prefixCharacters.count <= source.count else {
            return false
        }
        return source[start..<(start + prefixCharacters.count)].elementsEqual(prefixCharacters)
    }

    private static func indexOf(
        _ value: String,
        in source: [Character],
        from start: Int
    ) -> Int {
        let valueCharacters = Array(value)
        guard !valueCharacters.isEmpty else { return max(0, start) }
        guard start >= 0, start <= source.count - valueCharacters.count else { return -1 }
        for index in start...(source.count - valueCharacters.count) {
            if source[index..<(index + valueCharacters.count)].elementsEqual(valueCharacters) {
                return index
            }
        }
        return -1
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
