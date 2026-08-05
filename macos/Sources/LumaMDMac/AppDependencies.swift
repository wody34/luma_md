import Foundation
import LumaMDCore

@MainActor
public final class CoreNoteLoader: NoteLoading {
    public init() {}

    public func load(_ url: URL) throws -> ReaderNote {
        let accessed = url.startAccessingSecurityScopedResource()
        NativeQACapture.log(
            "security-scope start=\(accessed) readable=\(FileManager.default.isReadableFile(atPath: url.path)) path=\(url.path)"
        )
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if NativeQACapture.isEnabled,
           QAEnvironment[.forceUnreadable] == "1" {
            NativeQACapture.log("security-scope load=forced-unreadable")
            throw DocumentLoaderError.unreadable
        }

        let document: LoadedDocument
        do {
            document = try DocumentLoader.load(from: url)
        } catch {
            NativeQACapture.log(
                "security-scope load=error detail=\(error)"
            )
            throw error
        }
        return ReaderNote(
            fileURL: url,
            filename: document.filename,
            source: document.source,
            byteCount: document.byteSize,
            isTemporary: false
        )
    }
}

@MainActor
public final class CorePreferencesAdapter: AppPreferencesProviding {
    private let preferences: ReaderPreferences

    public init(preferences: ReaderPreferences = ReaderPreferences()) {
        self.preferences = preferences
    }

    public var theme: ThemePreference {
        get {
            switch preferences.theme {
            case .system:
                return .system
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
        set {
            switch newValue {
            case .system:
                preferences.theme = .system
            case .light:
                preferences.theme = .light
            case .dark:
                preferences.theme = .dark
            }
        }
    }

    public var typeScale: TypeScale {
        get {
            switch preferences.typeScale {
            case .small:
                return .small
            case .standard:
                return .standard
            case .large:
                return .large
            }
        }
        set {
            switch newValue {
            case .small:
                preferences.typeScale = .small
            case .standard:
                preferences.typeScale = .standard
            case .large:
                preferences.typeScale = .large
            }
        }
    }
}

public struct SecurityScopedBookmarkCodec: BookmarkCodec {
    public init() {}

    public func createBookmark(for url: URL) throws -> Data {
        if NativeQACapture.isEnabled,
           QAEnvironment[.forceBookmarkFailure] == "1" {
            NativeQACapture.log("bookmark-create result=forced-failure path=\(url.path)")
            throw CocoaError(.fileWriteNoPermission)
        }
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        NativeQACapture.log(
            "bookmark-create bytes=\(bookmark.count) path=\(url.path)"
        )
        return bookmark
    }

    public func resolveBookmark(_ bookmark: Data) throws -> BookmarkResolution {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        NativeQACapture.log(
            "bookmark-resolve stale=\(isStale) path=\(url.path)"
        )
        return BookmarkResolution(url: url, isStale: isStale)
    }
}

@MainActor
public final class CoreRecentDocuments: RecentDocumentProviding {
    private let store: RecentDocumentStore

    public init(
        defaults: UserDefaults = .standard,
        codec: any BookmarkCodec = SecurityScopedBookmarkCodec()
    ) {
        store = RecentDocumentStore(defaults: defaults, codec: codec)
    }

    public var hasRecentDocument: Bool {
        store.hasBookmark
    }

    public func resolveRecentDocument() throws -> URL? {
        try store.resolve()
    }

    public func remember(_ url: URL) throws {
        try store.store(url)
    }

    public func clearRecentDocument() {
        store.clear()
    }
}
