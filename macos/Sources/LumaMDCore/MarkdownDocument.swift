import Foundation

public struct MarkdownDocument: Sendable {
    public struct Heading: Sendable, Equatable {
        public let level: Int
        public let id: String
        public let text: String

        public init(level: Int, id: String, text: String) {
            self.level = level
            self.id = id
            self.text = text
        }
    }

    public let html: String
    public let source: String
    public let title: String
    public let wordCount: Int
    public let isEmpty: Bool
    public let headings: [Heading]

    public init(
        html: String,
        source: String = "",
        title: String,
        wordCount: Int,
        isEmpty: Bool,
        headings: [Heading]
    ) {
        self.html = html
        self.source = source
        self.title = title
        self.wordCount = wordCount
        self.isEmpty = isEmpty
        self.headings = headings
    }
}
