The popover and the About panel no longer paint a background of their own. NSPopover already
draws the system material, and the extra translucent fill on top of it read as a second panel
sitting inside the popover, with square corners inside the rounded chrome. Both surfaces now
use the standard macOS background.

Ad-hoc signed, so Gatekeeper blocks the first launch: right-click the app and choose Open, or
run `xattr -dr com.apple.quarantine "/Applications/Imperator CRT Overlay.app"`.
