// G8: pointer cursor only via the scoped SwiftUI API, and never on or beside a Toggle.
// Comments are stripped first: prose that names NSCursor.push() is not a call to it.
import { readFileSync } from "node:fs";

const raw = readFileSync("Sources/StatusBarController.swift", "utf8");
const lines = raw.split("\n").map((l) => l.replace(/\/\/.*$/, ""));
const code = lines.join("\n");
let bad = 0;

// 1. The leaky AppKit cursor-stack helper must be gone from executable code.
if (/NSCursor\s*\.\s*(push|pop)\s*\(/.test(code)) {
  console.log("FAIL: NSCursor push/pop is still called (it leaks pointingHand globally)");
  bad++;
}
if (/func\s+cursor\s*\(\s*_\s+cursor:\s*NSCursor/.test(code)) {
  console.log("FAIL: the NSCursor-based cursor() helper still exists");
  bad++;
}

// 2. Pointer styling, if any, uses pointerStyle(.link). Leading dot is optional:
//    inside a View extension it is called on implicit self.
const pointerLines = [];
lines.forEach((l, i) => { if (/\bpointerStyle\s*\(/.test(l)) pointerLines.push(i); });
for (const i of pointerLines) {
  if (!/\bpointerStyle\(\.link\)/.test(lines[i])) {
    console.log(`FAIL line ${i + 1}: unexpected pointerStyle variant: ${lines[i].trim()}`);
    bad++;
  }
}
if (pointerLines.length === 0) { console.log("FAIL: no pointerStyle call found at all"); bad++; }

// 3. No pointer styling within 12 lines of a Toggle.
const toggleLines = [];
lines.forEach((l, i) => { if (/^\s*Toggle\(/.test(l)) toggleLines.push(i); });
if (toggleLines.length === 0) { console.log("FAIL: no Toggle found, the check would be vacuous"); bad++; }
for (const t of toggleLines) {
  for (const p of pointerLines) {
    if (Math.abs(p - t) <= 12) {
      console.log(`FAIL: pointerStyle at line ${p + 1} sits within 12 lines of the Toggle at line ${t + 1}`);
      bad++;
    }
  }
}

console.log(`pointerStyle uses: ${pointerLines.length}, toggles: ${toggleLines.length}`);
if (bad === 0) console.log("POINTER_OK"); else process.exit(1);
