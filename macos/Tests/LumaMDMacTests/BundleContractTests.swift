import Foundation
import XCTest

final class BundleContractTests: XCTestCase {
    func testInfoPlistRegistersAllDocumentTypesAndMacOS13Minimum() throws {
        let info = try propertyList(at: packageRoot.appendingPathComponent("Resources/Info.plist"))

        XCTAssertEqual(info["CFBundleIdentifier"] as? String, "dev.lumamd.viewer.macos")
        XCTAssertEqual(info["CFBundleExecutable"] as? String, "LumaMD")
        XCTAssertEqual(info["LSMinimumSystemVersion"] as? String, "13.0")
        XCTAssertEqual(info["LSSupportsOpeningDocumentsInPlace"] as? Bool, true)

        let documentTypes = try XCTUnwrap(info["CFBundleDocumentTypes"] as? [[String: Any]])
        XCTAssertFalse(documentTypes.isEmpty)
        XCTAssertTrue(documentTypes.allSatisfy { $0["CFBundleTypeRole"] as? String == "Viewer" })

        let extensions = Set(documentTypes.flatMap {
            $0["CFBundleTypeExtensions"] as? [String] ?? []
        })
        XCTAssertEqual(extensions, ["md", "markdown", "mdown", "mkd", "mdx", "txt"])

        let contentTypes = Set(documentTypes.flatMap {
            ($0["LSItemContentTypes"] as? [String]) ?? []
        })
        XCTAssertTrue(contentTypes.contains("net.daringfireball.markdown"))
        XCTAssertTrue(contentTypes.contains("public.plain-text"))
    }

    func testEntitlementsAreExactReadOnlyLocalSandboxContract() throws {
        let entitlements = try propertyList(
            at: packageRoot.appendingPathComponent("Resources/LumaMD.entitlements")
        )
        let expectedBooleanKeys: Set<String> = [
            "com.apple.security.app-sandbox",
            "com.apple.security.files.user-selected.read-only",
            "com.apple.security.files.bookmarks.app-scope",
        ]
        let webKitBootstrapKey =
            "com.apple.security.temporary-exception.mach-lookup.global-name"
        XCTAssertEqual(Set(entitlements.keys), expectedBooleanKeys.union([webKitBootstrapKey]))
        for key in expectedBooleanKeys {
            XCTAssertEqual(entitlements[key] as? Bool, true, "Expected enabled entitlement: \(key)")
        }
        XCTAssertEqual(
            entitlements[webKitBootstrapKey] as? [String],
            ["com.apple.nsurlsessiond"]
        )
        XCTAssertNil(entitlements["com.apple.security.network.client"])
        XCTAssertNil(entitlements["com.apple.security.network.server"])
        XCTAssertNil(entitlements["com.apple.security.files.user-selected.read-write"])
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func propertyList(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(value as? [String: Any])
    }
}
