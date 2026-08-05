import Foundation
import XCTest
import LumaMDMac

@MainActor
final class AppModelTests: XCTestCase {
    func testStartsOnWelcomeWithPersistedPreferencesAndRecentAvailability() {
        let recentURL = fileURL("Last note.md")
        let context = makeContext(recentURL: recentURL, theme: .dark, typeScale: .large)

        XCTAssertEqual(context.model.state, .welcome)
        XCTAssertTrue(context.model.hasRecentDocument)
        XCTAssertEqual(context.model.theme, .dark)
        XCTAssertEqual(context.model.typeScale, .large)
    }

    func testOpenActionUsesNativePickerAndCancelPreservesCurrentState() {
        let context = makeContext()
        let selectedURL = fileURL("Selected.markdown")
        let note = makeNote(url: selectedURL, filename: "Selected.markdown")
        context.loader.results[selectedURL] = .success(note)
        context.native.openPanelResult = selectedURL

        context.model.openDocument()

        XCTAssertEqual(context.loader.loadedURLs, [selectedURL])
        XCTAssertEqual(context.model.state, .reading(note))
        XCTAssertEqual(context.recent.rememberedURLs, [selectedURL])

        context.native.openPanelResult = nil
        context.model.openDocument()

        XCTAssertEqual(context.loader.loadedURLs, [selectedURL])
        XCTAssertEqual(context.model.state, .reading(note))
    }

    func testOpenURLsUsesOnlyFirstSupportedURLAndRemembersItAfterSuccess() {
        let context = makeContext()
        let unsupportedURL = fileURL("cover.png")
        let firstSupportedURL = fileURL("First.mdx")
        let secondSupportedURL = fileURL("Second.txt")
        let note = makeNote(url: firstSupportedURL, filename: "First.mdx")
        context.loader.results[firstSupportedURL] = .success(note)

        context.model.open(urls: [unsupportedURL, firstSupportedURL, secondSupportedURL])

        XCTAssertEqual(context.loader.loadedURLs, [firstSupportedURL])
        XCTAssertEqual(context.recent.rememberedURLs, [firstSupportedURL])
        XCTAssertEqual(context.model.state, .reading(note))
        XCTAssertTrue(context.model.hasRecentDocument)
    }

    func testOpenFailureIsRecoverableAndDoesNotReplaceRecentDocument() {
        let context = makeContext()
        let unreadableURL = fileURL("private/bad.md")
        context.loader.results[unreadableURL] = .failure(TestError.secretPath)

        context.model.open(urls: [unreadableURL])

        XCTAssertEqual(context.loader.loadedURLs, [unreadableURL])
        XCTAssertTrue(context.recent.rememberedURLs.isEmpty)
        guard case let .failure(message) = context.model.state else {
            return XCTFail("Expected a recoverable failure state")
        }
        XCTAssertTrue(message.contains("bad.md"))
        XCTAssertFalse(message.contains("/Users/secret"))

        context.model.goHome()
        XCTAssertEqual(context.model.state, .welcome)
    }

    func testBookmarkPersistenceFailureDoesNotDiscardLoadedDocument() {
        let context = makeContext()
        let downloadURL = fileURL("Downloads/report.md")
        let note = makeNote(url: downloadURL, filename: "report.md")
        context.loader.results[downloadURL] = .success(note)
        context.recent.rememberError = TestError.bookmarkPersistence

        context.model.open(urls: [downloadURL])

        XCTAssertEqual(context.loader.loadedURLs, [downloadURL])
        XCTAssertEqual(context.recent.rememberAttempts, [downloadURL])
        XCTAssertEqual(context.model.state, .reading(note))
    }

