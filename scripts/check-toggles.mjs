// G6: every Toggle in the UI uses the brandbook switch recipe and nothing else.
import { readFileSync } from "node:fs";

const src = readFileSync("Sources/StatusBarController.swift", "utf8");
const lines = src.split("\n");

const required = [".toggleStyle(.switch)", ".tint(AppColors.brand)", ".labelsHidden()"];
// The scale is fixed at 0.55; the anchor is not. A header switch is anchored
// trailing, because scaleEffect shrinks what is drawn while keeping the
// switch's full layout width, which otherwise leaves a gap at the right edge.
const scalePattern = /\.scaleEffect\(0\.55(\s*,\s*anchor:\s*\.\w+)?\)/;
const banned = [".frame(width: 36, height: 20)", ".controlSize("];

const starts = [];
lines.forEach((l, i) => { if (/^\s*Toggle\(/.test(l)) starts.push(i); });

if (starts.length === 0) { console.log("FAIL: no Toggle found"); process.exit(1); }

let bad = 0;
for (const start of starts) {
  // modifier block runs until labelsHidden, or 14 lines, whichever comes first
  let end = start;
  for (let i = start; i < Math.min(start + 14, lines.length); i++) {
    end = i;
    if (lines[i].includes(".labelsHidden()")) break;
  }
  const block = lines.slice(start, end + 1).join("\n");
  for (const r of required) {
    if (!block.includes(r)) { console.log(`FAIL line ${start + 1}: missing ${r}`); bad++; }
  }
  if (!scalePattern.test(block)) {
    console.log(`FAIL line ${start + 1}: missing .scaleEffect(0.55), with or without an anchor`);
    bad++;
  }
  for (const b of banned) {
    if (block.includes(b)) { console.log(`FAIL line ${start + 1}: has banned ${b}`); bad++; }
  }
}

console.log(`toggles found: ${starts.length}`);
if (bad === 0) console.log("TOGGLES_OK"); else process.exit(1);
