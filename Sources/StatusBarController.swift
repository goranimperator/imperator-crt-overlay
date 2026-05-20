import AppKit

class PillToggleView: NSView {
    var isOn: Bool { didSet { needsDisplay = true } }
    var onToggle: ((Bool) -> Void)?

    private let trackWidth: CGFloat = 38
    private let trackHeight: CGFloat = 22
    private let knobInset: CGFloat = 2

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 28))

        let label = NSTextField(labelWithString: "Overlay Active")
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 20, y: 4, width: 120, height: 20)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let x: CGFloat = bounds.width - trackWidth - 16
        let y: CGFloat = (bounds.height - trackHeight) / 2
        let trackRect = CGRect(x: x, y: y, width: trackWidth, height: trackHeight)
        let radius = trackHeight / 2

        let trackColor = isOn ? NSColor.systemBlue : NSColor.systemGray
        ctx.setFillColor(trackColor.cgColor)
        ctx.addPath(CGPath(roundedRect: trackRect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.fillPath()

        let knobSize = trackHeight - knobInset * 2
        let knobX = isOn ? x + trackWidth - knobSize - knobInset : x + knobInset
        let knobY = y + knobInset
        let knobRect = CGRect(x: knobX, y: knobY, width: knobSize, height: knobSize)

        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 2, color: CGColor(gray: 0, alpha: 0.2))
        ctx.setFillColor(CGColor.white)
        ctx.addPath(CGPath(roundedRect: knobRect, cornerWidth: knobSize / 2, cornerHeight: knobSize / 2, transform: nil))
        ctx.fillPath()
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        onToggle?(isOn)
    }
}

