import AppKit
import Foundation
import LumaMDCore
import SwiftUI
@preconcurrency import WebKit

#if LUMA_MD_QA
@MainActor
enum NativeQACapture {
    private static let processStartedAt = ProcessInfo.processInfo.systemUptime
    private static var actionStartedAt: TimeInterval?
    private static var didConfigureWindow = false
    private static var auditedAccessibilityNames = Set<String>()

    nonisolated static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["LUMA_MD_QA_RUN_ID"] != nil
    }

    static var elapsedMilliseconds: Int {
        let baseline = actionStartedAt ?? processStartedAt
        return Int((ProcessInfo.processInfo.systemUptime - baseline) * 1_000)
    }

    static func startRunClock() {
        _ = processStartedAt
    }

    static func markActionStarted(_ action: String) {
        actionStartedAt = ProcessInfo.processInfo.systemUptime
        log("timing-start action=\(action)")
    }

    static func captureWindow(named name: String) {
        guard isEnabled else { return }
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow
                ?? NSApp.mainWindow
                ?? NSApp.windows.first(where: \.isVisible),
                  let contentView = window.contentView
            else {
                log("capture-window=\(name) result=missing-window")
                return
            }

            configureWindow(window)
            auditAccessibilityIfRequested(window, captureName: name)
            let view = contentView
            let bounds = view.bounds
            guard let representation = view.bitmapImageRepForCachingDisplay(in: bounds) else {
                log("capture-window=\(name) result=missing-bitmap")
                return
            }
            view.cacheDisplay(in: bounds, to: representation)
            write(representation: representation, named: name)
        }
    }

    static func configureWindow(_ window: NSWindow) {
        guard isEnabled, !didConfigureWindow,
              let value = ProcessInfo.processInfo.environment["LUMA_MD_QA_WINDOW_SIZE"]
        else {
            return
        }
        let components = value.split(separator: "x", maxSplits: 1)
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]),
              width > 0,
              height > 0
        else {
            log("window-size=\(value) result=invalid")
            return
        }
        didConfigureWindow = true
        window.setContentSize(NSSize(width: width, height: height))
        log("window-size=\(Int(width))x\(Int(height)) result=PASS")
    }

    static func captureWebView(_ webView: WKWebView, named name: String) {
        guard isEnabled else { return }
        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        webView.takeSnapshot(with: configuration) { image, error in
            if let error {
                log("capture-web=\(name) result=error detail=\(error.localizedDescription)")
                return
            }
            guard let image,
                  let tiff = image.tiffRepresentation,
                  let representation = NSBitmapImageRep(data: tiff)
            else {
                log("capture-web=\(name) result=missing-bitmap")
                return
            }
            write(representation: representation, named: name)
        }
    }

    static func captureBottomIfRequested(_ webView: WKWebView) {
        guard ProcessInfo.processInfo.environment["LUMA_MD_QA_CAPTURE_BOTTOM"] == "1"
        else {
            return
        }
        let source = """
        (() => {
          const root = document.scrollingElement || document.documentElement;
          root.scrollTop = root.scrollHeight;
          return {
            scrollY: root.scrollTop,
            scrollHeight: root.scrollHeight,
            clientHeight: root.clientHeight
          };
        })();
        """
        webView.evaluateJavaScript(source) { result, error in
            guard error == nil, let values = result as? [String: Any] else {
                log(
                    "capture-bottom result=error detail=\(error?.localizedDescription ?? "missing result")"
                )
                return
            }
            log("capture-bottom result=PASS dom=\(values)")
            captureWebView(webView, named: "reader-bottom")
        }
    }

    private static func auditAccessibilityIfRequested(
        _ window: NSWindow,
        captureName: String
    ) {
        let requested = ProcessInfo.processInfo.environment["LUMA_MD_QA_ACCESSIBILITY"]
        guard requested == "1" || requested == captureName else {
            return
        }
        guard auditedAccessibilityNames.insert(captureName).inserted else {
            return
        }

        window.contentView?.layoutSubtreeIfNeeded()
        var visited = Set<ObjectIdentifier>()
        var nodeCount = 0
        var controlCount = 0
        var unlabeledControlCount = 0
        var identifiers = [String]()
        var controlDetails = [String]()

        func walk(_ candidate: Any) {
            guard let object = candidate as? NSObject else { return }
            let identity = ObjectIdentifier(object)
            guard visited.insert(identity).inserted else { return }

            func accessibilityValue(_ selectorName: String) -> Any? {
                let selector = NSSelectorFromString(selectorName)
                guard object.responds(to: selector) else { return nil }
                return object.perform(selector)?.takeUnretainedValue()
            }

            let role = accessibilityValue("accessibilityRole") as? String
            let label = accessibilityValue("accessibilityLabel") as? String
            let title = accessibilityValue("accessibilityTitle") as? String
            let help = accessibilityValue("accessibilityHelp") as? String
            let identifier = accessibilityValue("accessibilityIdentifier") as? String
            let children = accessibilityValue("accessibilityChildren") as? [Any] ?? []
            nodeCount += 1
            if let identifier, !identifier.isEmpty {
                identifiers.append(identifier)
            }
            let controlRoles = [
                NSAccessibility.Role.button.rawValue,
                NSAccessibility.Role.link.rawValue,
                NSAccessibility.Role.popUpButton.rawValue,
                NSAccessibility.Role.checkBox.rawValue,
                NSAccessibility.Role.radioButton.rawValue,
            ]
            let isSystemWindowControl = String(describing: type(of: object))
                .contains("NSTheme")
            if let role, controlRoles.contains(role), !isSystemWindowControl {
                controlCount += 1
                let effectiveLabel = [label, title, help, identifier]
                    .compactMap { $0 }
                    .first { !$0.isEmpty }
                controlDetails.append(
                    "\(role):\(effectiveLabel ?? "unlabeled"):\(type(of: object))"
                )
                if effectiveLabel == nil {
                    unlabeledControlCount += 1
                }
            }
            children.forEach(walk)
        }
        walk(window)

        window.makeFirstResponder(nil)
        window.selectNextKeyView(nil)
        let firstResponder = window.firstResponder
        window.selectNextKeyView(nil)
        let secondResponder = window.firstResponder
        let focusPassed = firstResponder != nil
            && firstResponder !== window
            && secondResponder != nil

        let requiredShortcuts: [(String, String, NSEvent.ModifierFlags)] = [
            ("Open…", "o", .command),
            ("Home", "1", .command),
            ("Copy Markdown", "c", [.command, .shift]),
            ("Share Markdown…", "s", [.command, .shift]),
            ("Create Clipboard Memo", "v", [.command, .shift]),
            ("Small Text", "-", .command),
            ("Default Text", "0", .command),
            ("Large Text", "=", .command),
        ]
        let menuItems = allMenuItems(in: NSApp.mainMenu)
        let shortcutsPassed = requiredShortcuts.allSatisfy { title, key, modifiers in
            menuItems.contains { item in
                item.title == title
                    && item.keyEquivalent == key
                    && item.keyEquivalentModifierMask.contains(modifiers)
            }
        }
        let availableShortcuts = menuItems.compactMap { item -> String? in
            guard !item.keyEquivalent.isEmpty else { return nil }
            return "\(item.title)=\(item.keyEquivalent):\(item.keyEquivalentModifierMask.rawValue)"
        }

        let accessibilityPassed = nodeCount > 0
            && controlCount > 0
            && unlabeledControlCount == 0
        log(
            "accessibility capture=\(captureName) result=\(accessibilityPassed ? "PASS" : "FAIL") keyWindow=\(window.isKeyWindow) nodes=\(nodeCount) controls=\(controlCount) unlabeled=\(unlabeledControlCount) identifiers=\(identifiers.sorted()) details=\(controlDetails)"
        )
        log(
            "keyboard-focus capture=\(captureName) result=\(focusPassed ? "PASS" : "FAIL") first=\(String(describing: firstResponder.map { type(of: $0) })) second=\(String(describing: secondResponder.map { type(of: $0) }))"
        )
        log(
            "menu-shortcuts result=\(shortcutsPassed ? "PASS" : "FAIL") required=\(requiredShortcuts.count) available=\(availableShortcuts)"
        )
    }

    private static func allMenuItems(in menu: NSMenu?) -> [NSMenuItem] {
        guard let menu else { return [] }
        return menu.items.flatMap { item in
            [item] + allMenuItems(in: item.submenu)
        }
    }

    static func captureOutline(_ headings: [MarkdownDocument.Heading]) {
        guard isEnabled else { return }
        let view = NSHostingView(
            rootView: OutlinePopover(
                headings: headings,
                selectHeading: { _ in }
            )
            .preferredColorScheme(.light)
            .background(Color(nsColor: .windowBackgroundColor))
            .frame(width: 330)
        )
        view.frame = NSRect(x: 0, y: 0, width: 330, height: 460)
        view.layoutSubtreeIfNeeded()
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            log("capture-outline result=missing-bitmap")
            return
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        write(representation: representation, named: "outline-hierarchy")
    }

    nonisolated static func log(_ message: String) {
        guard isEnabled else { return }
        let line = "LUMA_QA \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
        guard let directory = try? evidenceDirectory() else { return }
        let logURL = directory.appendingPathComponent("actions.log")
        let data = Data(line.utf8)
        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }

    private static func write(
        representation: NSBitmapImageRep,
        named name: String
    ) {
        guard let png = representation.representation(using: .png, properties: [:]),
              let directory = try? evidenceDirectory()
        else {
            log("capture=\(name) result=encoding-failed")
            return
        }
        let url = directory.appendingPathComponent("\(safeName(name)).png")
        do {
            try png.write(to: url, options: .atomic)
            log(
                "capture=\(name) result=PASS path=\(url.path) bytes=\(png.count) elapsed-ms=\(elapsedMilliseconds)"
            )
        } catch {
            log("capture=\(name) result=write-failed detail=\(error.localizedDescription)")
        }
    }

    nonisolated private static func evidenceDirectory() throws -> URL {
        let runID = ProcessInfo.processInfo.environment["LUMA_MD_QA_RUN_ID"] ?? "default"
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumaMD-QA-\(safeName(runID))", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    nonisolated private static func safeName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let name = value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
        return name.isEmpty ? "capture" : name
    }
}
#else
@MainActor
enum NativeQACapture {
    nonisolated static var isEnabled: Bool { false }
    static var elapsedMilliseconds: Int { 0 }

    static func startRunClock() {}
    static func markActionStarted(_ action: String) {}
    static func captureWindow(named name: String) {}
    static func configureWindow(_ window: NSWindow) {}
    static func captureWebView(_ webView: WKWebView, named name: String) {}
    static func captureBottomIfRequested(_ webView: WKWebView) {}
    static func captureOutline(_ headings: [MarkdownDocument.Heading]) {}
    nonisolated static func log(_ message: String) {}
}
#endif
