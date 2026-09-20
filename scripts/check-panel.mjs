// Builds the app's real panel content and proves its body stays translucent.
// MenuBarPanel lays down the system's `.popover` material and the content tints
// it, so an opaque fill here would hide the material.
import { execSync } from "node:child_process";
import { mkdtempSync, copyFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const dir = mkdtempSync(join(tmpdir(), "bgcheck-"));
const bin = join(dir, "bgprobe");
// Top-level expressions are legal only in a file named main.swift.
const probe = join(dir, "main.swift");
copyFileSync("scripts/panel-probe.swift", probe);

// Every app source except main.swift, whose top-level code would own the entry
// point. Read off disk rather than out of git: a source file that is not
// committed yet is still part of the build, and asking git for the list made
// this gate fail to compile the moment a new file appeared.
const sources = readdirSync("Sources")
  .filter((f) => f.endsWith(".swift") && f !== "main.swift")
  .map((f) => join("Sources", f));

// Stamp the probe exactly as the Makefile stamps the app. AppKit draws the
// generation of controls named by the sdk field, so a probe built without this
// would render an older generation than the one that ships.
const sdk = execSync("xcrun --sdk macosx --show-sdk-version", { encoding: "utf8" }).trim();
execSync(
  `swiftc ${sources.map((s) => JSON.stringify(s)).join(" ")} ${JSON.stringify(probe)} ` +
    `-target arm64-apple-macos13.0 ` +
    `-Xlinker -platform_version -Xlinker macos -Xlinker 13.0 -Xlinker ${sdk} ` +
    `-framework AppKit -framework Metal -framework MetalKit ` +
    `-framework QuartzCore -suppress-warnings -o ${JSON.stringify(bin)}`,
  { stdio: "inherit" }
);
const stamp = execSync(
  `otool -l ${JSON.stringify(bin)} | awk '/LC_BUILD_VERSION/,/^$/' | grep -E '^ *(minos|sdk)'`,
  { encoding: "utf8" }
).trim().replace(/\s+/g, " ");
console.log(`probe stamp: ${stamp}`);
if (!stamp.includes("sdk 27.0")) { console.log("FAIL: probe is not stamped sdk 27.0"); process.exit(1); }

const out = execSync(bin, { encoding: "utf8" });
process.stdout.write(out);
process.exit(out.includes("PANEL_OK") ? 0 : 1);
