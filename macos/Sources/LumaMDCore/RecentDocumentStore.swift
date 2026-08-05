import Foundation

public struct BookmarkResolution: Equatable {
    public let url: URL
    public let isStale: Bool

    public init(url: URL, isStale: Bool) {
        self.url = url
        self.isStale = isStale
    }
}

public protocol BookmarkCodec {
    func createBookmark(for url: URL) throws -> Data
    func resolveBookmark(_ bookmark: Data) throws -> BookmarkResolution
}

public struct SystemBookmarkCodec: BookmarkCodec {
    public init() {}

    public func createBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func resolveBookmark(_ bookmark: Data) throws -> BookmarkResolution {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return BookmarkResolution(url: url, isStale: isStale)
    }
}

public final class RecentDocumentStore {
    private static let bookmarkKey = "recent-document-bookmark"

    private let defaults: UserDefaults
    private let codec: BookmarkCodec

    public init(
        defaults: UserDefaults = .standard,
        codec: BookmarkCodec = SystemBookmarkCodec()
    ) {
        self.defaults = defaults
        self.codec = codec
    }

    public var hasBookmark: Bool {
        defaults.data(forKey: Self.bookmarkKey) != nil
    }

    public func store(_ url: URL) throws {
        let bookmark = try codec.createBookmark(for: url)
        defaults.set(bookmark, forKey: Self.bookmarkKey)
    }

    public func resolve() throws -> URL? {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else {
            return nil
        }

        let resolution = try codec.resolveBookmark(bookmark)
        if resolution.isStale {
            let refreshedBookmark = try codec.createBookmark(for: resolution.url)
            defaults.set(refreshedBookmark, forKey: Self.bookmarkKey)
        }
        return resolution.url
    }

    public func clear() {
        defaults.removeObject(forKey: Self.bookmarkKey)
    }
}
