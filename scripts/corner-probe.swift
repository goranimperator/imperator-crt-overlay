// Renders the app's REAL PopoverContentView and measures its alpha corner profile,
// then compares that profile against the 20pt continuous shape measured on the
// system popover glass. Compiled together with the app's own sources.
import AppKit
import SwiftUI

@MainActor
func run() -> Int32 {
    let vm = CRTSettingsViewModel()
    let root = PopoverContentView(quitAction: {}, aboutAction: {}).environmentObject(vm)
    let host = NSHostingView(rootView: root)
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

    func alpha(_ x: Int, _ y: Int) -> CGFloat {
        guard x >= 0, y >= 0, x < w, y < h, let c = rep.colorAt(x: x, y: y) else { return -1 }
        return c.alphaComponent
    }

    var bad = 0
    let cornerA = alpha(1, 1)
    let centerA = alpha(w / 2, h / 2)
    print(String(format: "alpha: corner (1,1) = %.3f, centre = %.3f", cornerA, centerA))
    if centerA < 0.02 { print("FAIL: centre is not painted, the render is empty"); bad += 1 }
    if cornerA > 0.02 { print("FAIL: top-left corner is painted, content is not clipped"); bad += 1 }

    // The popover background is .black.opacity(0.15), so anything inside the clip
    // reads at least ~0.15 while anything outside it is exactly 0. Threshold well
    // below the background so the edge is found where the SHAPE ends, not where
    // the first control happens to be drawn.
    let onThreshold: CGFloat = 0.05
    let deepInside = alpha(Int(60 * scale), Int(h) - Int(30 * scale))
    print(String(format: "alpha deep inside the background = %.3f (threshold %.2f)", deepInside, onThreshold))
    if deepInside < onThreshold {
        print("FAIL: background is not painted, the threshold has nothing to find")
        bad += 1
    }

    // Compare the corner profile column by column against a 20pt continuous shape.
    let ref = Path(roundedRect: CGRect(origin: .zero, size: host.bounds.size),
                   cornerRadius: 20, style: .continuous).cgPath
    func firstPaintedRow(_ x: Int) -> Int {
        for y in 0..<min(h, Int(44 * scale)) where alpha(x, y) > onThreshold { return y }
        return -1
    }
    func refFirstRow(_ x: Int) -> Int {
        for y in 0..<min(h, Int(44 * scale)) {
            // AppKit bitmap rows count down from the top; CGPath is bottom-left origin.
            let pt = CGPoint(x: (CGFloat(x) + 0.5) / scale,
                             y: host.bounds.height - (CGFloat(y) + 0.5) / scale)
            if ref.contains(pt) { return y }
        }
        return -1
    }

    var worst = 0
    var compared = 0
    for xPt in stride(from: 0, through: 22, by: 2) {
        let x = Int(CGFloat(xPt) * scale)
        let got = firstPaintedRow(x), want = refFirstRow(x)
        if got < 0 || want < 0 { continue }
        let diff = abs(got - want)
        worst = max(worst, diff)
        compared += 1
        print(String(format: "  x=%2dpt  content row %3d  reference row %3d  diff %d px", xPt, got, want, diff))
    }
    if compared < 6 { print("FAIL: too few columns compared (\(compared))"); bad += 1 }
    let tolerance = Int(2 * scale)
    if worst > tolerance {
        print("FAIL: corner profile deviates by \(worst) px, tolerance \(tolerance)")
        bad += 1
    } else {
        print("worst deviation \(worst) px within tolerance \(tolerance)")
    }

    if bad == 0 { print("CORNERS_ROUNDED"); return 0 }
    return 1
}

exit(MainActor.assumeIsolated { run() })
