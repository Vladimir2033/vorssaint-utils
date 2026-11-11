// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Syntex Utils: unofficial personal fork of Vorssaint, under the same license.

// Icon assets for `./build.sh --syntex`, drawn from code alone.
//
// TRADEMARKS.md asks a fork for its own icon, so nothing here reads the
// Vorssaint artwork in Resources/Brand: the mark is an "S" set in the
// system's rounded heavy face, on a graphite tile. Same outputs and sizes
// as Tools/MakeIcon.swift, so the rest of the build does not change:
//   <outDir>/icon_*.png, AppIcon.icns, MenuBarIcon.png, MenuBarIcon@2x.png
//   and BrandMark.png, all beside <outDir>.
import AppKit
import CoreText

let iconSizes: [(name: String, px: Int, icnsType: String?)] = [
    ("icon_16x16", 16, nil), ("icon_16x16@2x", 32, "ic11"),
    ("icon_32x32", 32, nil), ("icon_32x32@2x", 64, "ic12"),
    ("icon_128x128", 128, "ic07"), ("icon_128x128@2x", 256, "ic13"),
    ("icon_256x256", 256, "ic08"), ("icon_256x256@2x", 512, "ic14"),
    ("icon_512x512", 512, "ic09"), ("icon_512x512@2x", 1024, "ic10"),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"

/// The fork's yellow, the same family as the idle menu bar tint
/// (BlackHoleGlyph.idleTint = .systemYellow) so icon and menu bar match.
let markYellow = NSColor(srgbRed: 1.0, green: 0.80, blue: 0.0, alpha: 1)
let tileTop = NSColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1)
let tileBottom = NSColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1)

func roundedHeavyFont(size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .heavy)
    if let rounded = base.fontDescriptor.withDesign(.rounded),
       let font = NSFont(descriptor: rounded, size: size) {
        return font
    }
    return base
}

/// Outline of `text` as one path, so it can be fitted by its real ink bounds
/// instead of the font's line box (which would leave the letter off-centre).
func textPath(_ text: String, font: NSFont) -> CGPath {
    let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: [.font: font]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        guard let runFont = attributes[kCTFontAttributeName as String] else { continue }
        let ctFont = runFont as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for index in 0..<count {
            if let glyph = CTFontCreatePathForGlyph(ctFont, glyphs[index], nil) {
                path.addPath(glyph, transform: CGAffineTransform(translationX: positions[index].x,
                                                                 y: positions[index].y))
            }
        }
    }
    return path
}

/// `path` scaled to `height` and centred on `center`.
func fitted(_ path: CGPath, height: CGFloat, center: CGPoint) -> CGPath {
    let bounds = path.boundingBoxOfPath
    let scale = height / bounds.height
    var transform = CGAffineTransform(translationX: center.x - bounds.midX * scale,
                                      y: center.y - bounds.midY * scale)
        .scaledBy(x: scale, y: scale)
    return path.copy(using: &transform) ?? path
}

let monogram = textPath("S", font: roundedHeavyFont(size: 512))
let wordmark = textPath("Syntex", font: roundedHeavyFont(size: 512))

func bitmapCanvas(_ px: Int, _ py: Int) -> NSBitmapImageRep? {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: py,
                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                     isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)
}

/// Runs `draw` with a focused context on a fresh canvas. Without focusing,
/// the draws land nowhere and the PNG comes out empty (see MakeIcon.swift).
func render(width: Int, height: Int, pointSize: NSSize, _ draw: (CGContext) -> Void) -> Data? {
    guard let rep = bitmapCanvas(width, height),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    rep.size = pointSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// MARK: - App icon

func renderAppIcon(px: Int) -> Data? {
    let size = CGFloat(px)
    return render(width: px, height: px, pointSize: NSSize(width: size, height: size)) { cg in
        // macOS icon grid: an 824/1024 tile with a 185/1024 corner, leaving
        // the margin the Dock expects around every app icon.
        let inset = size * 100 / 1024
        let tile = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
        let radius = size * 185 / 1024
        let shape = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)
        cg.saveGState()
        cg.addPath(shape)
        cg.clip()
        let colors = [tileTop.cgColor, tileBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                     colors: colors, locations: [0, 1]) {
            cg.drawLinearGradient(gradient, start: CGPoint(x: tile.midX, y: tile.maxY),
                                  end: CGPoint(x: tile.midX, y: tile.minY), options: [])
        }
        cg.restoreGState()
        cg.addPath(fitted(monogram, height: tile.height * 0.58,
                          center: CGPoint(x: tile.midX, y: tile.midY)))
        cg.setFillColor(markYellow.cgColor)
        cg.fillPath()
    }
}

