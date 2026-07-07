// generate_icon.swift — renders the app icon with CoreGraphics (no design
// tools needed) and emits an .iconset directory.
//
// Design: charcoal squircle, saffron mic capsule + white stand (desi accent,
// readable at 16px). Run via build_app.sh; output → iconutil -c icns.
//
// Usage: swift generate_icon.swift <output.iconset>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(size: Int, scale: Int, name: String) {
    let pixels = size * scale
    let s = CGFloat(pixels)
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }

    // Squircle background with macOS-style margin (content ≈ 80% of canvas)
    let margin = s * 0.10
    let rect = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let bg = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225,
                    cornerHeight: rect.width * 0.225, transform: nil)
    ctx.addPath(bg)
    ctx.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1))  // charcoal
    ctx.fillPath()

    let saffron = CGColor(red: 1.00, green: 0.60, blue: 0.20, alpha: 1)
    let white = CGColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
    let green = CGColor(red: 0.08, green: 0.62, blue: 0.42, alpha: 1)

    // Mic capsule
    let micW = s * 0.22, micH = s * 0.34
    let micRect = CGRect(x: (s - micW) / 2, y: s * 0.42, width: micW, height: micH)
    ctx.addPath(CGPath(roundedRect: micRect, cornerWidth: micW / 2,
                       cornerHeight: micW / 2, transform: nil))
    ctx.setFillColor(saffron)
    ctx.fillPath()

    // Mic cradle (arc) + stem + base in white
    ctx.setStrokeColor(white)
    ctx.setLineWidth(s * 0.035)
    ctx.setLineCap(.round)
    let cradleR = micW * 0.95
    ctx.addArc(center: CGPoint(x: s / 2, y: s * 0.46), radius: cradleR,
               startAngle: .pi, endAngle: 0, clockwise: true)
    ctx.strokePath()
    ctx.move(to: CGPoint(x: s / 2, y: s * 0.46 - cradleR))
    ctx.addLine(to: CGPoint(x: s / 2, y: s * 0.245))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: s / 2 - micW * 0.6, y: s * 0.235))
    ctx.addLine(to: CGPoint(x: s / 2 + micW * 0.6, y: s * 0.235))
    ctx.strokePath()

    // Green "recording" dot — the desi tricolor nod (saffron + white + green)
    ctx.setFillColor(green)
    let dotR = s * 0.045
    ctx.fillEllipse(in: CGRect(x: s * 0.66 - dotR, y: s * 0.66 - dotR,
                               width: dotR * 2, height: dotR * 2))

    guard let image = ctx.makeImage() else { return }
    let url = URL(fileURLWithPath: "\(outDir)/\(name).png")
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

for size in [16, 32, 128, 256, 512] {
    draw(size: size, scale: 1, name: "icon_\(size)x\(size)")
    draw(size: size, scale: 2, name: "icon_\(size)x\(size)@2x")
}
print("iconset written to \(outDir)")
