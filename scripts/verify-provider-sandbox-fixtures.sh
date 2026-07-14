#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
DIR="$ROOT/tests/acceptance/baseline/fixtures/provider-sandbox"
OUT=${1:-"$ROOT/reports/baseline/BASE-002/provider-sandbox-sha256.txt"}

files='model-config-snapshot.json pricing-quote.json quota-policy.json cost-policy-snapshot.json provider-eligibility.json'
for name in $files; do
  file="$DIR/$name"
  jq -e '.schema_version == 1 and .immutable == true' "$file" >/dev/null
  if jq -e 'has("environment")' "$file" >/dev/null; then
    jq -e '.environment == "sandbox-fixture-only"' "$file" >/dev/null
  fi
done
jq -e '.fail_closed == true and .max_cost_minor > 0' "$DIR/cost-policy-snapshot.json" >/dev/null
jq -e '.unit_price_minor > 0 and .currency == "CNY"' "$DIR/pricing-quote.json" >/dev/null
grep -q '不得由 internal-prod 读取' "$DIR/README.md"

shasum -a 256 $(printf "$DIR/%s " $files) | sed "s#$ROOT/##" >"$OUT"
printf 'BASE-002 provider sandbox fixtures PASS\n'
