#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const storyKey = "1-3-建立可独立构建的最小平台骨架";
const storyPath = path.join(root, "_bmad-output/implementation-artifacts", `${storyKey}.md`);
const sprintPath = path.join(root, "_bmad-output/implementation-artifacts/sprint-status.yaml");
const story = fs.readFileSync(storyPath, "utf8");
const sprint = fs.readFileSync(sprintPath, "utf8");

const storyStatus = story.match(/^Status:\s*(\S+)\s*$/m)?.[1];
const sprintStatus = sprint.match(new RegExp(`^\\s{2}${storyKey}:\\s*(\\S+)\\s*$`, "m"))?.[1];
if (!storyStatus || !sprintStatus || storyStatus !== sprintStatus) {
  throw new Error(`Story/sprint status mismatch: ${storyStatus ?? "missing"} != ${sprintStatus ?? "missing"}`);
}

if (["review", "done"].includes(storyStatus)) {
  const unchecked = story.match(/^- \[ \].*$/gm) ?? [];
  if (unchecked.length > 0) throw new Error(`${storyStatus} Story still has ${unchecked.length} unchecked task/finding(s)`);
}

const fileList = story.match(/### File List\n\n([\s\S]*?)\n### Change Log/)?.[1];
if (!fileList) throw new Error("Story File List is missing");
const listedPaths = [...fileList.matchAll(/^- `([^`]+)`/gm)].map((match) => match[1]);
for (const relative of listedPaths) {
  if (!fs.existsSync(path.join(root, relative))) throw new Error(`Story File List references missing path: ${relative}`);
}
for (const forbidden of ["web/src/main.ts", "reports/observability/OBS-001/minimal-event-roundtrip.json"]) {
  if (listedPaths.includes(forbidden)) throw new Error(`Story File List retains deleted/stale evidence: ${forbidden}`);
}

console.log(`Story metadata valid: status=${storyStatus}, listed_files=${listedPaths.length}`);
