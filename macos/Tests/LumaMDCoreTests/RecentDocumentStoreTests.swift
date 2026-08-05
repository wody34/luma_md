import Foundation
import XCTest
import LumaMDCore

final class RecentDocumentStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "LumaMD.RecentDocumentStoreTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testStorePersistsEncodedBookmarkAndResolveUsesIt() throws {
        let url = URL(fileURLWithPath: "/Documents/reading.md")
        let bookmark = Data("bookmark-v1".utf8)
        let codec = BookmarkCodecSpy()
        codec.bookmarksByURL[url] = bookmark
        codec.resolutionsByBookmark[bookmark] = BookmarkResolution(url: url, isStale: false)

        try RecentDocumentStore(defaults: defaults, codec: codec).store(url)
        let resolved = try RecentDocumentStore(defaults: defaults, codec: codec).resolve()

        XCTAssertEqual(resolved, Optional(url))
        XCTAssertEqual(codec.createdURLs, [url])
        XCTAssertEqual(codec.resolvedBookmarks, [bookmark])
    }

    func testFreshResolutionDoesNotRewriteBookmark() throws {
        let url = URL(fileURLWithPath: "/Documents/current.md")
        let bookmark = Data("fresh-bookmark".utf8)
        let codec = BookmarkCodecSpy()
        codec.bookmarksByURL[url] = bookmark
        codec.resolutionsByBookmark[bookmark] = BookmarkResolution(url: url, isStale: false)
        let store = RecentDocumentStore(defaults: defaults, codec: codec)

        try store.store(url)
        XCTAssertEqual(try store.resolve(), Optional(url))

        XCTAssertEqual(codec.createdURLs, [url], "A fresh bookmark must not be regenerated")
    }

    func testStaleResolutionRefreshesPersistedBookmarkUsingResolvedURL() throws {
        let originalURL = URL(fileURLWithPath: "/Documents/original.md")
        let movedURL = URL(fileURLWithPath: "/Documents/moved.md")
        let staleBookmark = Data("bookmark-v1".utf8)
        let refreshedBookmark = Data("bookmark-v2".utf8)
        let codec = BookmarkCodecSpy()
        codec.bookmarksByURL[originalURL] = staleBookmark
        codec.bookmarksByURL[movedURL] = refreshedBookmark
        codec.resolutionsByBookmark[staleBookmark] = BookmarkResolution(
            url: movedURL,
            isStale: true
        )
        codec.resolutionsByBookmark[refreshedBookmark] = BookmarkResolution(
            url: movedURL,
            isStale: false
        )
        let store = RecentDocumentStore(defaults: defaults, codec: codec)

        try store.store(originalURL)
        XCTAssertEqual(try store.resolve(), Optional(movedURL))
        XCTAssertEqual(codec.createdURLs, [originalURL, movedURL])

        let relaunchedStore = RecentDocumentStore(defaults: defaults, codec: codec)
        XCTAssertEqual(try relaunchedStore.resolve(), Optional(movedURL))
        XCTAssertEqual(
            codec.resolvedBookmarks,
            [staleBookmark, refreshedBookmark],
            "The refreshed bookmark must replace the stale persisted data"
        )
    }

    func testClearRemovesRecentWithoutInvokingCodec() throws {
        let url = URL(fileURLWithPath: "/Documents/to-clear.md")
        let bookmark = Data("bookmark-to-clear".utf8)
        let codec = BookmarkCodecSpy()
        codec.bookmarksByURL[url] = bookmark
        let store = RecentDocumentStore(defaults: defaults, codec: codec)

        try store.store(url)
        store.clear()

        XCTAssertNil(try store.resolve())
        XCTAssertTrue(codec.resolvedBookmarks.isEmpty)
    }

    func testBookmarkPresenceCheckDoesNotResolveStoredBookmark() throws {
        let url = URL(fileURLWithPath: "/Downloads/report.md")
        let bookmark = Data("download-bookmark".utf8)
        let codec = BookmarkCodecSpy()
        codec.bookmarksByURL[url] = bookmark
        let store = RecentDocumentStore(defaults: defaults, codec: codec)
        try store.store(url)

        XCTAssertTrue(store.hasBookmark)
        XCTAssertTrue(
            codec.resolvedBookmarks.isEmpty,
            "Checking recent availability must not resolve a security-scoped bookmark."
        )
    }
}

private final class BookmarkCodecSpy: BookmarkCodec {
    enum FixtureError: Error {
        case missingBookmark(URL)
        case missingResolution(Data)
    }

    var bookmarksByURL: [URL: Data] = [:]
    var resolutionsByBookmark: [Data: BookmarkResolution] = [:]
    private(set) var createdURLs: [URL] = []
    private(set) var resolvedBookmarks: [Data] = []

    func createBookmark(for url: URL) throws -> Data {
        createdURLs.append(url)
        guard let bookmark = bookmarksByURL[url] else {
            throw FixtureError.missingBookmark(url)
        }
        return bookmark
    }

    func resolveBookmark(_ bookmark: Data) throws -> BookmarkResolution {
        resolvedBookmarks.append(bookmark)
        guard let resolution = resolutionsByBookmark[bookmark] else {
            throw FixtureError.missingResolution(bookmark)
        }
        return resolution
    }
}
