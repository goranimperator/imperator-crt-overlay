import Foundation
import AppKit

extension Notification.Name {
    static let crtSettingsChanged = Notification.Name("CRTSettingsChanged")
    static let crtPresetsChanged = Notification.Name("CRTPresetsChanged")
}

struct PresetData: Codable {
    var name: String
    var scanlineIntensity: Float
    var vignetteIntensity: Float
    var flickerAmount: Float
    var noiseAmount: Float
    var curvatureAmount: Float
    var rgbDarkness: Float
    var rgbColor: Float
    var vhsAmount: Float
    var staticJump: Float
    var sizeScale: Float
    var tintR: Float
    var tintG: Float
    var tintB: Float
    var tintStrength: Float

    init(name: String, scanlineIntensity: Float, vignetteIntensity: Float,
         flickerAmount: Float, noiseAmount: Float, curvatureAmount: Float,
         rgbDarkness: Float, rgbColor: Float, vhsAmount: Float,
         staticJump: Float = 0.0, sizeScale: Float,
         tintR: Float, tintG: Float, tintB: Float, tintStrength: Float) {
        self.name = name
        self.scanlineIntensity = scanlineIntensity
        self.vignetteIntensity = vignetteIntensity
        self.flickerAmount = flickerAmount
        self.noiseAmount = noiseAmount
        self.curvatureAmount = curvatureAmount
        self.rgbDarkness = rgbDarkness
        self.rgbColor = rgbColor
        self.vhsAmount = vhsAmount
        self.staticJump = staticJump
        self.sizeScale = sizeScale
        self.tintR = tintR
        self.tintG = tintG
        self.tintB = tintB
        self.tintStrength = tintStrength
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        scanlineIntensity = try c.decodeIfPresent(Float.self, forKey: .scanlineIntensity) ?? 0.3
        vignetteIntensity = try c.decodeIfPresent(Float.self, forKey: .vignetteIntensity) ?? 0.25
        flickerAmount = try c.decodeIfPresent(Float.self, forKey: .flickerAmount) ?? 0.15
        noiseAmount = try c.decodeIfPresent(Float.self, forKey: .noiseAmount) ?? 0.1
        curvatureAmount = try c.decodeIfPresent(Float.self, forKey: .curvatureAmount) ?? 0.3
        rgbDarkness = try c.decodeIfPresent(Float.self, forKey: .rgbDarkness) ?? 0.0
        rgbColor = try c.decodeIfPresent(Float.self, forKey: .rgbColor) ?? 0.0
        vhsAmount = try c.decodeIfPresent(Float.self, forKey: .vhsAmount) ?? 0.0
        staticJump = try c.decodeIfPresent(Float.self, forKey: .staticJump) ?? 0.0
        sizeScale = try c.decodeIfPresent(Float.self, forKey: .sizeScale) ?? 0.0
        tintR = try c.decodeIfPresent(Float.self, forKey: .tintR) ?? 0.0
        tintG = try c.decodeIfPresent(Float.self, forKey: .tintG) ?? 0.0
        tintB = try c.decodeIfPresent(Float.self, forKey: .tintB) ?? 0.0
        tintStrength = try c.decodeIfPresent(Float.self, forKey: .tintStrength) ?? 0.0
    }
}

class CRTSettings {
    static let shared = CRTSettings()

    private var isBatchUpdate = false

    var isActive: Bool = true {
        didSet { if !isBatchUpdate { save(); notify() } }
    }
    var intensity: Float = 0.5 {
        didSet { if !isBatchUpdate { save(); notify() } }
    }
    var scanlineIntensity: Float = 0.3 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var vignetteIntensity: Float = 0.25 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var flickerAmount: Float = 0.15 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var noiseAmount: Float = 0.1 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var curvatureAmount: Float = 0.3 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var lineSpacing: Float = 3.0 {
        didSet { if !isBatchUpdate { save(); notify() } }
    }
    var rgbDarkness: Float = 0.0 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var rgbColor: Float = 0.0 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var vhsAmount: Float = 0.0 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var staticJump: Float = 0.0 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var sizeScale: Float = 0.0 {
        didSet { if !isBatchUpdate { activePresetName = nil; save(); notify() } }
    }
    var tintR: Float = 0.0
    var tintG: Float = 0.0
    var tintB: Float = 0.0
    var tintStrength: Float = 0.0

    var enabledScreens: Set<UInt32> = []
    var activePresetName: String? = nil

    // MARK: - Built-in presets