// MARK: - Menu bar glyph (template)

// Same canvas as the official glyph: BlackHoleGlyph.pointSize in
// Sources/Vorssaint/App/StatusItemController.swift, enforced by `--selftest`.
// The ink is 14 pt tall, the height of the menu bar's compact symbols.
let menuBarCanvas = (width: 26, height: 20)
let menuBarInkHeight: CGFloat = 14

func renderMenuBarIcon(scale: Int) -> Data? {
    let width = menuBarCanvas.width * scale, height = menuBarCanvas.height * scale
    return render(width: width, height: height,
                  pointSize: NSSize(width: menuBarCanvas.width, height: menuBarCanvas.height)) { cg in
        cg.addPath(fitted(monogram, height: menuBarInkHeight * CGFloat(scale),
                          center: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)))
        cg.setFillColor(NSColor.black.cgColor)
        cg.fillPath()
    }
}

// MARK: - ICNS

func appendFourCC(_ value: String, to data: inout Data) {
    data.append(contentsOf: value.utf8)
}

func appendUInt32BE(_ value: Int, to data: inout Data) {
    let clamped = UInt32(value)
    data.append(UInt8((clamped >> 24) & 0xff))
    data.append(UInt8((clamped >> 16) & 0xff))
    data.append(UInt8((clamped >> 8) & 0xff))
    data.append(UInt8(clamped & 0xff))
}

func writeICNS(entries: [(type: String, data: Data)], to url: URL) throws {
    let totalLength = 8 + entries.reduce(0) { $0 + 8 + $1.data.count }
    var icns = Data()
    appendFourCC("icns", to: &icns)
    appendUInt32BE(totalLength, to: &icns)
    for entry in entries {
        appendFourCC(entry.type, to: &icns)
        appendUInt32BE(8 + entry.data.count, to: &icns)
        icns.append(entry.data)
    }
    try icns.write(to: url)
}

// MARK: - Output

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
var icnsEntries: [(type: String, data: Data)] = []
for (name, px, icnsType) in iconSizes {
    guard let data = renderAppIcon(px: px) else {
        print("failed to render \(name)")
        exit(1)
    }
    try data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    if let icnsType {
        icnsEntries.append((type: icnsType, data: data))
    }
}
try writeICNS(entries: icnsEntries, to: URL(fileURLWithPath: "\(outDir)/../AppIcon.icns"))

for scale in [1, 2] {
    guard let data = renderMenuBarIcon(scale: scale) else {
        print("failed to render menu bar icon @\(scale)x")
        exit(1)
    }
    let suffix = scale == 1 ? "" : "@2x"
    try data.write(to: URL(fileURLWithPath: "\(outDir)/../MenuBarIcon\(suffix).png"))
}

// Wordmark for in-app use (panel header, onboarding, About badge). Template:
// BrandMark tints it, so it is drawn in black on transparent.
let wordBounds = wordmark.boundingBoxOfPath
let markWidth = 640
let markHeight = Int((CGFloat(markWidth) * wordBounds.height / wordBounds.width).rounded(.up))
if let data = render(width: markWidth, height: markHeight,
                     pointSize: NSSize(width: markWidth, height: markHeight), { cg in
    cg.addPath(fitted(wordmark, height: CGFloat(markHeight),
                      center: CGPoint(x: CGFloat(markWidth) / 2, y: CGFloat(markHeight) / 2)))
    cg.setFillColor(NSColor.black.cgColor)
    cg.fillPath()
}) {
    try data.write(to: URL(fileURLWithPath: "\(outDir)/../BrandMark.png"))
}
print("Syntex Utils iconset written to \(outDir)")
