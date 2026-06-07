import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Brand colors & extensions

enum AppColors {
    static let brand = Color(red: 0xa0/255.0, green: 0x18/255.0, blue: 0x18/255.0)
    static let brandFaded = brand.opacity(0.25)
    static let accent = Color(red: 0.43, green: 0.05, blue: 0.05)
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }

    func expandTapTarget() -> some View {
        contentShape(Rectangle())
    }
}

// MARK: - Observable wrapper for CRTSettings

class CRTSettingsViewModel: ObservableObject {
    @Published var isActive: Bool
    @Published var intensity: Float
    @Published var scanlineIntensity: Float
    @Published var vignetteIntensity: Float
    @Published var flickerAmount: Float
    @Published var noiseAmount: Float
    @Published var curvatureAmount: Float
    @Published var rgbDarkness: Float
    @Published var rgbColor: Float
    @Published var vhsAmount: Float
    @Published var staticJump: Float
    @Published var sizeScale: Float
    @Published var activePresetName: String?
    @Published var enabledScreens: Set<UInt32>
    @Published var screens: [(UInt32, String)]
    @Published var userPresets: [PresetData]

    private var suppressSync = false

    init() {
        let s = CRTSettings.shared
        isActive = s.isActive
        intensity = s.intensity
        scanlineIntensity = s.scanlineIntensity
        vignetteIntensity = s.vignetteIntensity
        flickerAmount = s.flickerAmount
        noiseAmount = s.noiseAmount
        curvatureAmount = s.curvatureAmount
        rgbDarkness = s.rgbDarkness
        rgbColor = s.rgbColor
        vhsAmount = s.vhsAmount
        staticJump = s.staticJump
        sizeScale = s.sizeScale
        activePresetName = s.activePresetName
        enabledScreens = s.enabledScreens
        userPresets = s.userPresets
        screens = NSScreen.screens.map { (CRTSettings.displayID(for: $0), $0.localizedName) }

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .crtSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(presetsChanged), name: .crtPresetsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func syncToSettings() {
        guard !suppressSync else { return }
        let s = CRTSettings.shared
        s.isActive = isActive
        s.intensity = intensity
        s.scanlineIntensity = scanlineIntensity
        s.vignetteIntensity = vignetteIntensity
        s.flickerAmount = flickerAmount
        s.noiseAmount = noiseAmount
        s.curvatureAmount = curvatureAmount
        s.rgbDarkness = rgbDarkness
        s.rgbColor = rgbColor
        s.vhsAmount = vhsAmount
        s.staticJump = staticJump
        s.sizeScale = sizeScale
    }

    func toggleScreen(_ displayID: UInt32) {
        CRTSettings.shared.toggleScreen(displayID)
    }

    func applyPreset(_ preset: PresetData) {
        CRTSettings.shared.applyPreset(preset)
    }

    func savePreset(name: String) {
        CRTSettings.shared.saveCurrentAsPreset(name: name)
    }

    func deletePreset(name: String) {
        CRTSettings.shared.deleteUserPreset(name: name)
    }

    @objc private func settingsChanged() {
        let s = CRTSettings.shared
        suppressSync = true
        isActive = s.isActive
        intensity = s.intensity
        scanlineIntensity = s.scanlineIntensity
        vignetteIntensity = s.vignetteIntensity
        flickerAmount = s.flickerAmount
        noiseAmount = s.noiseAmount
        curvatureAmount = s.curvatureAmount
        rgbDarkness = s.rgbDarkness
        rgbColor = s.rgbColor
        vhsAmount = s.vhsAmount
        staticJump = s.staticJump
        sizeScale = s.sizeScale
        activePresetName = s.activePresetName
        enabledScreens = s.enabledScreens
        userPresets = s.userPresets
        suppressSync = false
    }

    @objc private func presetsChanged() {
        userPresets = CRTSettings.shared.userPresets
        activePresetName = CRTSettings.shared.activePresetName
    }

    @objc private func screensChanged() {
        screens = NSScreen.screens.map { (CRTSettings.displayID(for: $0), $0.localizedName) }
        enabledScreens = CRTSettings.shared.enabledScreens
    }
}

// MARK: - SwiftUI Popover Content

struct PopoverContentView: View {
    @EnvironmentObject var vm: CRTSettingsViewModel
    let quitAction: () -> Void
    let aboutAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            VStack(spacing: 0) {
                toggleSection
                Divider().padding(.horizontal, 16)
                slidersSection
                Divider().padding(.horizontal, 16)
                screensSection
                Divider().padding(.horizontal, 16)
                presetsSection
            }
            .padding(.vertical, 8)
            Divider()
            footerView
        }
        .frame(width: 340)
        .background(.black.opacity(0.15))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            if let iconPath = Bundle.main.pathForImageResource("menubar-icon"),
               let img = NSImage(byReferencingFile: iconPath) {
                let sized = { () -> NSImage in
                    img.isTemplate = false
                    img.size = NSSize(width: 14, height: 14)
                    return img
                }()
                Image(nsImage: sized)
                    .foregroundStyle(AppColors.brand)
            }
            Text("Imperator CRT Overlay")
                .font(.headline)
            Spacer()
            Toggle("", isOn: $vm.isActive)
                .toggleStyle(.switch)
                .tint(AppColors.brand)
                .scaleEffect(0.55)
                .frame(width: 36, height: 20)
                .labelsHidden()
                .onChange(of: vm.isActive) { _ in vm.syncToSettings() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Intensity

    private var toggleSection: some View {
        VStack(spacing: 6) {
            SettingsSlider(label: "Intensity", value: $vm.intensity) { vm.syncToSettings() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Screens

    @State private var screensExpanded = false

    private var screensSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    screensExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(screensExpanded ? 90 : 0))
                    Text("SCREENS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .expandTapTarget()
            }
            .buttonStyle(.plain)

            if screensExpanded {
                ForEach(vm.screens, id: \.0) { displayID, name in
                    HStack {
                        Text(name)
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm.enabledScreens.contains(displayID) },
                            set: { _ in vm.toggleScreen(displayID) }
                        ))
                        .toggleStyle(.switch)
                        .tint(AppColors.brand)
                        .scaleEffect(0.55)
                        .frame(width: 36, height: 20)
                        .labelsHidden()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Sliders

    private var slidersSection: some View {
        VStack(spacing: 4) {
            SettingsSlider(label: "Scanlines", value: $vm.scanlineIntensity) { vm.syncToSettings() }
            SettingsSlider(label: "Vignette", value: $vm.vignetteIntensity) { vm.syncToSettings() }
            SettingsSlider(label: "Flicker", value: $vm.flickerAmount) { vm.syncToSettings() }
            SettingsSlider(label: "Noise", value: $vm.noiseAmount) { vm.syncToSettings() }
            SettingsSlider(label: "Curvature", value: $vm.curvatureAmount) { vm.syncToSettings() }
            SettingsSlider(label: "RGB Dark", value: $vm.rgbDarkness) { vm.syncToSettings() }
            SettingsSlider(label: "RGB Color", value: $vm.rgbColor) { vm.syncToSettings() }
            SettingsSlider(label: "VHS", value: $vm.vhsAmount) { vm.syncToSettings() }
            SettingsSlider(label: "Static", value: $vm.staticJump) { vm.syncToSettings() }
            SettingsSlider(label: "Size", value: $vm.sizeScale) { vm.syncToSettings() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Presets

    @State private var presetsExpanded = false

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    presetsExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(presetsExpanded ? 90 : 0))
                    Text("PRESETS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if let name = vm.activePresetName {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .expandTapTarget()
            }
            .buttonStyle(.plain)

            if presetsExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(CRTSettings.builtInPresets, id: \.name) { preset in
                            PresetRow(preset: preset, isActive: vm.activePresetName == preset.name) {
                                vm.applyPreset(preset)
                            }
                        }

                        if !vm.userPresets.isEmpty {
                            Divider().padding(.vertical, 4)
                            ForEach(vm.userPresets, id: \.name) { preset in
                                HStack {
                                    PresetRow(preset: preset, isActive: vm.activePresetName == preset.name) {
                                        vm.applyPreset(preset)
                                    }
                                    HoverButton(action: { vm.deletePreset(name: preset.name) }) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                }
                            }
                        }

                        HoverButton(action: { showSavePresetAlert() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                Text("Save Current as Preset…")
                                    .font(.caption)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func showSavePresetAlert() {
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
                vm.savePreset(name: name)
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            HoverButton(action: quitAction) {
                Text("Quit")
                    .font(.caption)
            }
            HoverButton(action: aboutAction) {
                Text("About")
                    .font(.caption)
            }
            Spacer()
            LaunchAtLoginToggle()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Reusable components

struct SettingsSlider: View {
    let label: String
    @Binding var value: Float
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .frame(width: 72, alignment: .leading)
            CustomSlider(value: $value, onChange: onChange)
            Text(String(format: "%.0f%%", value * 100))
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Float
    var onChange: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let knobSize: CGFloat = 14
            let trackH: CGFloat = 4
            let fillW = CGFloat(value) * w

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: trackH)

                // Track fill
                Capsule()
                    .fill(AppColors.brand)
                    .frame(width: fillW, height: trackH)

                // Knob
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: fillW - knobSize / 2)
            }
            .frame(height: h)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let newVal = Float(min(max(drag.location.x / w, 0), 1))
                        value = newVal
                        onChange()
                    }
            )
        }
        .frame(height: 20)
    }
}

struct PresetRow: View {
    let preset: PresetData
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(preset.name)
                    .font(.subheadline)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundStyle(AppColors.brand)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? AppColors.brand.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
        .onHover { isHovered = $0 }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("Open at Login")
                .font(.caption)
            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .tint(AppColors.brand)
                .scaleEffect(0.55)
                .frame(width: 36, height: 20)
                .labelsHidden()
        }
        .foregroundStyle(.primary)
        .opacity(isHovered ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        .onChange(of: isEnabled) { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isEnabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}

struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .opacity(isHovered ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - About Panel

struct AboutView: View {
    @State private var isLinkHovered = false

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)
            }
            Text("Imperator CRT Overlay")
                .font(.headline)
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0") (Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\u{00A9} 2024-2026 Goran Imperator")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("goranimperator.com")
                .font(.caption)
                .foregroundStyle(AppColors.brand)
                .underline(isLinkHovered)
                .onHover { isLinkHovered = $0 }
                .cursor(.pointingHand)
                .onTapGesture {
                    if let url = URL(string: "https://www.goranimperator.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
        }
        .padding(24)
        .frame(width: 300, height: 260)
        .background(.black.opacity(0.15))
    }
}

class AboutPanelController {
    static let shared = AboutPanelController()
    private var panel: NSPanel?

    func show() {
        if let existing = panel, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 260),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.center()

        let hostingView = NSHostingView(rootView: AboutView())
        panel.contentView = hostingView
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}

// MARK: - StatusBarController

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: CRTSettingsViewModel!
    private var eventMonitor: Any?

    override init() {
        super.init()
        viewModel = CRTSettingsViewModel()

        setupStatusItem()
        setupPopover()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        if let iconPath = Bundle.main.pathForImageResource("menubar-icon") {
            let img = NSImage(byReferencingFile: iconPath)!
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            button.image = img
        } else {
            button.image = NSImage(systemSymbolName: "tv", accessibilityDescription: "Imperator CRT Overlay")
        }
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let quitAction = {
            NSApplication.shared.terminate(nil)
        }

        let aboutAction = {
            AboutPanelController.shared.show()
        }

        let hostingController = NSHostingController(
            rootView: PopoverContentView(quitAction: quitAction, aboutAction: aboutAction)
                .environmentObject(viewModel)
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }
}
