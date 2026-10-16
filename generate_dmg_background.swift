import AppKit
import CoreGraphics
import UniformTypeIdentifiers

func drawBackground(width: CGFloat, height: CGFloat, scale: CGFloat) -> NSBitmapImageRep {
    let pixelW = Int(width * scale)
    let pixelH = Int(height * scale)
    
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelW,
        pixelsHigh: pixelH,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    
    // 1. Clean macOS Native Soft Frosted Gradient
    let bgGradient = NSGradient(colors: [
        NSColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 1.0),
        NSColor(red: 0.90, green: 0.93, blue: 0.99, alpha: 1.0),
        NSColor(red: 0.93, green: 0.95, blue: 0.99, alpha: 1.0)
    ], atLocations: [0.0, 0.55, 1.0], colorSpace: .deviceRGB)
    bgGradient?.draw(in: rect, angle: -40)
    
    // 2. Soft Ambient Glows behind Left (App) and Right (Applications) zones
    func drawRadialGlow(center: CGPoint, radius: CGFloat, color: NSColor) {
        let colors = [color.cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
            cg.drawRadialGradient(
                grad,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: .drawsAfterEndLocation
            )
        }
    }
    
    // Card center is at y_finder = 195 (y_cg = 400 - 195 = 205)
    let leftCenter = CGPoint(x: 180, y: height - 195)
    let rightCenter = CGPoint(x: 480, y: height - 195)
    
    drawRadialGlow(center: leftCenter, radius: 170, color: NSColor(red: 0.16, green: 0.45, blue: 0.98, alpha: 0.15))
    drawRadialGlow(center: rightCenter, radius: 170, color: NSColor(red: 0.42, green: 0.20, blue: 0.92, alpha: 0.15))
    
    // 3. Top Header Title & Subtitle
    let titleParagraph = NSMutableParagraphStyle()
    titleParagraph.alignment = .center
    
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0),
        .paragraphStyle: titleParagraph
    ]
    let titleStr = "Find Any File"
    titleStr.draw(in: CGRect(x: 0, y: height - 54, width: width, height: 30), withAttributes: titleAttrs)
    
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
        .foregroundColor: NSColor(red: 0.32, green: 0.38, blue: 0.50, alpha: 1.0),
        .paragraphStyle: titleParagraph
    ]
    let subStr = "Drag to Applications folder to install   •   Kurulum için Applications klasörüne sürükleyin"
    subStr.draw(in: CGRect(x: 0, y: height - 76, width: width, height: 20), withAttributes: subAttrs)
    
    // 4. Left & Right Drop Zone Pedestal Cards
    let cardW: CGFloat = 174
    let cardH: CGFloat = 178
    let cardBottomY: CGFloat = height - 284
    
    func drawCardShadow(for rect: CGRect) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(red: 0.10, green: 0.20, blue: 0.45, alpha: 0.10)
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.shadowBlurRadius = 18
        shadow.set()
        let path = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)
        NSColor.white.withAlphaComponent(0.90).setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    
    // Left Card (App source)
    let leftCardRect = CGRect(x: leftCenter.x - cardW / 2, y: cardBottomY, width: cardW, height: cardH)
    drawCardShadow(for: leftCardRect)
    let leftCardPath = NSBezierPath(roundedRect: leftCardRect, xRadius: 24, yRadius: 24)
    NSColor(red: 0.20, green: 0.50, blue: 0.96, alpha: 0.32).setStroke()
    leftCardPath.lineWidth = 1.5
    leftCardPath.stroke()
    
    // Right Card (Applications target - dashed indigo border)
    let rightCardRect = CGRect(x: rightCenter.x - cardW / 2, y: cardBottomY, width: cardW, height: cardH)
    drawCardShadow(for: rightCardRect)
    let rightCardPath = NSBezierPath(roundedRect: rightCardRect, xRadius: 24, yRadius: 24)
    NSColor(red: 0.38, green: 0.25, blue: 0.90, alpha: 0.45).setStroke()
    rightCardPath.lineWidth = 2.0
    let dashPattern: [CGFloat] = [7.0, 4.5]
    rightCardPath.setLineDash(dashPattern, count: 2, phase: 0)
    rightCardPath.stroke()
    
    // 5. Center Animated-Style Drag Arrow & Pill Badge
    let arrowY = height - 188
    let arrowStartX: CGFloat = 284
    let arrowEndX: CGFloat = 376
    
    let dotPositions: [(CGFloat, CGFloat)] = [
        (arrowStartX, 3.2),
        (arrowStartX + 12, 4.0),
        (arrowStartX + 25, 4.8)
    ]
    for (dx, r) in dotPositions {
        let dotRect = CGRect(x: dx - r, y: arrowY - r, width: r * 2, height: r * 2)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        NSColor(red: 0.16, green: 0.46, blue: 0.96, alpha: 0.75).setFill()
        dotPath.fill()
    }
    
    let shaftPath = NSBezierPath()
    shaftPath.move(to: CGPoint(x: arrowStartX + 38, y: arrowY))
    shaftPath.line(to: CGPoint(x: arrowEndX - 6, y: arrowY))
    shaftPath.lineWidth = 4.2
    shaftPath.lineCapStyle = .round
    NSColor(red: 0.15, green: 0.44, blue: 0.95, alpha: 0.95).setStroke()
    shaftPath.stroke()
    
    let headPath = NSBezierPath()
    headPath.move(to: CGPoint(x: arrowEndX - 17, y: arrowY + 13))
    headPath.line(to: CGPoint(x: arrowEndX, y: arrowY))
    headPath.line(to: CGPoint(x: arrowEndX - 17, y: arrowY - 13))
    headPath.lineWidth = 4.2
    headPath.lineCapStyle = .round
    headPath.lineJoinStyle = .round
    NSColor(red: 0.28, green: 0.22, blue: 0.90, alpha: 1.0).setStroke()
    headPath.stroke()
    
    let chevron2 = NSBezierPath()
    chevron2.move(to: CGPoint(x: arrowEndX - 31, y: arrowY + 9))
    chevron2.line(to: CGPoint(x: arrowEndX - 19, y: arrowY))
    chevron2.line(to: CGPoint(x: arrowEndX - 31, y: arrowY - 9))
    chevron2.lineWidth = 2.6
    chevron2.lineCapStyle = .round
    chevron2.lineJoinStyle = .round
    NSColor(red: 0.15, green: 0.44, blue: 0.95, alpha: 0.40).setStroke()
    chevron2.stroke()
    
    // "DRAG TO INSTALL" pill under arrow
    let pillW: CGFloat = 116
    let pillH: CGFloat = 22
    let pillRect = CGRect(x: (width - pillW) / 2, y: arrowY - 42, width: pillW, height: pillH)
    let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 11, yRadius: 11)
    let pillGrad = NSGradient(colors: [
        NSColor(red: 0.14, green: 0.44, blue: 0.96, alpha: 1.0),
        NSColor(red: 0.36, green: 0.18, blue: 0.88, alpha: 1.0)
    ])
    pillGrad?.draw(in: pillPath, angle: 0)
    
    let pillAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 9.5, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: titleParagraph,
        .kern: 0.7
    ]
    "DRAG TO INSTALL".draw(in: CGRect(x: pillRect.minX, y: pillRect.minY + 3.5, width: pillW, height: 15), withAttributes: pillAttrs)
    
    // 6. Bottom Footer Info Pill
    let footerW: CGFloat = 460
    let footerH: CGFloat = 28
    let footerRect = CGRect(x: (width - footerW) / 2, y: 24, width: footerW, height: footerH)
    let footerPath = NSBezierPath(roundedRect: footerRect, xRadius: 14, yRadius: 14)
    NSColor.white.withAlphaComponent(0.65).setFill()
    footerPath.fill()
    NSColor(red: 0.20, green: 0.30, blue: 0.50, alpha: 0.12).setStroke()
    footerPath.lineWidth = 1.0
    footerPath.stroke()
    
    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .medium),
        .foregroundColor: NSColor(red: 0.30, green: 0.36, blue: 0.48, alpha: 0.95),
        .paragraphStyle: titleParagraph
    ]
    " Native macOS App (Apple Silicon)   •   Ultra-Fast POSIX & Spotlight Engine".draw(
        in: CGRect(x: footerRect.minX, y: footerRect.minY + 6, width: footerW, height: 16),
        withAttributes: footerAttrs
    )
    
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let width: CGFloat = 660
let height: CGFloat = 400

let rep1x = drawBackground(width: width, height: height, scale: 1.0)
let rep2x = drawBackground(width: width, height: height, scale: 2.0)

let nsImage = NSImage(size: NSSize(width: width, height: height))
nsImage.addRepresentation(rep1x)
nsImage.addRepresentation(rep2x)

if let tiffData = nsImage.tiffRepresentation {
    try? tiffData.write(to: URL(fileURLWithPath: "dmg-background.tiff"))
    print("Generated dmg-background.tiff (\(tiffData.count) bytes)")
}

if let pngData = rep2x.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "dmg-background.png"))
    print("Generated dmg-background.png (\(pngData.count) bytes)")
}