    static let builtInPresets: [PresetData] = [
        PresetData(name: "Classic Green",
                   scanlineIntensity: 0.6, vignetteIntensity: 0.5,
                   flickerAmount: 0.4, noiseAmount: 0.3, curvatureAmount: 0.4,
                   rgbDarkness: 0.5, rgbColor: 0.5, vhsAmount: 0.0, staticJump: 0.0, sizeScale: 0.1,
                   tintR: 0.0, tintG: 0.18, tintB: 0.0, tintStrength: 0.15),
        PresetData(name: "Amber Terminal",
                   scanlineIntensity: 0.5, vignetteIntensity: 0.45,
                   flickerAmount: 0.3, noiseAmount: 0.25, curvatureAmount: 0.35,
                   rgbDarkness: 0.4, rgbColor: 0.4, vhsAmount: 0.0, staticJump: 0.0, sizeScale: 0.1,
                   tintR: 0.22, tintG: 0.14, tintB: 0.0, tintStrength: 0.12),
        PresetData(name: "Cool White",
                   scanlineIntensity: 0.4, vignetteIntensity: 0.35,
                   flickerAmount: 0.2, noiseAmount: 0.15, curvatureAmount: 0.25,
                   rgbDarkness: 0.3, rgbColor: 0.3, vhsAmount: 0.0, staticJump: 0.0, sizeScale: 0.05,
                   tintR: 0.06, tintG: 0.08, tintB: 0.14, tintStrength: 0.08),
        PresetData(name: "Subtle",
                   scanlineIntensity: 0.3, vignetteIntensity: 0.25,
                   flickerAmount: 0.15, noiseAmount: 0.1, curvatureAmount: 0.2,
                   rgbDarkness: 0.15, rgbColor: 0.15, vhsAmount: 0.0, staticJump: 0.0, sizeScale: 0.0,
                   tintR: 0.0, tintG: 0.0, tintB: 0.0, tintStrength: 0.0),
        PresetData(name: "VHS Tape",
                   scanlineIntensity: 0.2, vignetteIntensity: 0.3,
                   flickerAmount: 0.3, noiseAmount: 0.25, curvatureAmount: 0.15,
                   rgbDarkness: 0.1, rgbColor: 0.1, vhsAmount: 0.7, staticJump: 0.2, sizeScale: 0.15,
                   tintR: 0.04, tintG: 0.02, tintB: 0.0, tintStrength: 0.06),
        PresetData(name: "No Effect",
                   scanlineIntensity: 0.0, vignetteIntensity: 0.0,
                   flickerAmount: 0.0, noiseAmount: 0.0, curvatureAmount: 0.0,
                   rgbDarkness: 0.0, rgbColor: 0.0, vhsAmount: 0.0, staticJump: 0.0, sizeScale: 0.0,
                   tintR: 0.0, tintG: 0.0, tintB: 0.0, tintStrength: 0.0),
    ]

    // MARK: - User presets

    var userPresets: [PresetData] = []

    var allPresets: [PresetData] {
        Self.builtInPresets + userPresets
    }

    func isBuiltIn(_ name: String) -> Bool {
        Self.builtInPresets.contains { $0.name == name }
    }

    // MARK: - Screen management

