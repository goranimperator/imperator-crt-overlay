// Renders the app's REAL PopoverContentView and asserts it paints no background
// of its own. NSPopover already draws the system material; a second translucent
// fill on top reads as a panel sitting inside the popover rather than as the
// popover's own surface, and it squares off the corners the chrome rounds.
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

    func alpha(_ x: Int, _ y: Int) -> CGFloat {
        guard x >= 0, y >= 0, x < w, y < h, let c = rep.colorAt(x: x, y: y) else { return -1 }
        return c.alphaComponent
    }

    var bad = 0

    // Corners must be empty: nothing of the view's own may reach them.
    for (name, x, y) in [("top-left", 1, 1), ("top-right", w - 2, 1),
                         ("bottom-left", 1, h - 2), ("bottom-right", w - 2, h - 2)] {
        let a = alpha(x, y)
        print(String(format: "  %-13s alpha %.3f", (name as NSString).utf8String!, a))
        if a > 0.02 { print("FAIL: \(name) corner is painted"); bad += 1 }
    }

    // A band inside the popover that carries no control must also be empty,
    // which is what proves the background fill is gone rather than merely clipped.
    // Sample the gutter just inside the left edge, below the header.
    var painted = 0, sampled = 0
    for yPt in stride(from: 60, through: Int(host.bounds.height) - 40, by: 7) {
        let a = alpha(Int(3 * scale), Int(CGFloat(yPt) * scale))
        if a < 0 { continue }
        sampled += 1
        if a > 0.02 { painted += 1 }
    }
    print("left gutter: \(painted) of \(sampled) samples painted")
    if sampled < 20 { print("FAIL: too few gutter samples (\(sampled))"); bad += 1 }
    if painted > 0 {
        print("FAIL: the view paints a background of its own; NSPopover should supply it")
        bad += 1
    }

    if bad == 0 { print("BACKGROUND_STANDARD"); return 0 }
    return 1
}

exit(MainActor.assumeIsolated { run() })
