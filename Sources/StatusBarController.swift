import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Brand colors & extensions

enum AppColors {
    static let brand = Color(red: 0xa0/255.0, green: 0x18/255.0, blue: 0x18/255.0)
    /// Brandbook 6.1: the tint over the panel's own material.
    ///
    /// This was an opaque `white: 0.06` body for a day, painted to imitate the
    /// popover imperator-widget-clock was still getting from an old SDK stamp.
    /// Every Imperator menu bar app draws a MenuBarPanel now, which lays down
    /// the system's `.popover` material, so the tint is what goes over it and
    /// the opaque fill would hide the material the match depends on.
    static let popoverBackground = Color.black.opacity(0.15)
    static let brandFaded = brand.opacity(0.25)
    static let accent = Color(red: 0.43, green: 0.05, blue: 0.05)
    static let error = Color(red: 0.9, green: 0.3, blue: 0.3)
}

extension View {
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
    @Published var basePresetName: String?
    @Published var basePresetModified = false
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
        basePresetName = s.basePresetName
        basePresetModified = s.isBasePresetModified
        enabledScreens = s.enabledScreens
        userPresets = s.userPresets
        screens = NSScreen.screens.map { (CRTSettings.displayID(for: $0), $0.localizedName) }

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: .crtSettingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(presetsChanged), name: .crtPresetsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func syncToSettings() {
        guard !suppressSync else { return }
        // Each CRTSettings setter posts .crtSettingsChanged synchronously, which would
        // re-enter settingsChanged() and copy stale values back over the edit in flight.
        suppressSync = true
        defer { suppressSync = false }
        let s = CRTSettings.shared
        // Only what changed. Every setter saves and notifies, and each preset
        // value's setter also clears the active preset, so writing all twelve
        // meant the header switch dropped the preset, and one slider event cost
        // twelve notifications and 252 UserDefaults writes.
        func write<T: Equatable>(_ key: ReferenceWritableKeyPath<CRTSettings, T>, _ value: T) {
            if s[keyPath: key] != value { s[keyPath: key] = value }
        }
        write(\.isActive, isActive)
        write(\.intensity, intensity)
        write(\.scanlineIntensity, scanlineIntensity)
        write(\.vignetteIntensity, vignetteIntensity)
        write(\.flickerAmount, flickerAmount)
        write(\.noiseAmount, noiseAmount)
        write(\.curvatureAmount, curvatureAmount)
        write(\.rgbDarkness, rgbDarkness)
        write(\.rgbColor, rgbColor)
        write(\.vhsAmount, vhsAmount)
        write(\.staticJump, staticJump)
        write(\.sizeScale, sizeScale)
        // The notifications suppressed above are also how the presets list
        // learns that an edit took the values off a preset.
        refreshPresetState()
    }

    /// The preset the list marks as current: the exact match, or else the user
    /// preset whose values are being edited.
    var currentPresetName: String? { activePresetName ?? basePresetName }

    private func refreshPresetState() {
        let s = CRTSettings.shared
        activePresetName = s.activePresetName
        basePresetName = s.basePresetName
        basePresetModified = s.isBasePresetModified
    }

    func updateBasePreset() {
        CRTSettings.shared.updateBasePreset()
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

    func renamePreset(from old: String, to new: String) -> Bool {
        CRTSettings.shared.renameUserPreset(from: old, to: new)
    }

    func deletePreset(name: String) {
        CRTSettings.shared.deleteUserPreset(name: name)
    }

    @objc private func settingsChanged() {
        guard !suppressSync else { return }
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
        enabledScreens = s.enabledScreens
        userPresets = s.userPresets
        refreshPresetState()
        suppressSync = false
    }

    @objc private func presetsChanged() {
        userPresets = CRTSettings.shared.userPresets
        refreshPresetState()
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
            activateRow
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
            UpdatesSection()
            Divider()
            footerView
        }
        .frame(width: 340)
        .background(AppColors.popoverBackground)
    }

