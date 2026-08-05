import Foundation
import XCTest
import LumaMDMac

@MainActor
final class NativeServicesTests: XCTestCase {
    func testClipboardReadAndCopyPreserveExactOriginalSource() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = "# Original\n\n- first\n- second  \n"
        let pasteboard = FakePasteboard(source: source)
        let presenter = FakeSharePresenter()
        let services = NativeServices(
            pasteboard: pasteboard,
            shareFiles: ShareFileStore(temporaryDirectory: root),
            sharePresenter: presenter
        )

        XCTAssertEqual(services.readClipboardMarkdown(), source)

        let replacement = "## Copy **this source**, not HTML.\n"
        services.copyMarkdown(replacement)

        XCTAssertEqual(pasteboard.writtenSources, [replacement])
        XCTAssertEqual(pasteboard.source, replacement)
    }

    func testShareSanitizesFilenameWritesExactSourceAndCleansUpOnCompletion() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = "# Shared\n\nKorean: 정확한 원문  \n"
        let pasteboard = FakePasteboard()
        let presenter = FakeSharePresenter()
        let services = NativeServices(
            pasteboard: pasteboard,
            shareFiles: ShareFileStore(temporaryDirectory: root),
            sharePresenter: presenter
        )

        let sharedURL = try services.shareMarkdown(
            filename: "Road/map\\Draft\n.mdx",
            source: source
        )

        XCTAssertEqual(sharedURL.lastPathComponent, "Road_map_Draft_.md")
        XCTAssertEqual(sharedURL.deletingLastPathComponent().deletingLastPathComponent(), root)
        XCTAssertEqual(try String(contentsOf: sharedURL, encoding: .utf8), source)
        XCTAssertEqual(presenter.presentedURLs, [sharedURL])
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedURL.path))

        presenter.completePresentation()

        XCTAssertFalse(FileManager.default.fileExists(atPath: sharedURL.path))
    }

    func testCleanupRemovesOnlyDedicatedShareDirectory() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let neighboringFile = root.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: neighboringFile)
        let store = ShareFileStore(temporaryDirectory: root)
        let preparedURL = try store.prepare(filename: "stale.markdown", source: "stale")
        let shareDirectory = preparedURL.deletingLastPathComponent()
        let secondStaleFile = shareDirectory.appendingPathComponent("older.md")
        try Data("older".utf8).write(to: secondStaleFile)

        try store.cleanup()

        XCTAssertFalse(FileManager.default.fileExists(atPath: shareDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: neighboringFile.path))
        XCTAssertEqual(try String(contentsOf: neighboringFile, encoding: .utf8), "keep")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumaMDMacTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }
}

@MainActor
private final class FakePasteboard: PasteboardAccess {
    var source: String?
    private(set) var writtenSources: [String] = []

    init(source: String? = nil) {
        self.source = source
    }

    func readString() -> String? {
        source
    }

    func replaceString(_ source: String) {
        writtenSources.append(source)
        self.source = source
    }
}

@MainActor
private final class FakeSharePresenter: SharePresenting {
    private(set) var presentedURLs: [URL] = []
    private var completion: (() -> Void)?

    func present(fileURL: URL, completion: @escaping () -> Void) {
        presentedURLs.append(fileURL)
        self.completion = completion
    }

    func completePresentation() {
        let pendingCompletion = completion
        completion = nil
        pendingCompletion?()
    }
}
