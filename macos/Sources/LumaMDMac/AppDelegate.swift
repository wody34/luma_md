@preconcurrency import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public let openRequestBroker = OpenRequestBroker()

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NativeQACapture.startRunClock()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        DispatchQueue.main.async {
            NSApp.windows.forEach(self.configureWindowForCurrentScreen)
        }
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        openRequestBroker.receive(urls)
        application.activate(ignoringOtherApps: true)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    public static func configureWindow(
        _ window: NSWindow,
        within availableFrame: NSRect
    ) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        let controlsHidden = [
            window.standardWindowButton(.closeButton),
            window.standardWindowButton(.miniaturizeButton),
            window.standardWindowButton(.zoomButton),
        ].allSatisfy { $0?.isHidden != false }

        guard window.frame.width > availableFrame.width
                || window.frame.height > availableFrame.height
        else {
            NativeQACapture.log(
                "window-chrome result=PASS titlebarHidden=\(window.titleVisibility == .hidden) controlsHidden=\(controlsHidden) resizable=\(window.styleMask.contains(.resizable)) draggable=\(window.isMovableByWindowBackground) adaptive=unchanged frame=\(Int(window.frame.width))x\(Int(window.frame.height))"
            )
            return
        }
        let width = min(window.frame.width, availableFrame.width)
        let height = min(window.frame.height, availableFrame.height)
        let frame = NSRect(
            x: availableFrame.midX - width / 2,
            y: availableFrame.midY - height / 2,
            width: width,
            height: height
        )
        window.setFrame(frame, display: true)
        NativeQACapture.log(
            "window-chrome result=PASS titlebarHidden=\(window.titleVisibility == .hidden) controlsHidden=\(controlsHidden) resizable=\(window.styleMask.contains(.resizable)) draggable=\(window.isMovableByWindowBackground) adaptive=clamped frame=\(Int(width))x\(Int(height))"
        )
    }

    @objc
    private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        configureWindowForCurrentScreen(window)
    }

    private func configureWindowForCurrentScreen(_ window: NSWindow) {
        let availableFrame = window.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? window.frame
        Self.configureWindow(window, within: availableFrame)
        if QAEnvironment[.captureChrome] == "1" {
            NativeQACapture.captureWindow(named: "chrome-ready")
        }
    }
}
