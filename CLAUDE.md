# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Imperator CRT Overlay is a macOS menu bar app that renders a real-time CRT/VHS screen effect as a transparent overlay on all displays. Built with pure Swift + Metal and no Xcode project: it is compiled with `swiftc` via the Makefile.

## Build & Run

| Command | What it does |
| --- | --- |
| `make build` | Compile and codesign into `build/Imperator CRT Overlay.app` |
| `make run` | Build and open |
| `make clean` | Remove `build/` and `dist/` |
| `make dist VERSION=x.y.z` | Versioned, signed zip in `dist/`; touches nothing in git |
| `make release VERSION=x.y.z` | Bump, commit, tag, push and publish the GitHub release |

No test framework. Verification is a successful build plus the checks in `scripts/`, which
are plain Node and take no dependencies:

| Check | What it gates |
| --- | --- |
| `node scripts/check-toggles.mjs` | The brandbook switch recipe on every Toggle |
| `node scripts/check-pointer.mjs` | No custom hover cursor in any source |
| `node scripts/check-panel.mjs` | The panel body stays translucent over its material |
| `node scripts/check-readme.mjs` | The README still describes the app |
| `node scripts/check-hygiene.mjs` | Nothing local-only tracked, no absolute paths |
| `node scripts/check-release-zip.mjs` | The release zip carries the version, a valid signature and sdk 27.0 |

Commands are kept out of comment-carrying code blocks on purpose: pasted into zsh with
interactive comments off, a trailing `# ...` turns into extra arguments.

To install: `cp -R "build/Imperator CRT Overlay.app" /Applications/`

## Architecture

Seven source files, no external dependencies:

- **main.swift**: app entry point. Creates NSApplication and AppDelegate by hand (no @main/@NSApplicationMain).
- **AppDelegate.swift**: sets up the Metal device, creates one overlay window per screen, forces dark mode, sets the accent override and installs the Edit menu (key equivalents only, the app shows no menu bar). Decides per overlay whether it is shown and whether its view keeps drawing. Listens for screen and Space changes to keep overlays on top.
- **OverlayWindow.swift**: NSPanel subclass. Borderless, transparent, mouse-passthrough, maximum window level, `.stationary` (persists through Mission Control and Show Desktop).
- **CRTMetalView.swift**: MTKView subclass that renders the CRT effect, at 30fps while an effect moves and paused otherwise. The Metal shader is compiled from an inline string (not a .metal file). The `Uniforms` struct must match between Swift and the shader source.
- **CRTSettings.swift**: singleton (`CRTSettings.shared`) holding all effect parameters. Persists to UserDefaults with `crt.*` keys. Uses `NotificationCenter` (.crtSettingsChanged, .crtPresetsChanged) to broadcast changes. Built-in and user-created presets are stored as `PresetData`.
- **StatusBarController.swift**: the panel's contents. `AppColors`, View extensions, `CRTSettingsViewModel` (ObservableObject bridging CRTSettings), `PopoverContentView` (SwiftUI), the component structs (SettingsSlider, CustomSlider, PresetRow, LaunchAtLoginToggle, HoverButton), `AboutView`/`AboutPanelController`, and `StatusBarController` (status item and panel management).
- **MenuBarPanel.swift**: the menu bar panel itself, shared with the other Imperator menu bar apps. A borderless `NSPanel` over an `NSVisualEffectView`, so the corner radius is the app's to set. Owns click-outside, Escape and deactivation dismissal.

### Data flow

```
StatusBarController (MenuBarPanel + NSStatusItem)
  └─ PopoverContentView (SwiftUI, 340pt wide)
       └─ CRTSettingsViewModel (@Published properties)
            ↕ syncs bidirectionally via NotificationCenter
       └─ CRTSettings.shared (singleton, persists to UserDefaults)
            ↕ .crtSettingsChanged notification
       └─ AppDelegate → OverlayWindow[] → CRTMetalView (reads CRTSettings.shared each frame)
```

## Brandbook

This app follows the Imperator Apps BrandBook (`github.com:goranimperator/imperator-apps-brandbook`). Key rules:

- **Accent color**: `AppColors.brand` (#A01818) everywhere. Never use bare `Color.accentColor`.
- **Toggles**: `.switch` style, `.tint(AppColors.brand)`, `.scaleEffect(0.55)`, `.labelsHidden()`. A switch at the right edge anchors the scale `.trailing`: `scaleEffect` shrinks what is drawn but keeps the full layout width, so a centred one drifts off the padding
- **Sliders**: 4pt track, 14pt white knob, `AppColors.brand` fill, shadow `color: .black.opacity(0.3), radius: 2, y: 1`
- **Toggles carry no frame**: the macOS 27 switch is 54x24pt, so `scaleEffect(0.55)` gives
  29.7x13.2. A `.frame(width: 36, height: 20)` only adds invisible padding while reading as a
  size guarantee it does not provide. `controlSize` does nothing to a switch any more.
- **HoverButton**: opacity 0.45→1.0, `.easeInOut(duration: 0.2)`
- **Header**: `HStack { Glyph, AppName(.headline), Spacer, Toggle }`, padding H:16 V:12. The glyph is the app's own menu bar icon, 16pt, `.renderingMode(.template)` (brandbook 9.1)
- **Footer**: `HStack { LaunchAtLoginToggle, Spacer, About, Quit }`, padding H:16 V:10
- **Accordions**: chevron.right 11pt .medium, rotation 90°, labels 11pt .semibold .uppercased .secondary. They open and close without animation and hold plain rows, no `ScrollView`, as imperator-eq does
- **Dark mode forced**: `NSApp.appearance = NSAppearance(named: .darkAqua)`
- **Bundle ID**: `com.goranimperator.ImperatorCRTOverlay`

## Key Constraints

- **No Xcode**: Build uses `swiftc` directly. Asset catalogs require `actool` (full Xcode); the Makefile has a fallback `|| true`.
- **Shader changes**: The Metal shader is an inline string in CRTMetalView.swift. The `Uniforms` struct in Swift and the shader `struct Uniforms` must stay in sync: field order matters for Metal buffer layout. Bind it with `MemoryLayout<Uniforms>.stride`, not `size`.
- **Ad-hoc codesigning** is mandatory (`codesign --sign - --force --deep`) or Gatekeeper blocks the app.
- **Build stamp** must read `minos 13.0 / sdk 27.0`. Two separate flags produce it, and both
  are load-bearing. `-target arm64-apple-macos13.0` sets `minos`: without it swiftc stamps the
  minimum with the toolchain's version (measured: `minos 27.0`), which contradicts
  `LSMinimumSystemVersion 13.0` and stops the app launching below macOS 27.
  `-platform_version` pins `sdk` explicitly instead of trusting the linker default, and `sdk`
  is what AppKit reads to decide which generation of control to draw. Verify after any
  Makefile edit:
  `otool -l "build/Imperator CRT Overlay.app/Contents/MacOS/CRTImperator" | grep -A4 LC_BUILD_VERSION`
- **The menu bar panel is the app's own**, `Sources/MenuBarPanel.swift`, not an `NSPopover`.
  Do not go back to `NSPopover`: it exposes no radius, and neither frame it draws is the one
  macOS uses in the menu bar. The measurements and the reason for the 18.25 constant are
  written in `MenuBarPanel.swift`; read them there rather than restating them. No arrow and
  no animation, on purpose. `MenuBarPanel` owns click-outside and Escape dismissal, so the
  app must not add monitors of its own.
- **Panel content must be rigid.** The panel grows and shrinks with its content's minimum
  height. A `ScrollView` has a minimum height of zero, so a ScrollView in an accordion opens
  with no height at all: the presets list and its Save button vanished that way. Accordions
  also toggle without animation: the window resizes at once, and animated content slid
  against it so the whole panel jumped. Do not change `MenuBarPanel`'s sizing to work around
  either; three other apps rely on its `contentHeight` hook.
- **Rendering pauses** when an overlay is hidden or nothing in it moves
  (`CRTSettings.isAnimated`), and draws once per settings change instead. A running 30fps
  loop behind a switched-off overlay cost about 11% of the GPU.
- **Shader time wraps every 60 s.** Past about two minutes the Float products inside
  `hash21` lose every fractional bit and the VHS and static effects die.
- **Screens**: `crt.knownScreens` remembers every display seen. A new display starts on; one
  the user switched off stays off.
- **Dialogs from the panel are sheets on it** (`beginSheetModal(for:)`), never `runModal()`.
  The panel floats at `.popUpMenu`, above the level of an app-modal alert, so a modal alert
  opens underneath it.
- **Settings writes**: `syncToSettings()` writes only the values that changed. Every setter
  saves and notifies, and the effect setters clear the active preset.
- **Preset state**: a preset holds every slider, Intensity included (presets saved before
  1.0.3 take the intensity in use when they are loaded). `activePresetName` is the exact
  match and clears on the first slider edit. `basePresetName` is the user preset the values came from and survives edits; the
  Update pill on that row shows while `isBasePresetModified` is true.
- **Panel background**: `AppColors.popoverBackground` is `Color.black.opacity(0.15)`, the
  brandbook tint laid over the panel's `.popover` material. It must stay translucent; an
  opaque fill hides the material. `scripts/check-panel.mjs` gates this.
- **Hover cursor**: never change it. No `pointerStyle`, no `NSCursor.push()`/`pop()`, no
  `linkPointer()` helper. macOS does not put a hand on a control, so neither does this app.
  `scripts/check-pointer.mjs` gates this.
- **LSUIElement = true**: No Dock icon. Menu bar only.
- **Remote**: GitHub at `github.com:goranimperator/imperator-crt-overlay.git`