    static func displayID(for screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    func isScreenEnabled(_ displayID: UInt32) -> Bool {
        enabledScreens.contains(displayID)
    }

    func toggleScreen(_ displayID: UInt32) {
        if enabledScreens.contains(displayID) {
            enabledScreens.remove(displayID)
        } else {
            enabledScreens.insert(displayID)
        }
        save()
        notify()
    }

    // MARK: - Preset operations

    func applyPreset(_ preset: PresetData) {
        isBatchUpdate = true
        activePresetName = preset.name
        scanlineIntensity = preset.scanlineIntensity
        vignetteIntensity = preset.vignetteIntensity
        flickerAmount = preset.flickerAmount
        noiseAmount = preset.noiseAmount
        curvatureAmount = preset.curvatureAmount
        rgbDarkness = preset.rgbDarkness
        rgbColor = preset.rgbColor
        vhsAmount = preset.vhsAmount
        staticJump = preset.staticJump
        sizeScale = preset.sizeScale
        tintR = preset.tintR
        tintG = preset.tintG
        tintB = preset.tintB
        tintStrength = preset.tintStrength
        isBatchUpdate = false
        save()
        notify()
    }

    func saveCurrentAsPreset(name: String) {
        let preset = PresetData(
            name: name,
            scanlineIntensity: scanlineIntensity,
            vignetteIntensity: vignetteIntensity,
            flickerAmount: flickerAmount,
            noiseAmount: noiseAmount,
            curvatureAmount: curvatureAmount,
            rgbDarkness: rgbDarkness,
            rgbColor: rgbColor,
            vhsAmount: vhsAmount,
            staticJump: staticJump,
            sizeScale: sizeScale,
            tintR: tintR, tintG: tintG, tintB: tintB,
            tintStrength: tintStrength
        )
        if let idx = userPresets.firstIndex(where: { $0.name == name }) {
            userPresets[idx] = preset
        } else {
            userPresets.append(preset)
        }
        activePresetName = name
        saveUserPresets()
        save()
        notify()
        NotificationCenter.default.post(name: .crtPresetsChanged, object: nil)
    }

    func deleteUserPreset(name: String) {
        userPresets.removeAll { $0.name == name }
        if activePresetName == name { activePresetName = nil }
        saveUserPresets()
        save()
        notify()
        NotificationCenter.default.post(name: .crtPresetsChanged, object: nil)
    }

    // MARK: - Persistence

    func load() {
        let d = UserDefaults.standard
        loadUserPresets()
        guard d.object(forKey: "crt.version") != nil else {
            enableAllCurrentScreens()
            applyPreset(Self.builtInPresets.first { $0.name == "Subtle" }!)
            return
        }
        isBatchUpdate = true
        isActive = true
        intensity = d.object(forKey: "crt.intensity") != nil ? d.float(forKey: "crt.intensity") : 0.5
        scanlineIntensity = d.float(forKey: "crt.scanlineIntensity")
        vignetteIntensity = d.float(forKey: "crt.vignetteIntensity")
        flickerAmount = d.float(forKey: "crt.flickerAmount")
        noiseAmount = d.float(forKey: "crt.noiseAmount")
        curvatureAmount = d.float(forKey: "crt.curvatureAmount")
        lineSpacing = max(d.float(forKey: "crt.lineSpacing"), 1.0)
        rgbDarkness = d.float(forKey: "crt.rgbDarkness")
        rgbColor = d.float(forKey: "crt.rgbColor")
        vhsAmount = d.float(forKey: "crt.vhsAmount")
        staticJump = d.float(forKey: "crt.staticJump")
        sizeScale = d.float(forKey: "crt.sizeScale")
        tintR = d.float(forKey: "crt.tintR")
        tintG = d.float(forKey: "crt.tintG")
        tintB = d.float(forKey: "crt.tintB")
        tintStrength = d.float(forKey: "crt.tintStrength")
        activePresetName = d.string(forKey: "crt.activePreset")
        if let ids = d.array(forKey: "crt.enabledScreens") as? [Int] {
            enabledScreens = Set(ids.map { UInt32($0) })
        }
        if enabledScreens.isEmpty {
            enableAllCurrentScreens()
        }
        isBatchUpdate = false
    }

    private func enableAllCurrentScreens() {
        enabledScreens = Set(NSScreen.screens.map { Self.displayID(for: $0) })
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(2, forKey: "crt.version")
        d.set(isActive, forKey: "crt.isActive")
        d.set(intensity, forKey: "crt.intensity")
        d.set(scanlineIntensity, forKey: "crt.scanlineIntensity")
        d.set(vignetteIntensity, forKey: "crt.vignetteIntensity")
        d.set(flickerAmount, forKey: "crt.flickerAmount")
        d.set(noiseAmount, forKey: "crt.noiseAmount")
        d.set(curvatureAmount, forKey: "crt.curvatureAmount")
        d.set(lineSpacing, forKey: "crt.lineSpacing")
        d.set(rgbDarkness, forKey: "crt.rgbDarkness")
        d.set(rgbColor, forKey: "crt.rgbColor")
        d.set(vhsAmount, forKey: "crt.vhsAmount")
        d.set(staticJump, forKey: "crt.staticJump")
        d.set(sizeScale, forKey: "crt.sizeScale")
        d.set(tintR, forKey: "crt.tintR")
        d.set(tintG, forKey: "crt.tintG")
        d.set(tintB, forKey: "crt.tintB")
        d.set(tintStrength, forKey: "crt.tintStrength")
        d.set(activePresetName, forKey: "crt.activePreset")
        d.set(enabledScreens.map { Int($0) }, forKey: "crt.enabledScreens")
    }

    private func saveUserPresets() {
        if let data = try? JSONEncoder().encode(userPresets) {
            UserDefaults.standard.set(data, forKey: "crt.userPresets")
        }
    }

    private func loadUserPresets() {
        guard let data = UserDefaults.standard.data(forKey: "crt.userPresets"),
              let presets = try? JSONDecoder().decode([PresetData].self, from: data) else { return }
        userPresets = presets
    }

    private func notify() {
        NotificationCenter.default.post(name: .crtSettingsChanged, object: nil)
    }
}
