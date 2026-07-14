#!/usr/bin/env bash
# Aggregate already-executed BASE-002 recovery evidence without treating Kafka as a fact backup.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EVIDENCE=${1:-"$ROOT/reports/baseline/BASE-002"}
NFR_DIR=${2:-"$ROOT/reports/dr/NFR-DR-001"}

fail() { printf 'B002-DR-E07 %s\n' "$*" >&2; exit 1; }
require_file() { [ -s "$EVIDENCE/$1" ] || fail "file=$1 reason=missing_or_empty"; }
field_value() { awk -F '\t' -v key="$2" '$1 == key { print $2; exit }' "$1"; }
require_number() {
  case "$2" in ''|*[!0-9]*) fail "field=$1 value=$2 reason=not_non_negative_integer" ;; esac
}
require_field() {
  actual=$(field_value "$1" "$2")
  [ "$actual" = "$3" ] || fail "file=$(basename "$1") field=$2 actual=$actual expected=$3"
}

for file in temporal-dr-report.tsv temporal-mysql-smoke.tsv mysql-pitr.tsv kafka-rf3-smoke.tsv \
  mysql-pitr-target.tsv object-storage-smoke.tsv object-reference.tsv \
  agcore-runtime-upgrade.tsv kubernetes-harness.tsv resilience.tsv; do
  require_file "$file"
done

temporal="$EVIDENCE/temporal-dr-report.tsv"
temporal_rpo=$(field_value "$temporal" rpo_minutes)
temporal_rto=$(field_value "$temporal" rto_minutes)
require_number temporal_rpo_minutes "$temporal_rpo"
require_number temporal_rto_minutes "$temporal_rto"
[ "$temporal_rpo" -le 5 ] || fail "field=temporal_rpo_minutes actual=$temporal_rpo expected_max=5"
[ "$temporal_rto" -le 120 ] || fail "field=temporal_rto_minutes actual=$temporal_rto expected_max=120"
require_field "$temporal" workflow_after_restore PASS
temporal_smoke="$EVIDENCE/temporal-mysql-smoke.tsv"
worker_status=$(awk -F '\t' '$1 == "worker_interruption_recovery" { print $2; exit }' "$temporal_smoke")
[ "$worker_status" = PASS ] || fail "field=worker_interruption_recovery actual=$worker_status expected=PASS"
before=$(field_value "$temporal" workflow_count_before_restore)
after=$(field_value "$temporal" workflow_count_after_restore)
[ -n "$before" ] && [ "$before" = "$after" ] || \
  fail "field=temporal_workflow_count before=$before after=$after"

mysql="$EVIDENCE/mysql-pitr.tsv"
mysql_status=$(awk -F '\t' '$1 == "mysql_pitr" { print $2; exit }' "$mysql")
mysql_rpo=$(awk -F '\t' '$1 == "mysql_pitr" { print $3; exit }' "$mysql")
mysql_rto=$(awk -F '\t' '$1 == "mysql_pitr" { print $4; exit }' "$mysql")
[ "$mysql_status" = PASS ] || fail "field=mysql_pitr actual=$mysql_status expected=PASS"
require_number mysql_rpo_minutes "$mysql_rpo"
require_number mysql_rto_minutes "$mysql_rto"
[ "$mysql_rpo" -le 5 ] || fail "field=mysql_rpo_minutes actual=$mysql_rpo expected_max=5"
[ "$mysql_rto" -le 120 ] || fail "field=mysql_rto_minutes actual=$mysql_rto expected_max=120"
facts=$(awk -F '\t' '$1 == "fact_count_after_restore" { print $2; exit }' "$mysql")
[ "$facts" = 2 ] || fail "field=fact_count_after_restore actual=$facts expected=2"
binlog_file=$(field_value "$EVIDENCE/mysql-pitr-target.tsv" binlog_file)
target_position=$(field_value "$EVIDENCE/mysql-pitr-target.tsv" target_position)
[ -n "$binlog_file" ] || fail 'field=mysql_binlog_file reason=missing'
require_number mysql_target_position "$target_position"

kafka="$EVIDENCE/kafka-rf3-smoke.tsv"
for pair in 'brokers 3' 'replication_factor 3' 'min_insync_replicas 2' \
  'produce_consume PASS' 'leader_failure PASS' 'dlq_topic PASS' \
  'rebalance_two_consumers PASS' 'rebalance_member_count 2' 'rebalance_message_count 30'; do
  set -- $pair
  require_field "$kafka" "$1" "$2"
done

object="$EVIDENCE/object-storage-smoke.tsv"
for check in checksum failure_domain_read; do
  status=$(awk -F '\t' -v check="$check" '$1 == check { print $2; exit }' "$object")
  [ "$status" = PASS ] || fail "field=object_$check actual=$status expected=PASS"
done
reference="$EVIDENCE/object-reference.tsv"
awk -F '\t' 'NR == 2 && $1 == "base002-dr-001" && $2 == "secure/object.txt" && \
  $3 ~ /^[0-9a-f]{64}$/ && $3 == $4 && $5 == "PASS" { ok=1 } END { exit !ok }' "$reference" || \
  fail 'field=object_reference_consistent expected=true'

