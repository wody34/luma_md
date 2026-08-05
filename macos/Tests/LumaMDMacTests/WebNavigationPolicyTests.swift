import Foundation
import XCTest
import LumaMDMac

final class WebNavigationPolicyTests: XCTestCase {
    private let documentURL = URL(string: "https://luma.local/reader")!

    func testSameDocumentFragmentsStayInsideWebView() {
        let policy = WebNavigationPolicy(documentURL: documentURL)
        let relativeFragment = URL(string: "#overview", relativeTo: documentURL)!.absoluteURL
        let absoluteFragment = URL(string: "https://luma.local/reader#details")!

        XCTAssertEqual(policy.decision(for: relativeFragment, isMainFrame: true), .allow)
        XCTAssertEqual(policy.decision(for: absoluteFragment, isMainFrame: true), .allow)
    }

    func testHTTPHTTPSAndMailtoMainFrameLinksOpenExternally() {
        let policy = WebNavigationPolicy(documentURL: documentURL)
        let safeURLs = [
            URL(string: "http://example.com/note")!,
            URL(string: "https://example.com/note?q=markdown")!,
            URL(string: "mailto:reader@example.com?subject=Luma%20MD")!,
        ]

        for url in safeURLs {
            XCTAssertEqual(
                policy.decision(for: url, isMainFrame: true),
                .openExternal(url),
                "Expected external handling for \(url)"
            )
        }
    }

    func testUnsafeSchemesAreAlwaysBlocked() {
        let policy = WebNavigationPolicy(documentURL: documentURL)
        let unsafeURLs = [
            URL(string: "javascript:alert(1)")!,
            URL(string: "data:text/html,unsafe")!,
            URL(fileURLWithPath: "/etc/passwd"),
            URL(string: "ftp://example.com/note.md")!,
            URL(string: "luma://open")!,
            URL(string: "custom-reader://note")!,
        ]

        for url in unsafeURLs {
            XCTAssertEqual(
                policy.decision(for: url, isMainFrame: true),
                .cancel,
                "Expected blocked navigation for \(url)"
            )
        }
    }

    func testCrossDocumentLocalNavigationAndSubframesAreBlocked() {
        let policy = WebNavigationPolicy(documentURL: documentURL)
        let localCrossDocument = URL(string: "https://luma.local/other#heading")!
        let externalSubframe = URL(string: "https://example.com/tracker")!
        let externalRedirect = URL(string: "https://example.com/redirected")!

        XCTAssertEqual(policy.decision(for: localCrossDocument, isMainFrame: true), .cancel)
        XCTAssertEqual(policy.decision(for: externalSubframe, isMainFrame: false), .cancel)
        XCTAssertEqual(policy.decision(for: externalRedirect, isMainFrame: false), .cancel)
    }

    func testSafeLinkOpeningANewWindowUsesNativeExternalHandler() {
        let policy = WebNavigationPolicy(documentURL: documentURL)
        let externalURL = URL(string: "https://example.com/new-window")!

        XCTAssertEqual(
            policy.decision(for: externalURL, isMainFrame: nil),
            .openExternal(externalURL)
        )
    }
}