class SliderMenuItemView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    var onValueChanged: ((Float) -> Void)?

    init(title: String, value: Float, maxValue: Float = 1.0) {
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 28))

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 20, y: 4, width: 75, height: 20)

        slider.floatValue = value
        slider.minValue = 0
        slider.maxValue = Double(maxValue)
        slider.isContinuous = true
        slider.frame = NSRect(x: 100, y: 4, width: 115, height: 20)
        slider.target = self
        slider.action = #selector(sliderChanged)

        valueLabel.stringValue = String(format: "%.0f%%", value * 100)
        valueLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: 218, y: 4, width: 36, height: 20)

        addSubview(titleLabel)
        addSubview(slider)
        addSubview(valueLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func sliderChanged() {
        let v = slider.floatValue
        valueLabel.stringValue = String(format: "%.0f%%", v * 100)
        onValueChanged?(v)
    }

    func setValue(_ value: Float) {
        slider.floatValue = value
        valueLabel.stringValue = String(format: "%.0f%%", value * 100)
    }
}

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var pillToggle: PillToggleView!
    private var scanlineSlider: SliderMenuItemView!
    private var vignetteSlider: SliderMenuItemView!
    private var flickerSlider: SliderMenuItemView!
    private var noiseSlider: SliderMenuItemView!
    private var curvatureSlider: SliderMenuItemView!
    private var rgbDarknessSlider: SliderMenuItemView!
    private var rgbColorSlider: SliderMenuItemView!
    private var vhsSlider: SliderMenuItemView!
    private var staticSlider: SliderMenuItemView!
    private var sizeSlider: SliderMenuItemView!
    private var screensMenu: NSMenu!
    private var screenItems: [UInt32: NSMenuItem] = [:]
    private var presetsMenu: NSMenu!

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let iconPath = Bundle.main.pathForImageResource("menubar-icon") {
                let img = NSImage(byReferencingFile: iconPath)!
                img.isTemplate = true
                img.size = NSSize(width: 18, height: 18)
                button.image = img
            } else {
                button.image = NSImage(systemSymbolName: "tv", accessibilityDescription: "CRT Imperator")
            }
        }
        menu = NSMenu()
        menu.autoenablesItems = false
        buildMenu()
        statusItem.menu = menu

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsDidChange),
            name: .crtSettingsChanged, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(presetsDidChange),
            name: .crtPresetsChanged, object: nil
        )
    }

    private func buildMenu() {
        let s = CRTSettings.shared

        pillToggle = PillToggleView(isOn: s.isActive)
        pillToggle.onToggle = { [weak self] on in
            CRTSettings.shared.isActive = on
        }
        let toggleMenuItem = NSMenuItem()
        toggleMenuItem.view = pillToggle
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())

        screensMenu = NSMenu()
        screensMenu.autoenablesItems = false
        rebuildScreensMenu()
        let screensItem = NSMenuItem(title: "Screens", action: nil, keyEquivalent: "")
        screensItem.submenu = screensMenu
        menu.addItem(screensItem)
        menu.addItem(.separator())

        scanlineSlider = addSlider(title: "Scanlines", value: s.scanlineIntensity) { s.scanlineIntensity = $0 }
        vignetteSlider = addSlider(title: "Vignette", value: s.vignetteIntensity) { s.vignetteIntensity = $0 }
        flickerSlider = addSlider(title: "Flicker", value: s.flickerAmount) { s.flickerAmount = $0 }
        noiseSlider = addSlider(title: "Noise", value: s.noiseAmount) { s.noiseAmount = $0 }
        curvatureSlider = addSlider(title: "Curvature", value: s.curvatureAmount) { s.curvatureAmount = $0 }
        rgbDarknessSlider = addSlider(title: "RGB Dark", value: s.rgbDarkness) { s.rgbDarkness = $0 }
        rgbColorSlider = addSlider(title: "RGB Color", value: s.rgbColor) { s.rgbColor = $0 }
        vhsSlider = addSlider(title: "VHS", value: s.vhsAmount) { s.vhsAmount = $0 }
        staticSlider = addSlider(title: "Static", value: s.staticJump) { s.staticJump = $0 }
        sizeSlider = addSlider(title: "Size", value: s.sizeScale) { s.sizeScale = $0 }
        menu.addItem(.separator())

        presetsMenu = NSMenu()
        presetsMenu.autoenablesItems = false
        rebuildPresetsMenu()
        let presetItem = NSMenuItem(title: "Presets", action: nil, keyEquivalent: "")
        presetItem.submenu = presetsMenu
        menu.addItem(presetItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit CRT Imperator", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func rebuildScreensMenu() {
        screensMenu.removeAllItems()
        screenItems.removeAll()
        let s = CRTSettings.shared

        for screen in NSScreen.screens {
            let displayID = CRTSettings.displayID(for: screen)
            let name = screen.localizedName
            let item = NSMenuItem(title: name, action: #selector(toggleScreen(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(displayID)
            item.state = s.isScreenEnabled(displayID) ? .on : .off
            screensMenu.addItem(item)
            screenItems[displayID] = item
        }
    }

    private func rebuildPresetsMenu() {
        presetsMenu.removeAllItems()
        let s = CRTSettings.shared

        for preset in CRTSettings.builtInPresets {
            let item = NSMenuItem(title: preset.name, action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.name
            item.state = s.activePresetName == preset.name ? .on : .off
            presetsMenu.addItem(item)
        }

        if !s.userPresets.isEmpty {
            presetsMenu.addItem(.separator())
            for preset in s.userPresets {
                let item = NSMenuItem(title: preset.name, action: #selector(selectPreset(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.name
                item.state = s.activePresetName == preset.name ? .on : .off
                presetsMenu.addItem(item)
            }
        }

        presetsMenu.addItem(.separator())

        let saveItem = NSMenuItem(title: "Save Current as Preset\u{2026}", action: #selector(savePreset), keyEquivalent: "")
        saveItem.target = self
        presetsMenu.addItem(saveItem)

        if !s.userPresets.isEmpty {
            let deleteMenu = NSMenu()
            for preset in s.userPresets {
                let item = NSMenuItem(title: preset.name, action: #selector(deletePreset(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset.name
                deleteMenu.addItem(item)
            }
            let deleteItem = NSMenuItem(title: "Delete Preset", action: nil, keyEquivalent: "")
            deleteItem.submenu = deleteMenu
            presetsMenu.addItem(deleteItem)
        }
    }

    private func addSlider(title: String, value: Float, onChange: @escaping (Float) -> Void) -> SliderMenuItemView {
        let view = SliderMenuItemView(title: title, value: value)
        view.onValueChanged = onChange
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
        return view
    }

    @objc private func toggleOverlay() {
        CRTSettings.shared.isActive.toggle()
        pillToggle.isOn = CRTSettings.shared.isActive
    }

    @objc private func toggleScreen(_ sender: NSMenuItem) {
        let displayID = UInt32(sender.tag)
        CRTSettings.shared.toggleScreen(displayID)
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        let s = CRTSettings.shared
        if let preset = s.allPresets.first(where: { $0.name == name }) {
            DispatchQueue.main.async {
                s.applyPreset(preset)
            }
        }
    }

    @objc private func savePreset() {
        let alert = NSAlert()
        alert.messageText = "Save Preset"
        alert.informativeText = "Enter a name for the preset:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "Preset name"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                if CRTSettings.shared.isBuiltIn(name) {
                    let warn = NSAlert()
                    warn.messageText = "Reserved Name"
                    warn.informativeText = "'\(name)' is a built-in preset. Choose a different name."
                    warn.runModal()
                    return
                }
                CRTSettings.shared.saveCurrentAsPreset(name: name)
            }
        }
    }

    @objc private func deletePreset(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        CRTSettings.shared.deleteUserPreset(name: name)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func settingsDidChange() {
        let s = CRTSettings.shared
        pillToggle.isOn = s.isActive
        scanlineSlider.setValue(s.scanlineIntensity)
        vignetteSlider.setValue(s.vignetteIntensity)
        flickerSlider.setValue(s.flickerAmount)
        noiseSlider.setValue(s.noiseAmount)
        curvatureSlider.setValue(s.curvatureAmount)
        rgbDarknessSlider.setValue(s.rgbDarkness)
        rgbColorSlider.setValue(s.rgbColor)
        vhsSlider.setValue(s.vhsAmount)
        staticSlider.setValue(s.staticJump)
        sizeSlider.setValue(s.sizeScale)
        for (displayID, item) in screenItems {
            item.state = s.isScreenEnabled(displayID) ? .on : .off
        }
        rebuildPresetsMenu()
    }

    @objc private func screensDidChange() {
        rebuildScreensMenu()
    }

    @objc private func presetsDidChange() {
        rebuildPresetsMenu()
    }
}
