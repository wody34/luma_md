@preconcurrency import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
public protocol PasteboardAccess: AnyObject {
    func readString() -> String?
    func replaceString(_ source: String)
}

@MainActor
public protocol SharePresenting: AnyObject {
    func present(fileURL: URL, completion: @escaping () -> Void)
}

public struct ShareFileStore {
    private let fileManager: FileManager
    private let shareDirectory: URL

    public init(
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        shareDirectory = temporaryDirectory.appendingPathComponent(
            "LumaMDShare",
            isDirectory: true
        )
    }

    public func prepare(filename: String, source: String) throws -> URL {
        try cleanup()
        try fileManager.createDirectory(
            at: shareDirectory,
            withIntermediateDirectories: false
        )

        let fileURL = shareDirectory.appendingPathComponent(
            Self.sanitizedFilename(filename),
            isDirectory: false
        )
        try Data(source.utf8).write(to: fileURL, options: .atomic)
        return fileURL
    }

    public func cleanup() throws {
        guard fileManager.fileExists(atPath: shareDirectory.path) else { return }
        try fileManager.removeItem(at: shareDirectory)
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:")
            .union(.controlCharacters)
        let singleLevelName = filename.unicodeScalars.map { scalar in
            forbidden.contains(scalar) ? "_" : String(scalar)
        }.joined()

        let basename = (singleLevelName as NSString).deletingPathExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let usableBasename = basename.isEmpty || basename == "." || basename == ".."
            ? "Shared Markdown"
            : basename
        return "\(usableBasename).md"
    }
}

@MainActor
public final class NativeServices: NativeServicesProviding {
    private let pasteboard: any PasteboardAccess
    private let shareFiles: ShareFileStore
    private let sharePresenter: any SharePresenting

    public init() {
        pasteboard = AppKitPasteboard()
        shareFiles = ShareFileStore()
        sharePresenter = AppKitSharePresenter()
    }

    public init(
        pasteboard: any PasteboardAccess,
        shareFiles: ShareFileStore,
        sharePresenter: any SharePresenting
    ) {
        self.pasteboard = pasteboard
        self.shareFiles = shareFiles
        self.sharePresenter = sharePresenter
    }

    public func chooseDocument() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            "md", "markdown", "mdown", "mkd", "mdx", "txt",
        ].compactMap { UTType(filenameExtension: $0) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    public func readClipboardMarkdown() -> String? {
        guard let source = pasteboard.readString(),
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return source
    }

    public func copyMarkdown(_ source: String) {
        pasteboard.replaceString(source)
    }

    @discardableResult
    public func shareMarkdown(filename: String, source: String) throws -> URL {
        let fileURL = try shareFiles.prepare(filename: filename, source: source)
        sharePresenter.present(fileURL: fileURL) { [shareFiles] in
            try? shareFiles.cleanup()
        }
        return fileURL
    }
}

@MainActor
private final class AppKitPasteboard: PasteboardAccess {
    func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func replaceString(_ source: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(source, forType: .string)
    }
}

@MainActor
private final class AppKitSharePresenter: NSObject, SharePresenting {
    private var activePresentation: SharePresentation?

    func present(fileURL: URL, completion: @escaping () -> Void) {
        activePresentation?.finish()

        if QAEnvironment[.share] == "1" {
            let data = (try? Data(contentsOf: fileURL)) ?? Data()
            NativeQACapture.log(
                "share-present filename=\(fileURL.lastPathComponent) bytes=\(data.count) base64=\(data.base64EncodedString())"
            )
        }

        guard let view = NSApp.keyWindow?.contentView
            ?? NSApp.mainWindow?.contentView
            ?? NSApp.windows.first?.contentView
        else {
            NativeQACapture.log("share-picker result=missing-window")
            completion()
            return
        }

        let presentation = SharePresentation(completion: {
            completion()
            if QAEnvironment[.share] == "1" {
                NativeQACapture.log(
                    "share-cleanup result=\(FileManager.default.fileExists(atPath: fileURL.path) ? "FAILED" : "PASS") path=\(fileURL.path)"
                )
            }
        }) { [weak self] in
            self?.activePresentation = nil
        }
        activePresentation = presentation
        presentation.show(fileURL: fileURL, from: view)
    }
}

@MainActor
private final class SharePresentation: NSObject,
    @preconcurrency NSSharingServicePickerDelegate,
    NSSharingServiceDelegate
{
    private var picker: NSSharingServicePicker?
    private var completion: (() -> Void)?
    private let didFinish: () -> Void

    init(completion: @escaping () -> Void, didFinish: @escaping () -> Void) {
        self.completion = completion
        self.didFinish = didFinish
    }

    func show(fileURL: URL, from view: NSView) {
        let picker = NSSharingServicePicker(items: [fileURL])
        picker.delegate = self
        self.picker = picker
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        if QAEnvironment[.share] == "1" {
            NativeQACapture.log("share-picker result=shown")
        }
        if QAEnvironment[.cancelShare] == "1" {
            DispatchQueue.main.async { [weak self] in
                NativeQACapture.log("share-picker result=cancelled")
                self?.finish()
            }
        }
    }

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        didChoose service: NSSharingService?
    ) {
        if service == nil {
            if QAEnvironment[.share] == "1" {
                NativeQACapture.log("share-picker result=cancelled")
            }
            finish()
        }
    }

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        delegateFor sharingService: NSSharingService
    ) -> NSSharingServiceDelegate? {
        self
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish()
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        finish()
    }

    func finish() {
        guard let completion else { return }
        self.completion = nil
        picker = nil
        completion()
        didFinish()
    }
}
