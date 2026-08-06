import AppKit
import LumaMDMac
import XCTest

@MainActor
final class WindowPresentationTests: XCTestCase {
    func testAdaptiveBorderlessPresentationKeepsNativeWindowCapabilities() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_080, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        let availableFrame = NSRect(x: 0, y: 0, width: 900, height: 650)

        AppDelegate.configureWindow(window, within: availableFrame)

        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertTrue(window.standardWindowButton(.closeButton)?.isHidden == true)
        XCTAssertTrue(window.standardWindowButton(.miniaturizeButton)?.isHidden == true)
        XCTAssertTrue(window.standardWindowButton(.zoomButton)?.isHidden == true)
        XCTAssertTrue(window.frame.width <= availableFrame.width)
        XCTAssertTrue(window.frame.height <= availableFrame.height)
    }

    func testClosingTheLastWindowTerminatesTheApplication() {
        XCTAssertTrue(
            AppDelegate().applicationShouldTerminateAfterLastWindowClosed(.shared)
        )
    }
}
