#!/usr/bin/env bash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)
TMP=$(mktemp -d /tmp/base002-kafka-rf3-test.XXXXXX)
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

bash "$ROOT/scripts/verify-kafka-rf3-baseline.sh" "$TMP"

report="$TMP/kafka-rf3-smoke.tsv"
[ -s "$report" ]
for field in produce_consume leader_failure dlq_topic rebalance_two_consumers; do
  grep -F "${field}"$'\tPASS' "$report" >/dev/null 2>&1 || {
    printf 'expected PASS for %s\n' "$field" >&2
    sed -n '1,120p' "$report" >&2
    exit 1
  }
done

members=$(awk -F '\t' '$1 == "rebalance_member_count" { print $2 }' "$report")
messages=$(awk -F '\t' '$1 == "rebalance_message_count" { print $2 }' "$report")
[ "$members" -eq 2 ]
[ "$messages" -eq 30 ]

printf 'Kafka RF3/minISR2 produce, DLQ, leader failure and rebalance PASS\n'
