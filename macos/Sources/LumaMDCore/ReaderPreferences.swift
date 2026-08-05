import Foundation

public enum ReaderTheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum ReaderTypeScale: Double, CaseIterable, Sendable {
    case small = 0.92
    case standard = 1.00
    case large = 1.12

    public static let compact = ReaderTypeScale.small
    public static let expanded = ReaderTypeScale.large
}

public final class ReaderPreferences {
    private enum Key {
        static let theme = "theme"
        static let typeScale = "type-scale"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var theme: ReaderTheme {
        get {
            guard let value = defaults.string(forKey: Key.theme) else {
                return .system
            }
            return ReaderTheme(rawValue: value) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.theme)
        }
    }

    public var typeScale: ReaderTypeScale {
        get {
            ReaderTypeScale(rawValue: defaults.double(forKey: Key.typeScale)) ?? .standard
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.typeScale)
        }
    }
}
