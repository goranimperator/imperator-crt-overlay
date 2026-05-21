import AppKit
import Metal
import MetalKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var overlayWindows: [OverlayWindow] = []
    var metalDevice: MTLDevice?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            let alert = NSAlert()
            alert.messageText = "Metal krävs"
            alert.informativeText = "Imperator CRT Overlay kräver en Metal-kompatibel GPU."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        metalDevice = device

        CRTSettings.shared.load()
        statusBarController = StatusBarController()
        setupOverlays()

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: .crtSettingsChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }

    private func setupOverlays() {
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()

        guard let device = metalDevice else { return }
        let settings = CRTSettings.shared

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            let metalView = CRTMetalView(frame: window.contentView!.bounds, device: device)
            metalView.autoresizingMask = [.width, .height]
            window.contentView?.addSubview(metalView)

            if settings.isActive && settings.isScreenEnabled(window.displayID) {
                window.orderFrontRegardless()
            }
            overlayWindows.append(window)
        }
    }

    @objc private func settingsChanged() {
        let settings = CRTSettings.shared
        for window in overlayWindows {
            let shouldShow = settings.isActive && settings.isScreenEnabled(window.displayID)
            if shouldShow {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
        }
    }

    @objc private func screensChanged() {
        setupOverlays()
    }

    @objc private func spaceChanged() {
        bringOverlaysToFront()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.bringOverlaysToFront()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.bringOverlaysToFront()
        }
    }

    private func bringOverlaysToFront() {
        let settings = CRTSettings.shared
        for window in overlayWindows {
            if settings.isActive && settings.isScreenEnabled(window.displayID) {
                window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
                window.orderFrontRegardless()
            }
        }
    }
}
