import Foundation
import XCTest
import LumaMDMac

@MainActor
final class OpenRequestBrokerTests: XCTestCase {
    func testEventsReceivedBeforeHandlerInstallationAreBufferedAndDeliveredExactlyOnce() {
        let broker = OpenRequestBroker()
        let firstEvent = [fileURL("first.md"), fileURL("also-first.txt")]
        let secondEvent = [fileURL("second.mdx")]
        var deliveries: [[URL]] = []

        broker.receive(firstEvent)
        broker.receive(secondEvent)
        XCTAssertTrue(deliveries.isEmpty)

        broker.installHandler { deliveries.append($0) }

        XCTAssertEqual(deliveries, [firstEvent, secondEvent])

        let warmEvent = [fileURL("warm.markdown")]
        broker.receive(warmEvent)
        XCTAssertEqual(deliveries, [firstEvent, secondEvent, warmEvent])
    }

    func testInstallingHandlerBeforeAnyEventRoutesEachEventDirectlyWithoutReplay() {
        let broker = OpenRequestBroker()
        var deliveries: [[URL]] = []
        broker.installHandler { deliveries.append($0) }

        let first = [fileURL("one.mdown")]
        let second = [fileURL("two.mkd"), fileURL("three.md")]
        broker.receive(first)
        broker.receive(second)

        XCTAssertEqual(deliveries, [first, second])
        XCTAssertEqual(deliveries.flatMap { $0 }, first + second)
    }

    private func fileURL(_ filename: String) -> URL {
        URL(fileURLWithPath: "/finder-events").appendingPathComponent(filename)
    }
}