    func testHomeKeepsRecentAndContinueReadingReopensIt() {
        let recentURL = fileURL("Recent.mdown")
        let context = makeContext(recentURL: recentURL)
        let note = makeNote(url: recentURL, filename: "Recent.mdown")
        context.loader.results[recentURL] = .success(note)

        context.model.openRecent()
        XCTAssertEqual(context.model.state, .reading(note))
        XCTAssertTrue(
            context.recent.rememberedURLs.isEmpty,
            "Opening an existing security-scoped bookmark must not recreate it after scope closes"
        )

        context.model.goHome()
        XCTAssertEqual(context.model.state, .welcome)
        XCTAssertTrue(context.model.hasRecentDocument)

        context.model.openRecent()
        XCTAssertEqual(context.loader.loadedURLs, [recentURL, recentURL])
        XCTAssertEqual(context.model.state, .reading(note))
    }

    func testUnusableRecentIsClearedAndProducesRecoveryState() {
        let recentURL = fileURL("Moved.mkd")
        let context = makeContext(recentURL: recentURL)
        context.loader.results[recentURL] = .failure(TestError.secretPath)

        context.model.openRecent()

        XCTAssertEqual(context.recent.clearCount, 1)
        XCTAssertFalse(context.model.hasRecentDocument)
        guard case .failure = context.model.state else {
            return XCTFail("Expected stale recent recovery state")
        }
    }

    func testThemeAndTypeCommandsPersistExactChoicesAndCycleAllScales() {
        let context = makeContext(theme: .system, typeScale: .small)

        context.model.setTheme(.light)
        XCTAssertEqual(context.model.theme, .light)
        XCTAssertEqual(context.preferences.theme, .light)

        context.model.setTheme(.dark)
        XCTAssertEqual(context.model.theme, .dark)
        context.model.setTheme(.system)
        XCTAssertEqual(context.preferences.theme, .system)

        context.model.cycleTypeScale()
        XCTAssertEqual(context.model.typeScale, .standard)
        context.model.cycleTypeScale()
        XCTAssertEqual(context.model.typeScale, .large)
        context.model.cycleTypeScale()
        XCTAssertEqual(context.model.typeScale, .small)

        context.model.setTypeScale(.large)
        XCTAssertEqual(context.preferences.typeScale, .large)
        XCTAssertEqual(context.preferences.savedScales, [.standard, .large, .small, .large])
    }

    func testClipboardMemoRetainsExactSourceAndNeverChangesRecent() throws {
        let recentURL = fileURL("Kept.md")
        let context = makeContext(recentURL: recentURL)
        let source = "# 메모\n\nExact trailing spaces  \n"
        context.native.clipboardSource = source

        context.model.createClipboardMemo()

        guard case let .reading(note) = context.model.state else {
            return XCTFail("Expected clipboard memo reader state")
        }
        XCTAssertEqual(note.fileURL, nil)
        XCTAssertEqual(note.filename, "Clipboard memo.md")
        XCTAssertEqual(note.source, source)
        XCTAssertEqual(note.byteCount, source.lengthOfBytes(using: .utf8))
        XCTAssertTrue(note.isTemporary)
        XCTAssertEqual(context.recent.currentURL, recentURL)
        XCTAssertTrue(context.recent.rememberedURLs.isEmpty)

        context.native.clipboardSource = " \n\t "
        context.model.createClipboardMemo()
        guard case let .failure(message) = context.model.state else {
            return XCTFail("Expected blank clipboard recovery state")
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("clipboard"))
        XCTAssertEqual(context.recent.currentURL, recentURL)
    }

    func testCopyAndShareUseCurrentOriginalMarkdownWithoutChangingReaderState() {
        let context = makeContext()
        let url = fileURL("Unsafe name.mdx")
        let source = "# Original\n\n**Markdown**, not rendered text.\n"
        let note = makeNote(url: url, filename: "Unsafe name.mdx", source: source)
        context.loader.results[url] = .success(note)
        context.model.open(urls: [url])

        context.model.copyMarkdown()
        context.model.shareMarkdown()

        XCTAssertEqual(context.native.copiedSources, [source])
        XCTAssertEqual(context.native.sharedRequests, [
            .init(filename: "Unsafe name.mdx", source: source),
        ])
        XCTAssertEqual(context.model.state, .reading(note))
    }

