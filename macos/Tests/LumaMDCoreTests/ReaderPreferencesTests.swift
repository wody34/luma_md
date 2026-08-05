import Foundation
import XCTest
import LumaMDCore

final class ReaderPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "LumaMD.ReaderPreferencesTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    func testMissingValuesNormalizeToSystemAndStandardScale() {
        let preferences = ReaderPreferences(defaults: defaults)

        XCTAssertEqual(preferences.theme, .system)
        XCTAssertEqual(preferences.typeScale, .standard)
        XCTAssertEqual(preferences.typeScale.rawValue, 1.00, accuracy: 0.000_001)
    }

    func testEveryThemeChoicePersistsAcrossInstances() {
        for theme in [ReaderTheme.system, .light, .dark] {
            let writer = ReaderPreferences(defaults: defaults)
            writer.theme = theme

            let reader = ReaderPreferences(defaults: defaults)
            XCTAssertEqual(reader.theme, theme)
            XCTAssertEqual(defaults.string(forKey: "theme"), theme.rawValue)
        }
    }

    func testEverySupportedTypeScalePersistsAcrossInstances() {
        let scales: [ReaderTypeScale] = [.small, .standard, .large]
        let expectedRawValues = [0.92, 1.00, 1.12]

        for (scale, rawValue) in zip(scales, expectedRawValues) {
            let writer = ReaderPreferences(defaults: defaults)
            writer.typeScale = scale

            let reader = ReaderPreferences(defaults: defaults)
            XCTAssertEqual(reader.typeScale, scale)
            XCTAssertEqual(reader.typeScale.rawValue, rawValue, accuracy: 0.000_001)
            XCTAssertEqual(defaults.double(forKey: "type-scale"), rawValue, accuracy: 0.000_001)
        }
    }

    func testUnsupportedPersistedValuesNormalizeWithoutLeakingInvalidState() {
        defaults.set("sepia", forKey: "theme")
        defaults.set(1.08, forKey: "type-scale")

        let preferences = ReaderPreferences(defaults: defaults)

        XCTAssertEqual(preferences.theme, .system)
        XCTAssertEqual(preferences.typeScale, .standard)
    }
}
