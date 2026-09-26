// No custom hover cursor anywhere. Every hovered element keeps the macOS default
// arrow, because macOS itself does not put a hand on a control.
//
// Scans every Swift source, not just the one that happened to carry a helper
// once: a cursor set in MenuBarPanel or a view subclass is just as wrong, and
// AppKit offers several ways in besides NSCursor.push().
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const files = readdirSync("Sources")
  .filter((f) => f.endsWith(".swift"))
  .map((f) => join("Sources", f));

if (files.length === 0) { console.log("FAIL: no Swift sources found, the check would be vacuous"); process.exit(1); }

// Every way to change the cursor that AppKit or SwiftUI offers.
const banned = [
  [/NSCursor\s*\.\s*(push|pop)\s*\(/, "NSCursor.push()/pop() (a global stack that leaks when a hovered view disappears)"],
  [/NSCursor\s*\.\s*\w+\s*\.\s*set\s*\(/, "NSCursor.<cursor>.set()"],
  [/\.\s*addCursorRect\s*\(/, "addCursorRect()"],
  [/func\s+resetCursorRects\s*\(/, "resetCursorRects()"],
  [/func\s+cursorUpdate\s*\(/, "cursorUpdate()"],
  [/\.\s*cursorUpdate\b/, "an NSTrackingArea .cursorUpdate option"],
  [/\bpointerStyle\s*\(/, "SwiftUI pointerStyle()"],
  [/\bpointerVisibility\s*\(/, "SwiftUI pointerVisibility()"],
  [/func\s+linkPointer\s*\(/, "the linkPointer() helper"],
  [/func\s+cursor\s*\(\s*_\s+cursor:\s*NSCursor/, "the NSCursor-based cursor() helper"],
];

let bad = 0;
for (const file of files) {
  // Comments stripped first: prose naming NSCursor.push() is not a call to it.
  const lines = readFileSync(file, "utf8").split("\n").map((l) => l.replace(/\/\/.*$/, ""));
  lines.forEach((line, i) => {
    for (const [pattern, what] of banned) {
      if (pattern.test(line)) {
        console.log(`FAIL ${file}:${i + 1}: ${what} is not allowed: ${line.trim()}`);
        bad++;
      }
    }
  });
}

console.log(`scanned ${files.length} sources: ${files.map((f) => f.replace("Sources/", "")).join(", ")}`);
if (bad === 0) console.log("POINTER_OK: no custom hover cursor"); else process.exit(1);
