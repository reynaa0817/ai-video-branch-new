---
title: 'TEA Test Design → BMAD Handoff Document'
version: '1.0'
workflowType: 'testarch-test-design-handoff'
inputDocuments:
  - ../test-design-architecture.md
  - ../test-design-qa.md
  - ../test-design-progress.md
  - ../../planning-artifacts/epics.md
  - ../../planning-artifacts/implementation-readiness-report-2026-07-14.md
sourceWorkflow: 'testarch-test-design'
generatedBy: 'TEA Master Test Architect / Codex'
generatedAt: '2026-07-14T02:00:00+08:00'
projectName: 'ai-video'
---

# TEA → BMAD Integration Handoff

## Purpose

本文把系统级测试设计转换为 BMAD Epic、Story 与 Sprint 排序约束。当前 Epic/Story 已生成，因此本 handoff 主要用于 Sprint 0、后续 `create-story`、ATDD 和 Gate，不反向扩大产品范围。

## TEA Artifacts Inventory

| Artifact | Path | BMAD Integration Point |
|---|---|---|
| Architecture Test Design | `_bmad-output/test-artifacts/test-design-architecture.md` | Sprint 0 架构 blocker、ASR 与风险 owner |
| QA Test Design | `_bmad-output/test-artifacts/test-design-qa.md` | Story 测试级别、执行策略、数据/工具依赖 |
| Risk & Coverage Source | `_bmad-output/test-artifacts/test-design-progress.md` | R-001～R-018、40 个原子场景与 NFR evidence |
| Readiness Assessment | `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-14.md` | NOT READY 判定与 Story 顺序修复 |

## Epic-Level Integration Guidance

### Risk References

- **Epic 1 / Sprint 0:** R-001～R-004、R-008、R-018。先物化可恢复栈、确定性时间/事件探针、供应商模拟器和预算/工作流 model harness。
- **Epic 2:** R-007、R-016、R-017。资产原子采用、digest 失效、QG 人工复核与 workspace 隔离。
- **Epic 3:** R-002～R-009、R-012、R-018。最高风险集中区；模型/价格/合规快照必须先于正式生产计划。
- **Epic 4:** R-006、R-007。局部重做不得降级质量或重生成无关内容。
- **Epic 5:** R-010、R-011、R-013、R-015～R-017。导出、删除、DR、审计与指标口径。
- **Epic 6:** R-010、R-011、R-017。需先定义不可变 PublishedContentRecord 输入，不实现自动公开发布。

### Quality Gates

| Epic | Gate Criteria |
|---|---|
| Sprint 0 / Epic 1 | R-001～R-004 无 OPEN；P0 harness 可在 CI 重复运行；全栈版本/digest 可恢复 |
| Epic 2 | 多 Slot 并发 CAS 全拒绝/全成功；输入变化使旧证据 stale；QG 覆盖权限穷举通过 |
| Epic 3 | 并发预算永不越界；UNKNOWN 请求数保持 1；重复/乱序/重启只推进一次；fallback 不降低能力 |
| Epic 4 | 局部重做仅改变受影响 digest；原版保持采用直到原子切换；撤销追加可恢复 |
| Epic 5 | QG1～QG6/权利/标识任一阻断时无 Release/Export；删除与 DR 有可恢复证据 |
| Epic 6 | 渠道规则/案件/发布登记均不可变追加；下架阻止访问、导出与重复发布且保留历史 |

## Story-Level Integration Guidance

### P0/P1 Test Scenarios → Story Acceptance Criteria

| Story | Mandatory scenario IDs |
|---|---|
| 1.1 | BASE-001 |
| 1.2 | BASE-002、NFR-DR-001 的最小 smoke |
| 1.3 | ASY-002、ASY-006、PROV-003 的 harness 前置能力 |
| 1.6 | COST-001～003、COST-007、PROV-001～004、E2E-001 |
| 2.4～2.6 | DATA-001～002、QUAL-001、R-017 workspace 隔离 |
| 3.1 | PROV-005～007、COMP-001 |
| 3.2 | COST-002、COST-004～006 |
| 3.3～3.6 | ASY-001～006、PROV-002～006、E2E-002、NFR-PERF-001 |
| 4.1～4.4 | DATA-001～002、QUAL-002、E2E-003 |
| 5.1～5.5 | COMP-002～006、E2E-004、NFR-DR-001、MET-001、NFR-A11Y-001 |
| 6.1～6.3 | COMP-007、COMP-005、审计历史不改写场景 |

