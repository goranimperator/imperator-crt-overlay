// G12: build the app's real popover view and prove its corners are clipped
// to the macOS 27 popover shape.
import { execSync } from "node:child_process";
import { mkdtempSync, copyFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const dir = mkdtempSync(join(tmpdir(), "cornercheck-"));
const bin = join(dir, "cornerprobe");
// Top-level expressions are legal only in a file named main.swift.
const probe = join(dir, "main.swift");
copyFileSync("scripts/corner-probe.swift", probe);

// Every app source except main.swift, whose top-level code would own the entry point.
const sources = execSync("git ls-files 'Sources/*.swift'", { encoding: "utf8" })
  .split("\n")
  .filter((f) => f && !f.endsWith("main.swift"));

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
process.exit(out.includes("CORNERS_ROUNDED") ? 0 : 1);
