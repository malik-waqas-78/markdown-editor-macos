#!/usr/bin/env swift
import AppKit

// Draws a rounded-rect app icon with an "M↓" markdown glyph at a given size.
func iconImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    let bg = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06),
                          xRadius: size * 0.22, yRadius: size * 0.22)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.30, green: 0.52, blue: 1.0, alpha: 1),
        NSColor(red: 0.12, green: 0.28, blue: 0.85, alpha: 1)
    ])!
    gradient.draw(in: bg, angle: -90)

    let glyph = "M↓" as NSString
    let fontSize = size * 0.42
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.white
    ]
    let textSize = glyph.size(withAttributes: attrs)
    glyph.draw(at: NSPoint(x: (size - textSize.width) / 2,
                           y: (size - textSize.height) / 2),
               withAttributes: attrs)
    image.unlockFocus()
    return image
}

func png(_ image: NSImage, _ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in specs {
    let img = iconImage(size: CGFloat(px))
    try? png(img, px).write(to: URL(fileURLWithPath: "\(out)/\(name)"))
}
print("Wrote iconset to \(out)")