    private func makeContext(
        recentURL: URL? = nil,
        theme: ThemePreference = .system,
        typeScale: TypeScale = .standard
    ) -> TestContext {
        let loader = FakeNoteLoader()
        let recent = FakeRecentDocuments(currentURL: recentURL)
        let preferences = FakeAppPreferences(theme: theme, typeScale: typeScale)
        let native = FakeNativeServices()
        let model = AppModel(
            loader: loader,
            recentDocuments: recent,
            preferences: preferences,
            nativeServices: native
        )
        return TestContext(
            model: model,
            loader: loader,
            recent: recent,
            preferences: preferences,
            native: native
        )
    }

    private func makeNote(
        url: URL,
        filename: String,
        source: String = "# Note\n"
    ) -> ReaderNote {
        ReaderNote(
            fileURL: url,
            filename: filename,
            source: source,
            byteCount: source.lengthOfBytes(using: .utf8),
            isTemporary: false
        )
    }

    private func fileURL(_ path: String) -> URL {
        URL(fileURLWithPath: "/test-files").appendingPathComponent(path)
    }
}

@MainActor
private struct TestContext {
    let model: AppModel
    let loader: FakeNoteLoader
    let recent: FakeRecentDocuments
    let preferences: FakeAppPreferences
    let native: FakeNativeServices
}

@MainActor
private final class FakeNoteLoader: NoteLoading {
    var results: [URL: Result<ReaderNote, Error>] = [:]
    private(set) var loadedURLs: [URL] = []

    func load(_ url: URL) throws -> ReaderNote {
        loadedURLs.append(url)
        guard let result = results[url] else {
            throw TestError.missingFixture
        }
        return try result.get()
    }
}

@MainActor
private final class FakeRecentDocuments: RecentDocumentProviding {
    var currentURL: URL?
    var rememberError: Error?
    private(set) var rememberedURLs: [URL] = []
    private(set) var rememberAttempts: [URL] = []
    private(set) var clearCount = 0

    init(currentURL: URL?) {
        self.currentURL = currentURL
    }

    var hasRecentDocument: Bool { currentURL != nil }

    func resolveRecentDocument() throws -> URL? {
        currentURL
    }

    func remember(_ url: URL) throws {
        rememberAttempts.append(url)
        if let rememberError {
            throw rememberError
        }
        rememberedURLs.append(url)
        currentURL = url
    }

    func clearRecentDocument() {
        clearCount += 1
        currentURL = nil
    }
}

@MainActor
private final class FakeAppPreferences: AppPreferencesProviding {
    var theme: ThemePreference
    var typeScale: TypeScale {
        didSet { savedScales.append(typeScale) }
    }
    private(set) var savedScales: [TypeScale] = []

    init(theme: ThemePreference, typeScale: TypeScale) {
        self.theme = theme
        self.typeScale = typeScale
    }
}

@MainActor
private final class FakeNativeServices: NativeServicesProviding {
    struct ShareRequest: Equatable {
        let filename: String
        let source: String
    }

    var openPanelResult: URL?
    var clipboardSource: String?
    private(set) var copiedSources: [String] = []
    private(set) var sharedRequests: [ShareRequest] = []

    func chooseDocument() -> URL? {
        openPanelResult
    }

    func readClipboardMarkdown() -> String? {
        clipboardSource
    }

    func copyMarkdown(_ source: String) {
        copiedSources.append(source)
    }

    @discardableResult
    func shareMarkdown(filename: String, source: String) throws -> URL {
        sharedRequests.append(.init(filename: filename, source: source))
        return URL(fileURLWithPath: "/temporary-share/shared.md")
    }
}

private enum TestError: LocalizedError {
    case bookmarkPersistence
    case missingFixture
    case secretPath

    var errorDescription: String? {
        switch self {
        case .bookmarkPersistence:
            "Could not persist security-scoped bookmark."
        case .missingFixture:
            "Missing test fixture."
        case .secretPath:
            "Could not read /Users/secret/private/bad.md"
        }
    }
}
