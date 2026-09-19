// G19: the published zip, not the build directory, carries 1.0.1 and a valid signature.
import { execSync } from "node:child_process";
import { existsSync, rmSync, mkdirSync } from "node:fs";

const VERSION = "1.0.1";
const zip = `dist/Imperator-CRT-Overlay-${VERSION}.zip`;
if (!existsSync(zip)) { console.log(`FAIL: ${zip} does not exist`); process.exit(1); }

const out = "/tmp/crtrelcheck";
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
execSync(`unzip -q ${JSON.stringify(zip)} -d ${out}`);

const app = `${out}/Imperator CRT Overlay.app`;
const sh = (c) => execSync(c, { encoding: "utf8" }).trim();
let bad = 0;

const short = sh(`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" ${JSON.stringify(app + "/Contents/Info.plist")}`);
if (short !== VERSION) { console.log(`FAIL: zip reports version ${short}, expected ${VERSION}`); bad++; }

const copyright = sh(`/usr/libexec/PlistBuddy -c "Print :NSHumanReadableCopyright" ${JSON.stringify(app + "/Contents/Info.plist")}`);
if (!copyright.includes("MIT License")) { console.log(`FAIL: copyright does not mention the licence: ${copyright}`); bad++; }

try {
  execSync(`codesign --verify --strict ${JSON.stringify(app)} 2>&1`);
} catch (e) {
  console.log(`FAIL: signature invalid: ${e.stdout || e.message}`);
  bad++;
}

const stamp = sh(`otool -l ${JSON.stringify(app + "/Contents/MacOS/CRTImperator")} | awk '/LC_BUILD_VERSION/,/^$/' | grep -E '^ *sdk'`);
if (!stamp.includes("27.0")) { console.log(`FAIL: shipped binary is not stamped sdk 27.0: ${stamp}`); bad++; }

console.log(`version ${short}, ${stamp.trim()}, signature valid`);
if (bad === 0) console.log("ZIP_OK"); else process.exit(1);