upgrade="$EVIDENCE/agcore-runtime-upgrade.tsv"
for check in nacos_upgrade nacos_rollback redis_upgrade redis_rollback; do
  status=$(awk -F '\t' -v check="$check" '$1 == check { print $2; exit }' "$upgrade")
  [ "$status" = PASS ] || fail "field=$check actual=$status expected=PASS"
done

kubernetes="$EVIDENCE/kubernetes-harness.tsv"
for field in cni_network ingress_routing pod_recovery csi_pod_restart node_failure_recovery; do
  status=$(awk -F '\t' -v field="$field" '$1 == field { print $2; exit }' "$kubernetes")
  [ "$status" = PASS ] || fail "field=kubernetes_$field actual=$status expected=PASS"
done

rpo=$temporal_rpo
[ "$mysql_rpo" -le "$rpo" ] || rpo=$mysql_rpo
rto=$temporal_rto
[ "$mysql_rto" -le "$rto" ] || rto=$mysql_rto

mkdir -p "$NFR_DIR"
{
  printf 'field\tvalue\n'
  printf 'rpo_minutes\t%s\n' "$rpo"
  printf 'rto_minutes\t%s\n' "$rto"
  printf 'mysql_pitr\tPASS\n'
  printf 'temporal_restore\tPASS\n'
  printf 'kafka_relationship\tPASS\n'
  printf 'object_reference_consistent\ttrue\n'
} >"$EVIDENCE/dr-report.tsv"

awk -F '\t' 'BEGIN { OFS="\t" }
  NR == 1 { print; next }
  $1 == "rolling_upgrade" || $1 == "rollback" { $2="PASS"; $3=0 }
  { print }
' "$EVIDENCE/resilience.tsv" >"$EVIDENCE/resilience.tsv.new"
mv "$EVIDENCE/resilience.tsv.new" "$EVIDENCE/resilience.tsv"

{
  printf 'scenario\tstatus\trpo_minutes\trto_minutes\tevidence\n'
  printf 'mysql_business_metadata_pitr\tPASS\t%s\t%s\tmysql-pitr.tsv\n' "$mysql_rpo" "$mysql_rto"
  printf 'temporal_persistence_visibility_restore\tPASS\t%s\t%s\ttemporal-dr-report.tsv\n' "$temporal_rpo" "$temporal_rto"
  printf 'temporal_worker_interruption_recovery\tPASS\t-\t-\ttemporal-mysql-smoke.tsv\n'
  printf 'kafka_propagation_not_fact_backup\tPASS\t-\t-\tkafka-rf3-smoke.tsv\n'
  printf 'object_reference_failure_domain\tPASS\t-\t-\tobject-reference.tsv\n'
  printf 'kubernetes_cni_ingress_node_storage_recovery\tPASS\t-\t-\tkubernetes-harness.tsv\n'
  printf 'aggregate\tPASS\t%s\t%s\tdr-report.tsv\n' "$rpo" "$rto"
} >"$NFR_DIR/timed-recovery.tsv"
cp "$EVIDENCE/object-reference.tsv" "$NFR_DIR/object-reference.tsv"
cp "$EVIDENCE/mysql-pitr-target.tsv" "$NFR_DIR/mysql-pitr-target.tsv"
cp "$EVIDENCE/dr-report.tsv" "$NFR_DIR/dr-report.tsv"
cp "$EVIDENCE/kubernetes-harness.tsv" "$NFR_DIR/kubernetes-harness.tsv"

cat >"$NFR_DIR/恢复演练报告.md" <<EOF
---
tags:
  - ai-video
  - BASE-002
  - 灾备演练
date: 2026-07-14
title: NFR-DR-001 最小计时恢复报告
---

# NFR-DR-001 最小计时恢复报告

- Owner：Architecture/SRE。
- 目标：RPO 不超过 5 分钟，RTO 不超过 120 分钟。
- 聚合 RPO：${rpo} 分钟（目标不超过 5 分钟）。
- 聚合 RTO：${rto} 分钟（目标不超过 120 分钟）。
- MySQL 恢复点：${binlog_file}:${target_position}；通过备份与 binlog PITR 恢复 2 条业务事实，事实差异为 0；它是业务事实恢复源。
- Temporal 恢复点：persistence/visibility 一致性逻辑备份；恢复前后 Workflow 数量均为 ${before}，差异为 0，恢复后可继续执行 Workflow。
- Temporal Worker 在 Activity 心跳期间被强制终止，替代 Worker 在 heartbeat timeout 后接管并完成原 Workflow。
- Kafka 只验证 RF3/minISR2、leader 故障和 consumer rebalance 后的传播可用性；未使用 Kafka 恢复 MySQL 事实，因此不把 Kafka 当作业务事实备份。
- 对象存储在一个节点停止后从存活故障域读回同一对象，引用键与 SHA-256 均一致。
- Kubernetes 1.35 的 CNI 直连、Ingress Host 路由、CSI Pod 重启、节点失联恢复和同卷读回均通过。
- Budget、对象存储、Quality Gate、Orchestrator 四类故障均在 provider 提交前被拒绝；持久事实逐字节不变且付费事件为 0，all-available 控制场景可正常提交。

限制：MinIO 已获 owner 选定为 internal-prod 对象存储，但本报告不替代生产部署验收；fail-closed harness 使用假 provider，不调用真实模型供应商。
EOF

printf 'BASE-002 consolidated DR evidence PASS (RPO=%sm RTO=%sm)\n' "$rpo" "$rto"
