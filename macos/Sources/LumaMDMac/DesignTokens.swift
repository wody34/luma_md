import SwiftUI

public enum DesignTokens {
    static let readerMeasure: CGFloat = 720
    static let windowMinimum = CGSize(width: 720, height: 520)
    public static let windowDefault = CGSize(width: 1_080, height: 760)
    static let panelRadius: CGFloat = 22
    static let controlRadius: CGFloat = 12

    static var accent: Color {
        Color(red: 0.49, green: 0.28, blue: 0.88)
    }

    static var accentBright: Color {
        Color(red: 0.61, green: 0.42, blue: 0.97)
    }

    static var lightCanvas: Color {
        Color(red: 0.95, green: 0.94, blue: 0.97)
    }

    static var darkCanvas: Color {
        Color(red: 0.055, green: 0.05, blue: 0.075)
    }

    static var glow: RadialGradient {
        RadialGradient(
            colors: [accent.opacity(0.24), accent.opacity(0)],
            center: .top,
            startRadius: 0,
            endRadius: 420
        )
    }

    static var documentShadow: Color {
        Color.black.opacity(0.18)
    }
}
