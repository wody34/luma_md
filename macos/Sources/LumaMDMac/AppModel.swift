import Combine
import Foundation
import LumaMDCore
import OSLog

private let appModelLogger = Logger(
    subsystem: "dev.lumamd.viewer.macos",
    category: "recent-document"
)

public enum ThemePreference: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum TypeScale: String, CaseIterable, Sendable {
    case small
    case standard
    case large
}

public struct ReaderNote: Equatable, Sendable {
    public let fileURL: URL?
    public let filename: String
    public let source: String
    public let byteCount: Int
    public let isTemporary: Bool

    public init(
        fileURL: URL?,
        filename: String,
        source: String,
        byteCount: Int,
        isTemporary: Bool
    ) {
        self.fileURL = fileURL
        self.filename = filename
        self.source = source
        self.byteCount = byteCount
        self.isTemporary = isTemporary
    }
}

public enum AppState: Equatable, Sendable {
    case welcome
    case reading(ReaderNote)
    case failure(String)
}

@MainActor
public protocol NoteLoading: AnyObject {
    func load(_ url: URL) throws -> ReaderNote
}

@MainActor
public protocol RecentDocumentProviding: AnyObject {
    var hasRecentDocument: Bool { get }

    func resolveRecentDocument() throws -> URL?
    func remember(_ url: URL) throws
    func clearRecentDocument()
}

@MainActor
public protocol AppPreferencesProviding: AnyObject {
    var theme: ThemePreference { get set }
    var typeScale: TypeScale { get set }
}

@MainActor
public protocol NativeServicesProviding: AnyObject {
    func chooseDocument() -> URL?
    func readClipboardMarkdown() -> String?
    func copyMarkdown(_ source: String)

    @discardableResult
    func shareMarkdown(filename: String, source: String) throws -> URL
}

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var state: AppState
    @Published public private(set) var theme: ThemePreference
    @Published public private(set) var typeScale: TypeScale

    public var hasRecentDocument: Bool {
        recentDocuments.hasRecentDocument
    }

    private static let supportedExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mdx", "txt",
    ]

    private let loader: any NoteLoading
    private let recentDocuments: any RecentDocumentProviding
    private let preferences: any AppPreferencesProviding
    private let nativeServices: any NativeServicesProviding

    public init(
        loader: any NoteLoading,
        recentDocuments: any RecentDocumentProviding,
        preferences: any AppPreferencesProviding,
        nativeServices: any NativeServicesProviding
    ) {
        self.loader = loader
        self.recentDocuments = recentDocuments
        self.preferences = preferences
        self.nativeServices = nativeServices
        state = .welcome
        theme = preferences.theme
        typeScale = preferences.typeScale
    }

    public func openDocument() {
        guard let url = nativeServices.chooseDocument() else {
            return
        }
        NativeQACapture.markActionStarted("open-panel")
        open(url: url, clearRecentOnFailure: false)
    }

    public func open(urls: [URL]) {
        guard let url = urls.first(where: Self.isSupportedDocument) else {
            return
        }
        NativeQACapture.markActionStarted("open-urls")
        open(url: url, clearRecentOnFailure: false)
    }

    public func openRecent() {
        let url: URL
        do {
            guard let resolvedURL = try recentDocuments.resolveRecentDocument() else {
                recentDocuments.clearRecentDocument()
                state = .failure("The recent document is no longer available.")
                return
            }
            url = resolvedURL
        } catch {
            recentDocuments.clearRecentDocument()
            state = .failure("The recent document could not be reopened.")
            return
        }

        open(
            url: url,
            clearRecentOnFailure: true,
            rememberDocument: false
        )
    }

    public func goHome() {
        state = .welcome
    }

    public func clearRecent() {
        recentDocuments.clearRecentDocument()
        objectWillChange.send()
    }

    public func setTheme(_ theme: ThemePreference) {
        self.theme = theme
        preferences.theme = theme
    }

    public func setTypeScale(_ typeScale: TypeScale) {
        self.typeScale = typeScale
        preferences.typeScale = typeScale
    }

    public func cycleTypeScale() {
        switch typeScale {
        case .small:
            setTypeScale(.standard)
        case .standard:
            setTypeScale(.large)
        case .large:
            setTypeScale(.small)
        }
    }

    public func createClipboardMemo() {
        guard
            let source = nativeServices.readClipboardMarkdown(),
            !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            state = .failure("The clipboard does not contain any Markdown text.")
            return
        }

        state = .reading(ReaderNote(
            fileURL: nil,
            filename: "Clipboard memo.md",
            source: source,
            byteCount: source.lengthOfBytes(using: .utf8),
            isTemporary: true
        ))
    }

    public func copyMarkdown() {
        guard case let .reading(note) = state else {
            return
        }
        nativeServices.copyMarkdown(note.source)
    }

    public func shareMarkdown() {
        guard case let .reading(note) = state else {
            return
        }

        do {
            try nativeServices.shareMarkdown(filename: note.filename, source: note.source)
        } catch {
            state = .failure("Could not share \"\(note.filename)\".")
        }
    }

    private static func isSupportedDocument(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    private func open(
        url: URL,
        clearRecentOnFailure: Bool,
        rememberDocument: Bool = true
    ) {
        let note: ReaderNote
        do {
            note = try loader.load(url)
        } catch {
            if clearRecentOnFailure {
                recentDocuments.clearRecentDocument()
            }
            state = .failure("Could not open \"\(url.lastPathComponent)\". Check that the file is available and readable.")
            return
        }

        if rememberDocument {
            do {
                try recentDocuments.remember(url)
            } catch {
                appModelLogger.error(
                    "Could not persist recent bookmark: \(String(describing: error), privacy: .private)"
                )
                NativeQACapture.log(
                    "bookmark-create result=ignored-error filename=\(url.lastPathComponent)"
                )
            }
        }
        state = .reading(note)
    }
}
