// G13: the README is about this app, not the stock GitLab template.
import { readFileSync } from "node:fs";

const readme = readFileSync("README.md", "utf8");
let bad = 0;

const templateTells = [
  "To make it easy for you to get started with GitLab",
  "Editing this README",
  "makeareadme.com",
  "Choose a self-explaining name",
  "## Badges",
  "Suggestions for a good README",
];
for (const t of templateTells) {
  if (readme.includes(t)) { console.log(`FAIL: GitLab template text left: ${JSON.stringify(t)}`); bad++; }
}

const mustHave = [
  "Imperator CRT Overlay",
  "## Install",
  "## Build",
  "## Release",
  "## Layout",
  "## License",
  "macOS 13",
  "not notarized",
  "make build",
  "com.goranimperator.ImperatorCRTOverlay",
];
for (const m of mustHave) {
  if (!readme.includes(m)) { console.log(`FAIL: README missing ${JSON.stringify(m)}`); bad++; }
}

// Every source file the build compiles is named in the README layout table.
const makefile = readFileSync("Makefile", "utf8");
const swiftFiles = [...makefile.matchAll(/Sources\/(\w+\.swift)/g)].map((m) => m[1]);
const unique = [...new Set(swiftFiles)];
if (unique.length === 0) { console.log("FAIL: no Swift sources parsed from the Makefile"); bad++; }
for (const f of unique) {
  if (!readme.includes(f)) { console.log(`FAIL: README layout omits ${f}`); bad++; }
}

// A real version number in a command example reads as a claim about the app.
const cmdVersion = readme.match(/make (?:dist|release) VERSION=(\d+\.\d+\.\d+)/);
if (cmdVersion) { console.log(`FAIL: command example pins a real version ${cmdVersion[1]}, use x.y.z`); bad++; }

console.log(`sources checked: ${unique.join(", ")}`);
if (bad === 0) console.log("README_OK"); else process.exit(1);
