import AppKit

class OverlayWindow: NSWindow {
    let displayID: UInt32

    init(screen: NSScreen) {
        self.displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        self.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .fullScreenDisallowsTiling]
        self.contentView?.wantsLayer = true
    }
}
