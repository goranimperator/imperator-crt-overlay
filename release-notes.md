The app now checks for updates. Once a day it asks GitHub for the latest release and, when a
newer one is out, shows it in the panel and posts one notification. Download and the
notification open the release page. Updating is still by hand: download, unpack, replace the
app.

It is the only network request the app makes, and it sends nothing but the app's name and
version. Turn it off with Check for updates in the panel. Check Now runs it on demand.

The Screens and Presets sections now look like the ones in Imperator EQ: the chevron sits at the right edge, the active preset is named on the title row, and presets are radio rows with the save button above them. Pencil and trash show when you point at one of your own presets, and a red dot marks the active preset's name on the Presets title row.

The on/off switch moved from the header to its own Activate row under it, as in Imperator EQ.

Ad-hoc signed, so Gatekeeper blocks the first launch: right-click the app and choose Open, or
run `xattr -dr com.apple.quarantine "/Applications/Imperator CRT Overlay.app"`.
