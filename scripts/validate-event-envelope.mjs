#!/usr/bin/env node

import fs from "node:fs";

const [file] = process.argv.slice(2);
if (!file) {
  console.error("CONTRACT_INPUT_MISSING: envelope path is required");
  process.exit(2);
}

function reject(code, detail) {
  console.error(`${code}: ${detail}`);
  process.exit(1);
}

let data;
try {
  data = JSON.parse(fs.readFileSync(file, "utf8"));
} catch (error) {
  reject("CONTRACT_INVALID_JSON", error.message);
}

const allowedKeys = new Set([
  "event_id", "workspace_id", "aggregate_id", "aggregate_version",
  "owner_domain", "event_kind", "schema_version", "occurred_at",
  "producer", "trace", "payload",
]);
for (const key of Object.keys(data)) {
  if (!allowedKeys.has(key)) reject("CONTRACT_UNKNOWN_FIELD", key);
}

for (const key of ["event_id", "workspace_id", "aggregate_id", "schema_version", "occurred_at", "producer"]) {
  if (typeof data[key] !== "string" || data[key].trim() === "") reject("CONTRACT_REQUIRED_FIELD", key);
}
if (!Number.isSafeInteger(data.aggregate_version) || data.aggregate_version < 1) {
  reject("CONTRACT_INVALID_VERSION", "aggregate_version must be a positive safe integer");
}

const domains = new Set([
  "DOMAIN_STUDIO", "DOMAIN_WORKFLOW", "DOMAIN_BUDGET", "DOMAIN_ASSET",
  "DOMAIN_MODEL_GATEWAY", "DOMAIN_QUALITY", "DOMAIN_DELIVERY",
]);
if (!domains.has(data.owner_domain)) reject("CONTRACT_UNKNOWN_ENUM", "owner_domain");

const kinds = new Set(["EVENT_KIND_FACT_RECORDED", "EVENT_KIND_PROJECTION_UPDATED"]);
if (!kinds.has(data.event_kind)) reject("CONTRACT_UNKNOWN_ENUM", "event_kind");
if (data.schema_version !== "ai.video.platform.v1.DomainEventEnvelope") {
  reject("CONTRACT_SCHEMA_VERSION", data.schema_version);
}
if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(data.occurred_at) || Number.isNaN(Date.parse(data.occurred_at))) {
  reject("CONTRACT_INVALID_TIME", "occurred_at must be RFC3339 with offset");
}

if (!data.trace || typeof data.trace !== "object" || Array.isArray(data.trace)) {
  reject("CONTRACT_TRACE_REQUIRED", "trace");
}
const traceKeys = new Set(["trace_id", "span_id", "request_id"]);
for (const key of Object.keys(data.trace)) {
  if (!traceKeys.has(key)) reject("CONTRACT_UNKNOWN_FIELD", `trace.${key}`);
}
for (const key of traceKeys) {
  if (typeof data.trace[key] !== "string" || data.trace[key].trim() === "") reject("CONTRACT_TRACE_REQUIRED", key);
}

if (typeof data.payload !== "string" || data.payload === "") reject("CONTRACT_PAYLOAD_INVALID", "payload must be non-empty base64");
const payload = Buffer.from(data.payload, "base64");
if (payload.length === 0 || payload.length > 65536) reject("CONTRACT_PAYLOAD_SIZE", String(payload.length));
if (payload.toString("base64").replace(/=+$/, "") !== data.payload.replace(/=+$/, "")) reject("CONTRACT_PAYLOAD_INVALID", "non-canonical base64");

let decoded;
try {
  decoded = JSON.parse(payload.toString("utf8"));
} catch (error) {
  reject("CONTRACT_PAYLOAD_INVALID", error.message);
}
const forbiddenKey = /(secret|password|token|media_?url|prompt_?text)/i;
const forbiddenValue = /(?:https?:\/\/|bearer\s+|api[_-]?key)/i;
function scan(value) {
  if (Array.isArray(value)) return value.forEach(scan);
  if (value && typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      if (forbiddenKey.test(key)) reject("CONTRACT_SENSITIVE_PAYLOAD", key);
      scan(child);
    }
  } else if (typeof value === "string" && forbiddenValue.test(value)) {
    reject("CONTRACT_SENSITIVE_PAYLOAD", "string value");
  }
}
scan(decoded);

console.log("envelope semantic validation passed");
