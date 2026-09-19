// G17: nothing local-only tracked, no absolute paths, ignore rules cover the build output.
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

const sh = (c) => execSync(c, { encoding: "utf8" }).trim();
let bad = 0;

const tracked = sh("git ls-files").split("\n").filter(Boolean);
for (const f of tracked) {
  if (/settings\.local|\.DS_Store|^dist\/|^build\/|\.zip$/.test(f)) {
    console.log(`FAIL: tracked file should not be in git: ${f}`);
    bad++;
  }
}

const ignore = readFileSync(".gitignore", "utf8");
for (const rule of ["build/", "dist/", ".DS_Store", ".claude/settings.local.json"]) {
  if (!ignore.split("\n").map((l) => l.trim()).includes(rule)) {
    console.log(`FAIL: .gitignore missing rule ${rule}`);
    bad++;
  }
}

// Built at runtime so this file does not contain the literal it searches for,
// which would otherwise make the check flag itself and skip nothing else.
const homePrefix = ["/Users", "goran"].join("/");
for (const f of tracked) {
  if (!/\.(swift|md|plist|sh|mjs)$/.test(f) && f !== "Makefile") continue;
  // A tracked path can be absent from the working tree mid-rename.
  if (!existsSync(f)) continue;
  const body = readFileSync(f, "utf8");
  if (body.includes(homePrefix)) { console.log(`FAIL: absolute path in ${f}`); bad++; }
}

console.log(`tracked files: ${tracked.length}`);
if (bad === 0) console.log("HYGIENE_OK"); else process.exit(1);
