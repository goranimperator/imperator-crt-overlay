# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Imperator CRT Overlay — a macOS menu bar app that renders a real-time CRT/VHS screen effect as a transparent overlay on all displays. Built with pure Swift + Metal, no Xcode project — compiled with `swiftc` via Makefile.

## Build & Run

```bash
make build    # compile + codesign → build/Imperator CRT Overlay.app
make run      # build + open
make clean    # remove build/
```

No tests, no linter, no package manager. The only verification is a successful build.

To install: `cp -R "build/Imperator CRT Overlay.app" /Applications/`

## Architecture

Six source files, no external dependencies:

- **main.swift** — App entry point. Creates NSApplication + AppDelegate manually (no @main/@NSApplicationMain).
- **AppDelegate.swift** — Sets up Metal device, creates overlay windows per screen, forces dark mode, sets accent color override. Listens for screen changes and space changes to keep overlays on top.
- **OverlayWindow.swift** — NSPanel subclass: borderless, transparent, mouse-passthrough, maximum window level, `.stationary` (persists through Mission Control/Show Desktop).
- **CRTMetalView.swift** — MTKView subclass that renders the CRT effect at 30fps. Metal shaders are compiled from an inline string (not a .metal file). The `Uniforms` struct must match between Swift and the shader source.
- **CRTSettings.swift** — Singleton (`CRTSettings.shared`) holding all effect parameters. Persists to UserDefaults with `crt.*` keys. Uses `NotificationCenter` (.crtSettingsChanged, .crtPresetsChanged) to broadcast changes. Built-in and user-created presets stored as `PresetData`.
- **StatusBarController.swift** — The entire UI. Contains: `AppColors` enum, View extensions, `CRTSettingsViewModel` (ObservableObject bridging CRTSettings), `PopoverContentView` (SwiftUI), all component structs (SettingsSlider, CustomSlider, PresetRow, LaunchAtLoginToggle, HoverButton), `AboutView`/`AboutPanelController`, and `StatusBarController` (NSPopover management).

### Data flow

```
StatusBarController (NSPopover + NSStatusItem)
  └─ PopoverContentView (SwiftUI, 340pt wide)
       └─ CRTSettingsViewModel (@Published properties)
            ↕ syncs bidirectionally via NotificationCenter
       └─ CRTSettings.shared (singleton, persists to UserDefaults)
            ↕ .crtSettingsChanged notification
       └─ AppDelegate → OverlayWindow[] → CRTMetalView (reads CRTSettings.shared each frame)
```

## Brandbook

This app follows the Imperator Apps BrandBook (`gitlab.com:goranimperator/imperator-mac-apps-brandbook`). Key rules:

- **Accent color**: `AppColors.brand` (#A01818) everywhere. Never use bare `Color.accentColor`.
- **Toggles**: `.switch` style, `.tint(AppColors.brand)`, `.scaleEffect(0.55)`, `.frame(width: 36, height: 20)`, `.labelsHidden()`
- **Sliders**: 4pt track, 14pt white knob, `AppColors.brand` fill, shadow `color: .black.opacity(0.3), radius: 2, y: 1`
- **HoverButton**: opacity 0.45→1.0, `.easeInOut(duration: 0.2)`
- **Header**: `HStack { AppName(.headline), Spacer, Toggle }`, padding H:16 V:12, no icon
- **Footer**: `HStack { LaunchAtLoginToggle, Spacer, About, Quit }`, padding H:16 V:10
- **Accordions**: chevron.right 11pt .medium, rotation 90°, labels 11pt .semibold .uppercased .secondary
- **Dark mode forced**: `NSApp.appearance = NSAppearance(named: .darkAqua)`
- **Bundle ID**: `com.goranimperator.ImperatorCRTOverlay`

## Key Constraints

- **No Xcode**: Build uses `swiftc` directly. Asset catalogs require `actool` (full Xcode) — the Makefile has a fallback `|| true`.
- **Shader changes**: The Metal shader is an inline string in CRTMetalView.swift. The `Uniforms` struct in Swift and the shader `struct Uniforms` must stay in sync — field order matters for Metal buffer layout.
- **Ad-hoc codesigning** is mandatory (`codesign --sign - --force --deep`) or Gatekeeper blocks the app.
- **LSUIElement = true**: No Dock icon. Menu bar only.
- **Remote**: GitLab at `gitlab.com:goranimperator/mac-crt-overlay.git`
