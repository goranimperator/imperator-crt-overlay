# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Imperator CRT Overlay — a macOS menu bar app that renders a real-time CRT/VHS screen effect as a transparent overlay on all displays. Built with pure Swift + Metal, no Xcode project — compiled with `swiftc` via Makefile.

## Build & Run

```bash
make build    # compile + codesign → build/Imperator CRT Overlay.app
make run      # build + open
make clean    # remove build/ and dist/
make dist VERSION=x.y.z      # versioned, signed zip in dist/, touches nothing in git
make release VERSION=x.y.z   # bump, commit, tag, push, publish the GitHub release
```

No test framework. Verification is a successful build plus the checks in `scripts/`, which
are plain Node and take no dependencies:

```bash
node scripts/check-toggles.mjs    # brandbook switch recipe on every Toggle
node scripts/check-pointer.mjs    # pointer cursor scoped, never near a Toggle
node scripts/check-panel.mjs        # panel body stays translucent over its material
node scripts/check-readme.mjs     # README still describes the app
node scripts/check-hygiene.mjs    # nothing local-only tracked, no absolute paths
```

To install: `cp -R "build/Imperator CRT Overlay.app" /Applications/`

## Architecture

Six source files, no external dependencies:

- **main.swift** — App entry point. Creates NSApplication + AppDelegate manually (no @main/@NSApplicationMain).
- **AppDelegate.swift** — Sets up Metal device, creates overlay windows per screen, forces dark mode, sets accent color override. Listens for screen changes and space changes to keep overlays on top.
- **OverlayWindow.swift** — NSPanel subclass: borderless, transparent, mouse-passthrough, maximum window level, `.stationary` (persists through Mission Control/Show Desktop).
- **CRTMetalView.swift** — MTKView subclass that renders the CRT effect at 30fps. Metal shaders are compiled from an inline string (not a .metal file). The `Uniforms` struct must match between Swift and the shader source.
- **CRTSettings.swift** — Singleton (`CRTSettings.shared`) holding all effect parameters. Persists to UserDefaults with `crt.*` keys. Uses `NotificationCenter` (.crtSettingsChanged, .crtPresetsChanged) to broadcast changes. Built-in and user-created presets stored as `PresetData`.
- **StatusBarController.swift** — The entire UI. Contains: `AppColors` enum, View extensions, `CRTSettingsViewModel` (ObservableObject bridging CRTSettings), `PopoverContentView` (SwiftUI), all component structs (SettingsSlider, CustomSlider, PresetRow, LaunchAtLoginToggle, HoverButton), `AboutView`/`AboutPanelController`, and `StatusBarController` (status item and panel management).

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
- **Toggles**: `.switch` style, `.tint(AppColors.brand)`, `.scaleEffect(0.55)`, `.frame(width: 36, height: 20)`, `.labelsHidden()`
- **Sliders**: 4pt track, 14pt white knob, `AppColors.brand` fill, shadow `color: .black.opacity(0.3), radius: 2, y: 1`
- **Toggles carry no frame**: the macOS 27 switch is 54x24pt, so `scaleEffect(0.55)` gives
  29.7x13.2. A `.frame(width: 36, height: 20)` only adds invisible padding while reading as a
  size guarantee it does not provide. `controlSize` does nothing to a switch any more.
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
- **Panel background**: `AppColors.popoverBackground` is `Color.black.opacity(0.15)`, the
  brandbook tint laid over the panel's `.popover` material. It must stay translucent; an
  opaque fill hides the material. `scripts/check-panel.mjs` gates this.
- **Pointer cursor**: use `linkPointer()`, never `NSCursor.push()`/`pop()`. That stack is
  global, and a view that disappears while hovered never pops, which leaks the pointing hand
  onto every other control.
- **LSUIElement = true**: No Dock icon. Menu bar only.
- **Remote**: GitHub at `github.com:goranimperator/imperator-crt-overlay.git`
