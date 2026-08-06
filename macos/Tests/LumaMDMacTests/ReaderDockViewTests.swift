import Foundation
import XCTest
@testable import LumaMDMac

final class ReaderDockViewTests: XCTestCase {
    func testPrimaryReaderDockExposesDedicatedOutlineButton() {
        XCTAssertEqual(
            ReaderDockAction.primary,
            [.copy, .share, .outline, .open],
            "The primary reader dock must expose the outline control directly."
        )
    }

    func testOutlinePanelStaysInsideCompactAndLargeReaderBounds() {
        for size in [
            CGSize(width: 720, height: 520),
            CGSize(width: 1_080, height: 760),
            CGSize(width: 1_600, height: 1_000),
        ] {
            let width = ReaderOutlineLayout.panelWidth(for: size.width)
            let height = ReaderOutlineLayout.panelMaximumHeight(for: size.height)

            XCTAssertGreaterThan(width, 0)
            XCTAssertTrue(
                width + ReaderOutlineLayout.sideInset * 2 <= size.width
            )
            XCTAssertGreaterThan(height, 0)
            XCTAssertTrue(
                height + ReaderOutlineLayout.topInset
                    + ReaderOutlineLayout.dockClearance <= size.height
            )
        }
    }

    func testOutlinePanelTextContrastExceedsWCAGAAInBothThemes() {
        let lightContrast = OutlinePanelPalette.contrastRatio(
            foreground: OutlinePanelPalette.lightForeground,
            surface: OutlinePanelPalette.lightSurface
        )
        let darkContrast = OutlinePanelPalette.contrastRatio(
            foreground: OutlinePanelPalette.darkForeground,
            surface: OutlinePanelPalette.darkSurface
        )

        XCTAssertTrue(lightContrast >= 4.5)
        XCTAssertTrue(darkContrast >= 4.5)
    }

    func testOutlinePanelProvidesModalFocusAndDismissalContracts() throws {
        let readerSource = try source(
            at: "macos/Sources/LumaMDMac/ReaderView.swift"
        )
        let panelSource = try source(
            at: "macos/Sources/LumaMDMac/OutlinePopover.swift"
        )

        XCTAssertTrue(readerSource.components(
            separatedBy: ".accessibilityHidden(showsOutline)"
        ).count == 3)
        XCTAssertTrue(readerSource.components(
            separatedBy: ".allowsHitTesting(!showsOutline)"
        ).count == 3)
        XCTAssertTrue(readerSource.contains("focusedDockAction = .outline"))
        XCTAssertTrue(panelSource.contains("focusedTarget = .close"))
        XCTAssertTrue(panelSource.contains(".keyboardShortcut(.cancelAction)"))
        XCTAssertTrue(panelSource.contains("NSEvent.addLocalMonitorForEvents"))
        XCTAssertTrue(panelSource.contains("event.keyCode == 48"))
        XCTAssertTrue(panelSource.contains("NSEvent.removeMonitor(keyboardMonitor)"))
        XCTAssertTrue(panelSource.contains(".onExitCommand(perform: dismiss)"))
        XCTAssertTrue(panelSource.contains(".accessibilityAddTraits(.isModal)"))
        XCTAssertTrue(panelSource.contains(".accessibilityLabel(\"Close Outline\")"))
    }

    func testWelcomePrivacyCopyAcknowledgesExplicitSharing() throws {
        let source = try source(
            at: "macos/Sources/LumaMDMac/WelcomeView.swift"
        )

        XCTAssertTrue(source.contains(
            "Your notes stay local until you choose to share."
        ))
        XCTAssertFalse(source.contains("Nothing leaves your Mac."))
    }

    private func source(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
