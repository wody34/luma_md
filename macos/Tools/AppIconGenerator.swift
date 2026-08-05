import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "")
guard !outputURL.path.isEmpty else {
    fputs("Usage: swift AppIconGenerator.swift <AppIcon.iconset>\n", stderr)
    exit(64)
}

try FileManager.default.createDirectory(
    at: outputURL,
    withIntermediateDirectories: true
)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let colorSpace = CGColorSpaceCreateDeviceRGB()

for variant in variants {
    let pixels = variant.pixels
    let size = CGFloat(pixels)
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw IconError.context
    }

    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let iconBounds = bounds.insetBy(dx: size * 0.03, dy: size * 0.03)
    let iconPath = CGPath(
        roundedRect: iconBounds,
        cornerWidth: size * 0.22,
        cornerHeight: size * 0.22,
        transform: nil
    )
    context.addPath(iconPath)
    context.clip()

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.57, green: 0.36, blue: 0.95, alpha: 1),
            CGColor(red: 0.34, green: 0.18, blue: 0.72, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )
    guard let gradient else {
        throw IconError.gradient
    }
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: size * 0.15, y: size * 0.9),
        end: CGPoint(x: size * 0.85, y: size * 0.1),
        options: []
    )

    let pageRect = CGRect(
        x: size * 0.29,
        y: size * 0.20,
        width: size * 0.42,
        height: size * 0.60
    )
    let pagePath = CGPath(
        roundedRect: pageRect,
        cornerWidth: size * 0.045,
        cornerHeight: size * 0.045,
        transform: nil
    )
    context.addPath(pagePath)
    context.setFillColor(CGColor(gray: 1, alpha: 0.96))
    context.fillPath()

    let foldSize = size * 0.14
    context.move(to: CGPoint(x: pageRect.maxX - foldSize, y: pageRect.maxY))
    context.addLine(to: CGPoint(x: pageRect.maxX, y: pageRect.maxY - foldSize))
    context.addLine(to: CGPoint(x: pageRect.maxX - foldSize, y: pageRect.maxY - foldSize))
    context.closePath()
    context.setFillColor(CGColor(red: 0.77, green: 0.70, blue: 0.98, alpha: 1))
    context.fillPath()

    context.setStrokeColor(CGColor(red: 0.37, green: 0.22, blue: 0.72, alpha: 1))
    context.setLineWidth(max(1, size * 0.025))
    context.setLineCap(.round)
    for offset in [0.18, 0.28, 0.38] {
        let y = pageRect.minY + size * offset
        context.move(to: CGPoint(x: pageRect.minX + size * 0.10, y: y))
        context.addLine(to: CGPoint(x: pageRect.maxX - size * 0.10, y: y))
        context.strokePath()
    }

    guard let image = context.makeImage() else {
        throw IconError.image
    }
    let fileURL = outputURL.appendingPathComponent(variant.name)
    guard let destination = CGImageDestinationCreateWithURL(
        fileURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw IconError.destination
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw IconError.write
    }
}

print("Generated \(variants.count) icon images at \(outputURL.path)")

private enum IconError: Error {
    case context
    case gradient
    case image
    case destination
    case write
}