    // MARK: - Header

    /// Drawn once. The header is rebuilt on every settings change and the glyph
    /// never varies.
    private static let headerIcon: NSImage? = {
        guard let path = Bundle.main.pathForImageResource("menubar-icon"),
              let image = NSImage(byReferencingFile: path) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        return image
    }()

    private var headerView: some View {
        HStack(spacing: 8) {
            // The app's own menu bar glyph, left of the name, as the other
            // Imperator popover apps do it.
            if let icon = PopoverContentView.headerIcon {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
            }
            Text("Imperator CRT Overlay")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// The on/off switch on its own row under the header, as in imperator-eq:
    /// ACTIVATE at the left, the switch at the right edge.
    private var activateRow: some View {
        HStack {
            Text("ACTIVATE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: $vm.isActive)
                .toggleStyle(.switch)
                .tint(AppColors.brand)
                // Anchored trailing, not centred. `scaleEffect` shrinks what is
                // drawn but keeps the switch's full layout width, so a centred
                // 0.55 scale leaves empty space between the switch and the
                // padding.
                .scaleEffect(0.55, anchor: .trailing)
                .labelsHidden()
                .onChange(of: vm.isActive) { _ in vm.syncToSettings() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
            // No animation, as in imperator-eq: the panel window resizes at once,
            // so animated content slid against it and the whole panel jumped.
            CollapsibleHeader(title: "SCREENS", isExpanded: $screensExpanded)

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
                        .scaleEffect(0.55, anchor: .trailing)
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
            CollapsibleHeader(title: "PRESETS", detail: vm.currentPresetName, isExpanded: $presetsExpanded)

            if presetsExpanded {
                // Plain rows, no ScrollView, as in imperator-eq. A ScrollView's
                // minimum height is zero, and the panel sizes to its content's
                // minimum, so the list opened with no height at all.
                // The save button is right-aligned above the list, as in
                // imperator-eq. The user's own presets come first, the
                // built-in looks after them.
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        HoverButton(action: { showSavePresetAlert() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10))
                                Text("Save current as new preset")
                                    .font(.caption)
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        ForEach(vm.userPresets, id: \.name) { preset in
                            PresetRow(
                                preset: preset,
                                isActive: vm.currentPresetName == preset.name,
                                onUpdate: preset.name == vm.basePresetName && vm.basePresetModified
                                    ? { vm.updateBasePreset() } : nil,
                                onRename: { showEditPresetAlert(preset.name) },
                                onDelete: { vm.deletePreset(name: preset.name) }
                            ) {
                                vm.applyPreset(preset)
                            }
                        }
                        ForEach(CRTSettings.builtInPresets, id: \.name) { preset in
                            PresetRow(preset: preset, isActive: vm.currentPresetName == preset.name) {
                                vm.applyPreset(preset)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func showEditPresetAlert(_ current: String) {
        let alert = NSAlert()
        alert.messageText = "Edit Preset"
        alert.informativeText = "Enter a new name for the preset:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = current
        textField.placeholderString = "Preset name"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard let panel = NSApp.windows.first(where: { $0 is MenuBarPanel && $0.isVisible }) else { return }
        alert.beginSheetModal(for: panel) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name != current else { return }
            if !vm.renamePreset(from: current, to: name) {
                let warn = NSAlert()
                warn.messageText = "Name Taken"
                warn.informativeText = "'\(name)' is already a preset. Choose a different name."
                warn.beginSheetModal(for: panel)
            }
        }
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

        // A sheet on the panel, not runModal(). The panel floats at .popUpMenu,
        // above the level of an app-modal alert, so a modal alert opened
        // underneath it. A sheet belongs to the panel and shows on top of it,
        // and MenuBarPanel holds back its click-outside and Escape handling
        // while a sheet is attached.
        guard let panel = NSApp.windows.first(where: { $0 is MenuBarPanel && $0.isVisible }) else { return }
        alert.beginSheetModal(for: panel) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            if CRTSettings.shared.isBuiltIn(name) {
                let warn = NSAlert()
                warn.messageText = "Reserved Name"
                warn.informativeText = "'\(name)' is a built-in preset. Choose a different name."
                warn.beginSheetModal(for: panel)
                return
            }
            // A user preset with the same name is overwritten.
            vm.savePreset(name: name)
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            LaunchAtLoginToggle()
            Spacer()
            HoverButton(action: aboutAction) {
                Text("About")
                    .font(.caption)
            }
            HoverButton(action: quitAction) {
                Text("Quit")
                    .font(.caption)
            }
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
                        // Past either end the value stays pinned; that is not a change.
                        guard newVal != value else { return }
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
    /// Set only on the user preset being edited, once its values have changed.
    var onUpdate: (() -> Void)? = nil
    /// Set only on the user's own presets: the pencil and trash under the pointer.
    var onRename: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ActiveDot(isActive: isActive)
                Text(preset.name)
                    .font(.system(size: 10, weight: isActive ? .medium : .regular))
                    .lineLimit(1)
            }

            Spacer()

            if let onUpdate {
                // Its own button inside the tappable row: a click on the pill
                // updates the preset and does not also re-apply it.
                Button(action: onUpdate) {
                    Text("Update")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AppColors.brand))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if isHovered, let onRename, let onDelete {
                HStack(spacing: 8) {
                    HoverButton(action: onRename) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                    }
                    HoverButton(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                }
            }
        }
        .listRow(isHovered: $isHovered, onTap: action)
        .accessibilityAddTraits(.isButton)
    }
}

/// A section title that opens and closes the rows under it, as in imperator-eq:
/// the title, the active choice after it, and the chevron at the trailing edge.
struct CollapsibleHeader: View {
    let title: String
    /// Shown after the title on the same row, regular where the title is bold,
    /// behind a brand red dot: PRESETS names the active preset.
    var detail: String?
    @Binding var isExpanded: Bool

    var body: some View {
        Button(action: { isExpanded.toggle() }) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let detail {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppColors.brand)
                            .frame(width: 8, height: 8)
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The radio mark of a preset row: a ring with a brand red dot in it when
/// active, an empty `.secondary` ring otherwise.
struct ActiveDot: View {
    let isActive: Bool

    var body: some View {
        Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
            .font(.system(size: 11))
            .foregroundStyle(isActive ? AppColors.brand : Color.secondary)
    }
}

extension View {
    /// A row in a preset list: its padding, the brand wash under the pointer,
    /// and a tap anywhere on it.
    func listRow(isHovered: Binding<Bool>, onTap: @escaping () -> Void) -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered.wrappedValue ? AppColors.brand.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onHover { isHovered.wrappedValue = $0 }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var isEnabled = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("Open at Login")
                .font(.caption)
            Toggle("", isOn: Binding(get: { isEnabled }, set: { setLoginItem($0) }))
                .toggleStyle(.switch)
                .tint(AppColors.brand)
                .scaleEffect(0.55)
                .labelsHidden()
        }
        .foregroundStyle(.primary)
        .opacity(isHovered ? 1.0 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
        // Read here, not in the @State initializer: at this app's macOS 13
        // target that initializer runs on every redraw of the panel, about 2 ms
        // a call, and its result is thrown away, so the switch also never saw a
        // change made in System Settings. Showing the panel activates the app,
        // so this re-reads on every open.
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Through the binding rather than onChange, so a refresh does not
    /// register or unregister the login item again.
    private func setLoginItem(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {}
        refresh()
    }
}

/// The update check: a row when a newer release is out, the switch for the
/// daily check, and Check Now. Rigid rows only, the panel sizes to them.
struct UpdatesSection: View {
    @ObservedObject private var checker = UpdateChecker.shared
    @AppStorage(UpdateChecker.enabledKey) private var checkForUpdates: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Check for updates")
                    .font(.caption)
                Spacer()
                Toggle("", isOn: $checkForUpdates)
                    .toggleStyle(.switch)
                    .tint(AppColors.brand)
                    .scaleEffect(0.55, anchor: .trailing)
                    .labelsHidden()
                    .onChange(of: checkForUpdates) { on in
                        if on { checker.checkIfDue() }
                    }
            }
            HStack(spacing: 8) {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(checker.available == nil ? Color.secondary : AppColors.brand)
                    .lineLimit(1)
                Spacer()
                if let update = checker.available {
                    HoverButton(action: { UpdateChecker.open(update.page) }) {
                        Text("Download")
                            .font(.caption)
                    }
                }
                HoverButton(action: { Task { await checker.check() } }) {
                    Text("Check Now")
                        .font(.caption)
                }
                .disabled(checker.status == .checking)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statusText: String {
        let current = UpdateChecker.currentVersion
        switch checker.status {
        case .idle: return "Version \(current)"
        case .checking: return "Checking..."
        case .upToDate: return "Up to date, version \(current)"
        case .failed: return "Could not reach GitHub"
        case .available(let release): return "Version \(release.version) is out, you have \(current)"
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
                .onTapGesture {
                    if let url = URL(string: "https://www.goranimperator.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
        }
        .padding(24)
        .frame(width: 300, height: 260)
        .background(AppColors.popoverBackground)
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
        // NSPanel defaults to true: About hid whenever the app deactivated, then
        // came back uninvited each time the menu bar panel activated the app.
        panel.hidesOnDeactivate = false
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
    private var panel: MenuBarPanel!
    private var viewModel: CRTSettingsViewModel!

    override init() {
        super.init()
        viewModel = CRTSettingsViewModel()

        setupStatusItem()
        setupPopover()

        // Click-outside dismissal lives in MenuBarPanel, which owns the same
        // monitor plus the exception for the status item's own click.
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        if let iconPath = Bundle.main.pathForImageResource("menubar-icon") {
            let img = NSImage(byReferencingFile: iconPath)!
            img.isTemplate = true
            // A 13pt glyph, drawn on whole pixels at 1x and 2x so its 1pt lines
            // stay sharp. Imperator AirDrop's glyph is 13.1pt tall. The canvas
            // is 16pt with the spare points below the glyph: an even height
            // centres without a half-pixel round down, and the glyph then spans
            // the same rows as AirDrop's in a 30pt menu bar.
            img.size = NSSize(width: 16, height: 16)
            button.image = img
        } else {
            button.image = NSImage(systemSymbolName: "tv", accessibilityDescription: "Imperator CRT Overlay")
        }
        button.action = #selector(togglePopover)
        button.target = self
    }

    private func setupPopover() {
        let quitAction = {
            NSApplication.shared.terminate(nil)
        }

        // The panel floats at .popUpMenu, above a normal window, so About opened
        // underneath it. Close the panel first.
        let aboutAction = { [weak self] in
            self?.closePopover()
            AboutPanelController.shared.show()
        }

        // A MenuBarPanel rather than an NSPopover. macOS 27 draws its own menu
        // bar panels as plain rounded rectangles: a 17.50 pt corner, no arrow
        // and no animation, measured off Control Centre's Wi-Fi panel. An
        // NSPopover draws none of that and exposes none of it for adjustment.
        panel = MenuBarPanel(
            content: PopoverContentView(quitAction: quitAction, aboutAction: aboutAction)
                .environmentObject(viewModel),
            width: 340
        )
    }

    @objc private func togglePopover() {
        if panel.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    /// Opens the panel unless it is already open.
    func openPanel() {
        if !panel.isShown { showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        panel.show(from: button)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        guard panel.isShown else { return }
        panel.close()
    }
}
