// Renders the Vibecast app icon: top-down view of three stacked layers,
// matching StackIcon2 in docs/design/vibecast-visual-prototypes/project/
// vibes-entry-v2.jsx (which is also the Manage Vibes button in the app).
//
// Run from the repo root:
//   swift scripts/render_app_icon.swift
//
// Writes Vibecast/Vibecast/Assets.xcassets/AppIcon.appiconset/Icon.png
// (overwrites).

import Foundation
import AppKit
import CoreGraphics

// MARK: - Tuning knobs

let size: CGFloat = 1024

/// Morning vibe orange — matches the top vibe color in vibes-shared.jsx.
/// Used for the top filled diamond so the stack reads as "the layer
/// currently on top of the pile."
let accentHex: UInt32 = 0xD89A4F

/// Width of the bottom-two stroked V's, in canvas pixels.
let strokeWidth: CGFloat = 44

// MARK: - Paths

let cwd = FileManager.default.currentDirectoryPath
let outPath = "\(cwd)/Vibecast/Vibecast/Assets.xcassets/AppIcon.appiconset/Icon.png"

// MARK: - Colors (matches Brand.swift)

func srgb(_ rgb: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1
    )
}

let bg = srgb(0xF4EFE6)      // Brand.Color.bg (paper-warm)
let ink = srgb(0x1A1714)     // Brand.Color.ink
let accent = srgb(accentHex) // Morning orange

// MARK: - Render

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext init failed") }

// 1. Paper background, full bleed (iOS rounds corners itself).
ctx.setFillColor(bg)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// 2. Translate StackIcon2's 24×24 viewBox into the canvas. The icon's
//    drawn region is (x: 4..20, y: 4..21) — a 16×17 bounding box. We map
//    the full 24-unit viewBox into a 720×720 centered square so the icon
//    occupies ~70% of the canvas with some padding around it.
let scaledSpan: CGFloat = 720
let scale = scaledSpan / 24
let inset = (size - scaledSpan) / 2

/// Convert SVG (x, y) where y grows downward into CG canvas coords where
/// y grows upward. SVG (12, 12) lands at the visual center of the icon.
func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: inset + x * scale, y: size - (inset + y * scale))
}

// 3a. Top filled diamond — the layer "on top of the pile." Path matches
//     the SVG's `M4 8 L12 4 L20 8 L12 12 Z` outline; we fill it instead
//     of stroking so it reads as a solid color block.
ctx.beginPath()
ctx.move(to: point(4, 8))
ctx.addLine(to: point(12, 4))
ctx.addLine(to: point(20, 8))
ctx.addLine(to: point(12, 12))
ctx.closePath()
ctx.setFillColor(accent)
ctx.fillPath()

// 3b. Middle V — peek of the layer below the top. SVG: M4 13 L12 17 L20 13.
ctx.setStrokeColor(ink)
ctx.setLineWidth(strokeWidth)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

ctx.beginPath()
ctx.move(to: point(4, 13))
ctx.addLine(to: point(12, 17))
ctx.addLine(to: point(20, 13))
ctx.strokePath()

// 3c. Bottom V — peek of the bottom layer. SVG: M4 17 L12 21 L20 17.
ctx.beginPath()
ctx.move(to: point(4, 17))
ctx.addLine(to: point(12, 21))
ctx.addLine(to: point(20, 17))
ctx.strokePath()

// MARK: - Save PNG

guard let cgImage = ctx.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
do {
    try data.write(to: URL(fileURLWithPath: outPath))
    print("Wrote \(outPath)")
} catch {
    fputs("Write failed: \(error)\n", stderr)
    exit(1)
}
