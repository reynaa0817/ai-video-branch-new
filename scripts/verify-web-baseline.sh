#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FIXTURE="$ROOT/tests/acceptance/baseline/fixtures/web"
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
IMAGE='node:24.18.0@sha256:392e1e23f34da768d8d1f4e502b64f200d3be3465934d4b7930f57d7e2fc1989'
WORK=$(mktemp -d "$ROOT/.base-002-web.XXXXXX")
trap 'chmod -R u+w "$WORK" 2>/dev/null || true; rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$EVIDENCE" "$WORK/run1" "$WORK/run2"

lock_before=$(shasum -a 256 "$FIXTURE/pnpm-lock.yaml" | awk '{print $1}')

run_build() {
  run=$1
  dir="$WORK/$run"
  cp -R "$FIXTURE/." "$dir/"
  docker run --rm --network bridge -v "$dir:/workspace" -w /workspace "$IMAGE" sh -ceu '
    corepack enable
    corepack prepare pnpm@11.4.0 --activate
    pnpm install --frozen-lockfile --ignore-scripts --store-dir /tmp/pnpm-store
    pnpm list --json --depth Infinity > dependency-tree.json
    pnpm licenses list --json > licenses.json || true
    pnpm run build
  '
  shasum -a 256 "$dir/pnpm-lock.yaml" | awk '{print $1}' >"$dir/lock.digest"
  shasum -a 256 "$dir/dependency-tree.json" | awk '{print $1}' >"$dir/tree.digest"
  jq -e . "$dir/licenses.json" >/dev/null
  find "$dir/dist" -type f -print | LC_ALL=C sort | while IFS= read -r file; do shasum -a 256 "$file"; done | \
    sed "s#$dir/dist/##" | shasum -a 256 | awk '{print $1}' >"$dir/artifact.digest"
}

run_build run1
run_build run2

lock1=$(cat "$WORK/run1/lock.digest")
lock2=$(cat "$WORK/run2/lock.digest")
tree1=$(cat "$WORK/run1/tree.digest")
tree2=$(cat "$WORK/run2/tree.digest")
artifact1=$(cat "$WORK/run1/artifact.digest")
artifact2=$(cat "$WORK/run2/artifact.digest")
[ "$lock_before" = "$lock1" ] && [ "$lock1" = "$lock2" ]
[ "$tree1" = "$tree2" ]
[ "$artifact1" = "$artifact2" ]

cp -R "$FIXTURE/." "$WORK/negative-lock/"
sed 's/"react": "19.2.7"/"react": "19.2.6"/' "$WORK/negative-lock/package.json" >"$WORK/negative-lock/package.json.next"
mv "$WORK/negative-lock/package.json.next" "$WORK/negative-lock/package.json"
if docker run --rm --network bridge -v "$WORK/negative-lock:/workspace" -w /workspace "$IMAGE" sh -ceu '
  corepack enable
  corepack prepare pnpm@11.4.0 --activate
  pnpm install --frozen-lockfile --ignore-scripts --store-dir /tmp/pnpm-store
' >"$EVIDENCE/web-negative-lock.log" 2>&1; then
  printf 'frozen lockfile negative unexpectedly passed\n' >&2
  exit 1
fi

cp -R "$FIXTURE/." "$WORK/negative-engine/"
sed 's/"node": "24.18.0"/"node": "23.0.0"/' "$WORK/negative-engine/package.json" >"$WORK/negative-engine/package.json.next"
mv "$WORK/negative-engine/package.json.next" "$WORK/negative-engine/package.json"
if docker run --rm --network bridge -v "$WORK/negative-engine:/workspace" -w /workspace "$IMAGE" sh -ceu '
  corepack enable
  corepack prepare pnpm@11.4.0 --activate
  pnpm install --frozen-lockfile --ignore-scripts --config.engine-strict=true --store-dir /tmp/pnpm-store
' >"$EVIDENCE/web-negative-engine.log" 2>&1; then
  printf 'engine mismatch negative unexpectedly passed\n' >&2
  exit 1
fi

{
  printf 'field\trun1\trun2\n'
  printf 'lockfile_digest\t%s\t%s\n' "$lock1" "$lock2"
  printf 'dependency_tree_digest\t%s\t%s\n' "$tree1" "$tree2"
  printf 'artifact_digest\t%s\t%s\n' "$artifact1" "$artifact2"
  printf 'lockfile_mutated\tfalse\tfalse\n'
  printf 'license_status\tcomplete\tcomplete\n'
} >"$EVIDENCE/web-build.tsv"
printf 'BASE-002 web frozen build PASS\n'
