import Foundation

public enum InlineMarkdown {
    public static func render(_ source: String) -> String {
        var fragments: [String] = []
        var value = protectMatches(in: source, pattern: #"`([^`\n]+)`"#) { groups in
            token(for: append("<code>\(escape(groups[1]))</code>", to: &fragments))
        }
        value = protectMatches(in: value, pattern: #"(?<!\\)\$([^$\n]+)\$"#) { groups in
            token(for: append(MathRenderer.renderInline(groups[1]), to: &fragments))
        }

        value = escape(value)
        value = protectMatches(in: value, pattern: #"!\[([^]]*)\]\(([^\s)]+)\)"#) { groups in
            token(for: append("<span class=\"image-alt\">[\(groups[1])]</span>", to: &fragments))
        }
        value = protectMatches(in: value, pattern: #"\[([^]]+)\]\(([^\s)]+)\)"#) { groups in
            let label = groups[1]
            let destination = groups[2]
            let markup: String
            guard isSafeLink(destination) else {
                markup = "<span class=\"unsafe-link\">\(label)</span>"
                return token(for: append(markup, to: &fragments))
            }
            let external = destination.hasPrefix("#")
                ? ""
                : " target=\"_blank\" rel=\"noopener noreferrer\""
            markup = "<a href=\"\(destination)\"\(external)>\(label)</a>"
            return token(for: append(markup, to: &fragments))
        }
        value = replaceMatches(in: value, pattern: #"\*\*([^*\n]+)\*\*"#) {
            "<strong>\($0[1])</strong>"
        }
        value = replaceMatches(in: value, pattern: #"__([^_\n]+)__"#) {
            "<strong>\($0[1])</strong>"
        }
        value = replaceMatches(in: value, pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#) {
            "<em>\($0[1])</em>"
        }
        value = replaceMatches(in: value, pattern: #"(?<![\p{L}\p{N}_])_([^_\n]+)_(?![\p{L}\p{N}_])"#) {
            "<em>\($0[1])</em>"
        }
        value = replaceMatches(in: value, pattern: #"~~([^~\n]+)~~"#) {
            "<del>\($0[1])</del>"
        }
        for (index, fragment) in fragments.enumerated() {
            value = value.replacingOccurrences(of: token(for: index), with: fragment)
        }
        return value
    }

    public static func plainText(_ source: String) -> String {
        var value = replaceMatches(in: source, pattern: #"!\[([^]]*)\]\([^)]*\)"#) { $0[1] }
        value = replaceMatches(in: value, pattern: #"\[([^]]+)\]\([^)]*\)"#) { $0[1] }
        value = value.replacingOccurrences(of: #"[*_~`]"#, with: "", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func append(_ fragment: String, to fragments: inout [String]) -> Int {
        let index = fragments.count
        fragments.append(fragment)
        return index
    }

    private static func token(for index: Int) -> String {
        "\u{0007}\(index)\u{0007}"
    }

    private static func isSafeLink(_ destination: String) -> Bool {
        destination.hasPrefix("#")
            || destination.hasPrefix("https://")
            || destination.hasPrefix("http://")
            || destination.hasPrefix("mailto:")
    }

    private static func protectMatches(
        in source: String,
        pattern: String,
        transform: ([String]) -> String
    ) -> String {
        replaceMatches(in: source, pattern: pattern, transform: transform)
    }

    private static func replaceMatches(
        in source: String,
        pattern: String,
        transform: ([String]) -> String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return source }
        let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = expression.matches(in: source, range: fullRange)
        var output = source
        for match in matches.reversed() {
            guard let range = Range(match.range, in: source) else { continue }
            var groups: [String] = []
            for index in 0..<match.numberOfRanges {
                let groupRange = match.range(at: index)
                if groupRange.location == NSNotFound {
                    groups.append("")
                } else if let swiftRange = Range(groupRange, in: source) {
                    groups.append(String(source[swiftRange]))
                }
            }
            output.replaceSubrange(range, with: transform(groups))
        }
        return output
    }
}
