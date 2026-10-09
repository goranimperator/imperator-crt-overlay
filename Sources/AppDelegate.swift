import AppKit
import Metal
import MetalKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var overlayWindows: [OverlayWindow] = []
    var metalDevice: MTLDevice?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force dark mode
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Override accent color to brand red
        UserDefaults.standard.set(0, forKey: "AppleAccentColor")

        // Set process name
        ProcessInfo.processInfo.setValue("Imperator CRT Overlay", forKey: "processName")

        guard let device = MTLCreateSystemDefaultDevice() else {
            let alert = NSAlert()
            alert.messageText = "Metal is required"
            alert.informativeText = "Imperator CRT Overlay needs a Metal-capable GPU."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        metalDevice = device

        installEditMenu()
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

    /// Opening the app again (Finder, Spotlight, open -a) opens the panel. With
    /// no Dock icon and the status item possibly hidden behind the notch, this
    /// is otherwise no way back to the settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.openPanel()
        return false
    }

    /// An LSUIElement app shows no menu bar, but AppKit still finds Cmd-X, C, V,
    /// A and Z through the main menu's key equivalents. Without one, the Save
    /// Preset name field could not paste, copy or select all.
    private func installEditMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
            .keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(NSMenuItem())   // the application menu's slot
        main.addItem(editItem)
        NSApp.mainMenu = main
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
            overlayWindows.append(window)
            update(window, settings: settings)
        }
    }

    @objc private func settingsChanged() {
        let settings = CRTSettings.shared
        for window in overlayWindows {
            update(window, settings: settings)
        }
    }

    /// Shows or hides one overlay and decides whether its view keeps drawing.
    ///
    /// A hidden overlay, or one whose effects do not move, needs no 30fps loop:
    /// with the overlay switched off the view kept rendering full-screen frames
    /// nobody saw, measured at about 11% of the GPU. A still look is drawn once
    /// per settings change instead.
    private func update(_ window: OverlayWindow, settings: CRTSettings) {
        let show = settings.isActive && settings.isScreenEnabled(window.displayID)
        // Only on a change: this runs for every settings notification, which a
        // slider drag sends many times a second.
        if show, !window.isVisible {
            window.orderFrontRegardless()
        } else if !show, window.isVisible {
            window.orderOut(nil)
        }
        guard let view = window.contentView?.subviews.first(where: { $0 is CRTMetalView }) as? CRTMetalView else { return }
        view.isPaused = !show || !settings.isAnimated
        if show, view.isPaused {
            view.draw()
        }
    }

    @objc private func screensChanged() {
        CRTSettings.shared.registerConnectedScreens()
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
