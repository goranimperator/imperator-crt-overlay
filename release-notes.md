The menu bar panel is now drawn by the app instead of NSPopover. It has the same corner as the
macOS menu bar panels, no arrow, and opens and closes without animation. The Presets and
Screens sections fold open downward and close upward, and the preset list no longer opens
empty.

Presets now include Intensity. Presets you saved earlier take the Intensity you are using
when you update, and choosing a built-in preset sets its own.

Your own presets get an Update button. Pick one of them, change any slider, Intensity
included, and a red Update pill appears on its row; it saves the changes into that preset.
Saving under an existing name still overwrites it.

Fixes:

- The overlay no longer renders while it is switched off, or while nothing in it moves. It
  had been using about a tenth of the GPU with the overlay off.
- The VHS glitch, static bursts and tearing stopped after a couple of minutes of uptime. They
  keep running now.
- The Save Preset dialog opened behind the panel. It now opens on top of it, and Cmd-V,
  Cmd-C and Cmd-A work in its name field.
- About opened underneath the panel. The panel now closes first.
- Turning the overlay on or off no longer drops the active preset.
- A display the app has not seen before starts with the effect on, and a saved display that
  is no longer connected no longer leaves the overlay drawing nowhere.
- Opening the app again from Finder or Spotlight opens the panel.

Ad-hoc signed, so Gatekeeper blocks the first launch: right-click the app and choose Open, or
run `xattr -dr com.apple.quarantine "/Applications/Imperator CRT Overlay.app"`.
