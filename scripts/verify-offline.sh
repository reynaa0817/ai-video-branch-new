#!/usr/bin/env bash
# 功能：验证 Story 1.3 镜像引用、持久化目录和离线依赖 manifest。
# 参数：无
# 返回值：0-验证通过，1-验证失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-video-offline.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  echo "ERROR [$1]: $2" >&2
  exit 1
}

for tool in docker node; do
  command -v "$tool" >/dev/null 2>&1 || fail "tool-$tool" "$tool is required"
done
if command -v sha256sum >/dev/null 2>&1; then
  SHA256=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  SHA256=(shasum -a 256)
else
  fail "tool-sha256" "sha256sum or shasum is required"
fi

docker compose --env-file "$ROOT_DIR/.env.example" -f "$ROOT_DIR/docker-compose.yml" config --format json >"$WORK_DIR/compose.json" \
  || fail "compose-config" "docker compose config failed"
node - "$WORK_DIR/compose.json" "$WORK_DIR/compose-images.txt" <<'NODE' || fail "compose-images" "Compose contains external, pullable or floating images"
const fs = require("fs");
const compose = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const images = [];
for (const [name, service] of Object.entries(compose.services ?? {})) {
  const image = service.image;
  if (typeof image !== "string" || !image.startsWith("local.ai-video/")) throw new Error(`${name}: external registry`);
  const tag = image.split(":").at(-1);
  if (!tag || tag === "latest" || !/(?:\d|[a-f0-9]{7,})/.test(tag)) throw new Error(`${name}: floating tag`);
  if (service.pull_policy !== "never") throw new Error(`${name}: pull_policy must be never`);
  images.push(image);
}
fs.writeFileSync(process.argv[3], `${[...new Set(images)].sort().join("\n")}\n`);
NODE
while IFS= read -r image; do
  [[ -n "$image" ]] || continue
  docker image inspect "$image" >/dev/null 2>&1 || fail "offline-image" "required local image is not loaded: $image"
  architecture="$(docker image inspect --format '{{.Architecture}}' "$image")"
  [[ "$architecture" == "arm64" ]] || fail "offline-image" "$image has architecture $architecture, expected arm64"
  if [[ -n "${EXPECTED_VCS_REF:-}" && -n "${APP_IMAGE_TAG:-}" && "$image" == *":$APP_IMAGE_TAG" ]]; then
    revision="$(docker image inspect --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$image")"
    [[ "$revision" == "$EXPECTED_VCS_REF" ]] || fail "offline-image" "$image revision $revision does not match $EXPECTED_VCS_REF"
  fi
done <"$WORK_DIR/compose-images.txt"

node - "$ROOT_DIR" "$WORK_DIR/dockerfile-images.txt" <<'NODE' || fail "dockerfile-images" "Dockerfile contains an external or floating base image"
const fs = require("fs");
const path = require("path");
const root = process.argv[2];
function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (/Dockerfile$/.test(entry.name)) out.push(full);
  }
  return out;
}
const files = [...walk(path.join(root, "deploy")), path.join(root, "web", "Dockerfile")].filter((file) => fs.existsSync(file));
const images = [];
for (const file of files) {
  const source = fs.readFileSync(file, "utf8");
  for (const match of source.matchAll(/^FROM\s+([^\s]+)/gmi)) {
    const image = match[1];
    if (!image.startsWith("local.ai-video/") || image.endsWith(":latest") || !image.includes(":")) throw new Error(`${file}: ${image}`);
    images.push(image.replace(/\$\{TARGETARCH\}/g, "arm64"));
  }
}
fs.writeFileSync(process.argv[3], `${[...new Set(images)].sort().join("\n")}\n`);
NODE
while IFS= read -r image; do
  [[ -n "$image" ]] || continue
  docker image inspect "$image" >/dev/null 2>&1 || fail "offline-image" "required builder/runtime image is not loaded: $image"
done <"$WORK_DIR/dockerfile-images.txt"
echo "[1/3] 镜像引用检查通过"

for dir in data/mysql data/temporal data/kafka data/minio data/nacos data/redis data/logs/app data/logs/error; do
  [[ -d "$ROOT_DIR/$dir" && -w "$ROOT_DIR/$dir" ]] || fail "data-directory" "$dir is missing or not writable"
done
echo "[2/3] 持久化与日志目录权限检查通过"

MANIFEST="$ROOT_DIR/deps/manifest.sha256"
[[ -s "$MANIFEST" ]] || fail "offline-manifest" "OFFLINE_DEPENDENCIES_MISSING: deps/manifest.sha256 is absent or empty"
entry_count=0
has_go_cache=false
has_pnpm_store=false
has_image_bundle=false
SEEN_PATHS="$WORK_DIR/manifest-paths.txt"
: >"$SEEN_PATHS"
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  digest="${line%%  *}"
  relative="${line#*  }"
  [[ "$digest" =~ ^[0-9a-f]{64}$ && "$relative" != "$line" ]] || fail "offline-manifest" "invalid manifest entry: $line"
  [[ "$relative" != /* && "/$relative/" != *"/../"* && "/$relative/" != *"/./"* && "$relative" != *$'\t'* ]] || fail "offline-manifest" "unsafe manifest path: $relative"
  [[ "$relative" == deps/* || "$relative" == images/* ]] || fail "offline-manifest" "artifact must be under deps/ or images/: $relative"
  ! grep -Fqx -- "$relative" "$SEEN_PATHS" || fail "offline-manifest" "duplicate manifest path: $relative"
  printf '%s\n' "$relative" >>"$SEEN_PATHS"
  entry_count=$((entry_count + 1))
  artifact="$ROOT_DIR/$relative"
  [[ -f "$artifact" && ! -L "$artifact" ]] || fail "offline-artifact" "missing or symbolic-link artifact $relative"
  [[ "$relative" == deps/go-mod-cache/* ]] && has_go_cache=true
  [[ "$relative" == deps/pnpm-store/* ]] && has_pnpm_store=true
  [[ "$relative" == images/* ]] && has_image_bundle=true
  actual="$("${SHA256[@]}" "$artifact" | awk '{print $1}')"
  [[ "$actual" == "$digest" ]] || fail "offline-digest" "digest mismatch for $relative"
done <"$MANIFEST"
(( entry_count > 0 )) || fail "offline-manifest" "manifest contains no artifact entries"
[[ "$has_go_cache" == true ]] || fail "offline-manifest" "manifest lacks go-mod-cache artifacts"
[[ "$has_pnpm_store" == true ]] || fail "offline-manifest" "manifest lacks pnpm-store artifacts"
[[ "$has_image_bundle" == true ]] || fail "offline-manifest" "manifest lacks image bundles"
echo "[3/3] 离线依赖 manifest 与实体校验通过"

echo "Story 1.3 离线部署边界验证通过"
