import Foundation
import Darwin

public enum DocumentLoaderError: Error, Equatable {
    case unreadable
    case fileTooLarge
}

public struct LoadedDocument: Equatable {
    public let source: String
    public let filename: String
    public let byteSize: Int

    public init(source: String, filename: String, byteSize: Int) {
        self.source = source
        self.filename = filename
        self.byteSize = byteSize
    }
}

public enum DocumentLoader {
    public static let maximumByteSize = 5 * 1024 * 1024

    public static func load(from url: URL) throws -> LoadedDocument {
        var metadata = stat()
        let resolvedURL = url.resolvingSymlinksInPath()
        let metadataResult = resolvedURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return Darwin.lstat(path, &metadata)
        }
        guard metadataResult == 0 else {
            throw DocumentLoaderError.unreadable
        }
        if Int(metadata.st_size) > maximumByteSize {
            throw DocumentLoaderError.fileTooLarge
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DocumentLoaderError.unreadable
        }

        guard data.count <= maximumByteSize else {
            throw DocumentLoaderError.fileTooLarge
        }

        return LoadedDocument(
            source: String(decoding: data, as: UTF8.self),
            filename: url.lastPathComponent,
            byteSize: data.count
        )
    }
}
