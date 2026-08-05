import Foundation
import XCTest
import LumaMDCore

final class DocumentLoaderTests: XCTestCase {
    private let fiveMiB = 5 * 1024 * 1024

    func testExactlyFiveMiBLoadsSuccessfully() throws {
        let fileURL = try temporaryFile(named: "exact-limit.md")
        let bytes = Data(repeating: Character("a").asciiValue!, count: fiveMiB)
        try bytes.write(to: fileURL)

        let document = try DocumentLoader.load(from: fileURL)

        XCTAssertEqual(document.source.utf8.count, fiveMiB)
        XCTAssertEqual(document.byteSize, fiveMiB)
        XCTAssertEqual(document.filename, "exact-limit.md")
    }

    func testFiveMiBPlusOneByteThrowsTypedTooLargeError() throws {
        let fileURL = try temporaryFile(named: "over-limit.md")
        try Data(repeating: 0x61, count: fiveMiB + 1).write(to: fileURL)

        XCTAssertThrowsError(try DocumentLoader.load(from: fileURL)) { error in
            guard let loadingError = error as? DocumentLoaderError else {
                return XCTFail("Expected DocumentLoaderError, got \(type(of: error))")
            }
            XCTAssertEqual(loadingError, .fileTooLarge)
        }
    }

    func testOversizedMetadataWinsBeforeUnreadableContent() throws {
        let fileURL = try temporaryFile(named: "oversized-unreadable.md")
        try Data(repeating: 0x61, count: fiveMiB + 1).write(to: fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: fileURL.path
        )
        addTeardownBlock {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        }
        do {
            _ = try DocumentLoader.load(from: fileURL)
            XCTFail("Expected oversized file to be rejected before reading")
        } catch let error as DocumentLoaderError {
            XCTAssertEqual(error, .fileTooLarge)
        } catch {
            XCTFail("Expected DocumentLoaderError, got \(type(of: error))")
        }
    }

    func testMalformedUTF8UsesDeterministicReplacementCharacters() throws {
        let fileURL = try temporaryFile(named: "malformed.md")
        let bytes = Data([0x66, 0x80, 0x6f, 0xc3, 0x28])
        try bytes.write(to: fileURL)

        let document = try DocumentLoader.load(from: fileURL)

        XCTAssertEqual(document.source, "f\u{fffd}o\u{fffd}(")
        XCTAssertEqual(document.byteSize, bytes.count)
    }

    func testFilenameAndOriginalByteSizeAreRetained() throws {
        let fileURL = try temporaryFile(named: "한국어-note.md")
        let source = "안녕"
        try XCTUnwrap(source.data(using: .utf8)).write(to: fileURL)

        let document = try DocumentLoader.load(from: fileURL)

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.filename, "한국어-note.md")
        XCTAssertEqual(document.byteSize, 6, "Byte size must describe the original UTF-8 data, not character count")
    }

    func testUnreadableURLThrowsTypedUnreadableError() throws {
        let directory = try temporaryDirectory()
        let missingURL = directory.appendingPathComponent("missing.md", isDirectory: false)

        do {
            _ = try DocumentLoader.load(from: missingURL)
            XCTFail("Expected missing file to be unreadable")
        } catch let error as DocumentLoaderError {
            XCTAssertEqual(error, .unreadable)
        } catch {
            XCTFail("Expected DocumentLoaderError, got \(type(of: error))")
        }
    }

    private func temporaryFile(named filename: String) throws -> URL {
        try temporaryDirectory().appendingPathComponent(filename, isDirectory: false)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumaMD-DocumentLoaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
