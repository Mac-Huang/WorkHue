#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("Cannot create the icon canvas.") }
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

func rgba(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

// Use an opaque square. Each platform applies its own icon mask.
let background = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgba(0.16, 0.70, 0.025), rgba(0.30, 0.88, 0.06), rgba(0.43, 0.95, 0.19)] as CFArray,
    locations: [0, 0.68, 1]
)!
context.drawLinearGradient(background, start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])

let clockRect = CGRect(x: 156, y: 156, width: 712, height: 712)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 38, color: rgba(0.025, 0.25, 0.02, 0.22))
context.setFillColor(rgba(0.89, 1, 0.89, 0.30))
context.fillEllipse(in: clockRect)
context.restoreGState()

context.saveGState()
context.addEllipse(in: clockRect)
context.clip()
let face = CGGradient(
    colorsSpace: colorSpace,
    colors: [rgba(0.78, 1, 0.76, 0.15), rgba(0.94, 1, 0.94, 0.68)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(face, start: CGPoint(x: 512, y: 156), end: CGPoint(x: 512, y: 868), options: [])
context.restoreGState()

context.setStrokeColor(rgba(0.94, 1, 0.94, 0.86))
context.setLineWidth(16)
context.strokeEllipse(in: clockRect.insetBy(dx: 6, dy: 6))

// Rounded hands retain a simple silhouette at small complication and launcher sizes.
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -3), blur: 3, color: rgba(0.10, 0.45, 0.08, 0.28))
context.setStrokeColor(rgba(1, 1, 1, 0.98))
context.setLineWidth(60)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 512, y: 748))
context.addLine(to: CGPoint(x: 512, y: 512))
context.addLine(to: CGPoint(x: 678, y: 416))
context.strokePath()
context.restoreGState()

guard let image = context.makeImage() else { fatalError("Cannot render the icon.") }
let representation = NSBitmapImageRep(cgImage: image)
guard let png = representation.representation(using: .png, properties: [:]) else {
    fatalError("Cannot encode the icon.")
}
let manager = FileManager.default
for directory in ["Phone/Assets.xcassets/AppIcon.appiconset", "Watch/Assets.xcassets/AppIcon.appiconset"] {
    let destination = root.appendingPathComponent(directory, isDirectory: true)
    try manager.createDirectory(at: destination, withIntermediateDirectories: true)
    try png.write(to: destination.appendingPathComponent("AppIcon.png"))
    print(destination.appendingPathComponent("AppIcon.png").path)
}
