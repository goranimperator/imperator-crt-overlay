// Renders the app's REAL panel content and asserts the body stays translucent.
//
// MenuBarPanel draws the surface: an NSVisualEffectView with the `.popover`
// material, under a layer corner the app sets itself. The content's job is the
// brandbook tint over that material, so an opaque body here would hide the very
// thing the panel is built to show.
import AppKit
import SwiftUI

@MainActor
func run() -> Int32 {
    let vm = CRTSettingsViewModel()
    let host = NSHostingView(rootView: PopoverContentView(quitAction: {}, aboutAction: {}).environmentObject(vm))
    let size = host.fittingSize
    host.frame = NSRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()

    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
        print("FAIL: no bitmap rep"); return 1
    }
    rep.size = host.bounds.size
    host.cacheDisplay(in: host.bounds, to: rep)

    let w = rep.pixelsWide, h = rep.pixelsHigh
    let scale = CGFloat(w) / host.bounds.width
    print("content size = \(size), bitmap = \(w)x\(h), scale = \(scale)")

    func px(_ x: Int, _ y: Int) -> NSColor? { rep.colorAt(x: x, y: y) }

    var bad = 0

    // The body is the brandbook tint and nothing else, so it must be
    // translucent: MenuBarPanel lays down the system's `.popover` material and
    // an opaque fill here would hide it. This asserted the opposite for a day,
    // while the app painted an opaque body to imitate the popover
    // imperator-widget-clock was getting from an old SDK stamp.
    var alphas: [CGFloat] = [], whites: [CGFloat] = []
    for yPt in stride(from: 60, through: Int(host.bounds.height) - 40, by: 7) {
        guard let c = px(Int(4 * scale), Int(CGFloat(yPt) * scale))?
            .usingColorSpace(.deviceRGB) else { continue }
        alphas.append(c.alphaComponent)
        whites.append((c.redComponent + c.greenComponent + c.blueComponent) / 3)
    }
    guard alphas.count >= 20 else { print("FAIL: too few samples (\(alphas.count))"); return 1 }

    let minAlpha = alphas.min() ?? 0
    let meanWhite = whites.reduce(0, +) / CGFloat(whites.count)
    print(String(format: "gutter samples %d, min alpha %.3f, mean white %.4f",
                 alphas.count, minAlpha, meanWhite))

    // 0.15 black over whatever the material carries: opaque here means the
    // material is gone.
    if minAlpha > 0.9 {
        print("FAIL: the body is opaque, so it hides the panel's own material")
        bad += 1
    }
    if minAlpha < 0.05 {
        print("FAIL: the body paints no tint at all")
        bad += 1
    }

    if bad == 0 { print("PANEL_OK"); return 0 }
    return 1
}

exit(MainActor.assumeIsolated { run() })
