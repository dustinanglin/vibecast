// Renders the Vibecast app icon directly using CoreGraphics + CoreText with
// the bundled Fraunces variable font. Implements the IconPeriod design from
// docs/design/vibecast-visual-prototypes/project/vibe-logos-v2.jsx (section 3b
// "v + period across vibes" in Vibecast Logo & Splash v2.html).
//
// Run from the repo root:
//   swift scripts/render_app_icon.swift
//
// Writes Vibecast/Vibecast/Assets.xcassets/AppIcon.appiconset/Icon.png
// (overwrites). Tweak the `weight` and `accent` constants below to iterate.

import Foundation
import AppKit
import CoreText

// MARK: - Tuning knobs

let size: CGFloat = 1024
let weight: CGFloat = 600  // Fraunces wght axis: 100=thin, 400=regular, 500=medium, 600=semibold, 700=bold

// "Morning" vibe orange — oklch(0.68 0.14 35) ≈ sRGB #E07A5C
let accentHex: UInt32 = 0xE07A5C

// MARK: - Paths (relative to CWD = repo root)

let cwd = FileManager.default.currentDirectoryPath
let fontPath = "\(cwd)/Vibecast/Vibecast/Resources/Fonts/Fraunces[opsz,wght].ttf"
let outPath = "\(cwd)/Vibecast/Vibecast/Assets.xcassets/AppIcon.appiconset/Icon.png"

// MARK: - Register Fraunces

var fontError: Unmanaged<CFError>?
let fontURL = URL(fileURLWithPath: fontPath) as CFURL
guard CTFontManagerRegisterFontsForURL(fontURL, .process, &fontError) else {
    let e = fontError?.takeRetainedValue()
    fputs("Failed to register Fraunces at \(fontPath): \(String(describing: e))\n", stderr)
    exit(1)
}

// MARK: - Colors (matches Brand.swift)

func srgb(_ rgb: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1
    )
}

let paper = srgb(0xF4EFE6)
let ink = srgb(0x1A1714)
let accent = srgb(accentHex)

// MARK: - Render

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext init failed") }

// 1. Paper background, full bleed (iOS rounds corners itself)
ctx.setFillColor(paper)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// 2. Fraunces "v" — variable-font weight via wght axis. Size 62% of canvas,
//    baseline at 78% from top. Matches IconPeriod() in vibe-logos-v2.jsx.
let fontSize = size * 0.62
let varAxes = [2003265652: weight] as CFDictionary  // 'wght' axis tag = 0x77676874
let descAttrs: [CFString: Any] = [
    kCTFontNameAttribute: "Fraunces" as CFString,
    kCTFontVariationAttribute: varAxes,
]
let desc = CTFontDescriptorCreateWithAttributes(descAttrs as CFDictionary)
let font = CTFontCreateWithFontDescriptor(desc, fontSize, nil)

let kern = -0.04 * fontSize  // letter-spacing: -0.04em
let attrs: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: ink,
    kCTKernAttributeName: kern,
]
let attrStr = CFAttributedStringCreate(nil, "v" as CFString, attrs as CFDictionary)!
let line = CTLineCreateWithAttributedString(attrStr)
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

// SVG x=50% with text-anchor=middle: visually center the glyph
let textX = (size - bounds.width) / 2 - bounds.origin.x
// SVG baseline at y=78% from top (CG origin is bottom-left)
let textY = size - (size * 0.78)
ctx.textPosition = CGPoint(x: textX, y: textY)
CTLineDraw(line, ctx)

// 3. Accent dot — center at (72%, 70%) from top-left, radius 7.5% of canvas
let dotCX = size * 0.72
let dotCY = size - (size * 0.70)
let dotR = size * 0.075
ctx.setFillColor(accent)
ctx.fillEllipse(in: CGRect(x: dotCX - dotR, y: dotCY - dotR, width: dotR * 2, height: dotR * 2))

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