### Data-TestId Requirements

只为稳定用户语义和跨状态断言添加，禁止把内部 DOM 结构当 API：

- `project-create`, `idea-input`, `budget-limit`
- `budget-spent`, `budget-reserved`, `budget-remaining`, `budget-block-reason`
- `stage-track`, `gate-card`, `gate-confirm`, `gate-revise`, `gate-pause`
- `production-status`, `next-visible-result`, `attempt-status`, `provider-block-card`
- `candidate-version`, `adopted-version`, `compare-original`, `compare-candidate`
- `qg-1`～`qg-6`, `quality-blocker`, `warning-accept`
- `ai-content-label`, `internal-release-confirm`, `internal-export`

## Risk-to-Story Mapping

| Risk ID | Category | P×I | Recommended Story/Epic | Test Level |
|---|---|---:|---|---|
| R-001 | TECH | 3×3 | 1.1、1.2 | CI / Integration |
| R-002 | DATA | 3×3 | 1.6、3.2、3.6 | Property / MySQL Integration |
| R-003 | TECH | 3×3 | 1.3、3.3、3.4 | Temporal/Kafka Integration |
| R-004 | OPS | 3×3 | 1.6、3.6 | Provider Simulator Integration |
| R-005 | SEC | 2×3 | 3.1、5.1 | Unit Decision / Egress Integration |
| R-006 | BUS | 2×3 | 3.1、3.5、3.6 | Contract / Media Golden |
| R-007 | DATA | 2×3 | 2.5、2.6、4.4 | Concurrency Integration |
| R-008 | SEC | 2×3 | 1.3、3.6 | API Security Integration |
| R-009 | BUS | 2×3 | 3.2、3.6 | Ledger Model / Integration |
| R-010 | SEC | 2×3 | 5.2～5.4、6.1 | Media/E2E/Contract |
| R-011 | DATA | 2×3 | 5.1、6.3 | Saga Fault Integration |
| R-012 | PERF | 2×2 | 3.3 | k6 / API / Component |
| R-013 | OPS | 2×3 | Sprint 0、5.5 | DR Drill |
| R-014 | TECH | 2×2 | 1.3、全契约 Story | CI Contract |
| R-015 | DATA | 2×3 | 5.5 | Property / Analytics Integration |
| R-016 | BUS | 2×3 | 2.6、5.2 | Decision Table / API |
| R-017 | SEC | 2×3 | 1.4 起全部领域 Story | API Authz / Isolation |
| R-018 | TECH | 3×2 | Sprint 0 测试框架 | Parallel Burn-in |

## Recommended BMAD → TEA Workflow Sequence

1. **TEA Test Design** (`TD`) → 本 handoff 与两份系统级设计
2. **BMAD Sprint Planning** → 建立 Sprint 0，先执行 3.1 模型策略快照，再执行 3.2 正式生产计划
3. **BMAD Create Story** → 将过大 Story 拆为可执行任务并嵌入 mandatory scenario IDs
4. **TEA ATDD** (`AT`) → 为当前 Story 生成失败的 P0/P1 验收测试
5. **BMAD Implementation** → test-first 实施
6. **TEA Automate / NFR Assess / Trace** → 补齐回归、证据与 Gate

## Phase Transition Quality Gates

| From Phase | To Phase | Gate Criteria |
|---|---|---|
| Test Design | Sprint 0 | 所有 P0 风险有 owner、mitigation、evidence path；R-001～R-004 明确为 blocker |
| Sprint 0 | Feature Story | R-001～R-004 已 MITIGATED；P0 harness 100% 通过；技术栈可恢复 |
| Create Story | ATDD | Story 不含未来依赖，Mandatory scenario IDs 与数据前置完整 |
| ATDD | Implementation | P0/P1 red tests 可确定重复，禁止硬等待和共享 journal |
| Implementation | Epic Gate | P0=100%，P1≥95%，高风险无 OPEN，NFR evidence 路径已产出 |
| Epic 5 | Internal-prod | RPO/RTO、预算零越界、QG/标识/权利/删除/审计证据完成 |
