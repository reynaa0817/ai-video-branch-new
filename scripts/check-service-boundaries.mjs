#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const registry = JSON.parse(fs.readFileSync(path.join(root, "contracts/services.yaml"), "utf8"));
const entries = Object.entries(registry.services ?? {});
const forbidden = new Set(registry.forbidden_cross_service_segments ?? []);
const errors = [];

function walk(dir, predicate, result = []) {
  if (!fs.existsSync(dir)) return result;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, predicate, result);
    else if (predicate(full)) result.push(full);
  }
  return result;
}

const moduleByImportPrefix = entries.map(([name, service]) => ({
  name,
  path: service.path,
  prefix: `github.com/frochyzhang/ai-video/${service.path}/`,
}));

for (const [ownerName, owner] of entries) {
  const ownerRoot = path.join(root, owner.path);
  for (const file of walk(ownerRoot, (value) => value.endsWith(".go"))) {
    const source = fs.readFileSync(file, "utf8");
    const imports = [...source.matchAll(/["`]([^"`]+)["`]/g)].map((match) => match[1]);
    for (const imported of imports) {
      const target = moduleByImportPrefix.find((candidate) => imported.startsWith(candidate.prefix));
      if (!target || target.name === ownerName) continue;
      const remainder = imported.slice(target.prefix.length).split("/");
      if (remainder.some((segment) => forbidden.has(segment))) {
        errors.push(`${path.relative(root, file)} imports private code from ${target.name}: ${imported}`);
      }
    }
  }
}

const tableOwners = new Map();
for (const [ownerName, owner] of entries) {
  for (const file of walk(path.join(root, owner.path), (value) => value.endsWith(".sql"))) {
    const sql = fs.readFileSync(file, "utf8");
    for (const match of sql.matchAll(/\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?[`"]?([a-zA-Z0-9_]+)/gi)) {
      const table = match[1].toLowerCase();
      const previous = tableOwners.get(table);
      if (previous && previous !== ownerName) {
        errors.push(`business table ${table} is declared by both ${previous} and ${ownerName}`);
      } else {
        tableOwners.set(table, ownerName);
      }
    }
  }
}

for (const sharedRoot of ["contracts", "data"]) {
  for (const file of walk(path.join(root, sharedRoot), (value) => value.endsWith(".sql"))) {
    const sql = fs.readFileSync(file, "utf8");
    if (/\bcreate\s+table\b/i.test(sql)) {
      errors.push(`${path.relative(root, file)} defines a business table outside a fact-owning service`);
    }
  }
}

if (errors.length > 0) {
  for (const error of errors) console.error(error);
  process.exit(1);
}

console.log(`validated ${entries.length} service boundaries and ${tableOwners.size} owned SQL tables`);
