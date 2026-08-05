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
}
