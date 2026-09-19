Rebuilt against the macOS 27 SDK, so AppKit now draws the current generation of controls
instead of the older ones the previous stamp pinned the app to. The switches are the wide
system capsule, and the popover's own corners match the shape macOS draws around it.

Also in this release: the effect sliders are draggable again. A settings change posted its
notification part way through saving, which copied the previous values back over the edit in
flight and snapped every slider back to where it started.

The app still runs on macOS 13 and later.

Ad-hoc signed, so Gatekeeper blocks the first launch: right-click the app and choose Open, or
run `xattr -dr com.apple.quarantine "/Applications/Imperator CRT Overlay.app"`.
