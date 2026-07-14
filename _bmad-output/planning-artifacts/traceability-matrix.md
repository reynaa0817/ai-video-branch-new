---
tags:
  - ai-video
  - 需求追踪
  - 测试追踪
  - Sprint-0
date: 2026-07-14
title: AI 漫剧创作平台统一追踪矩阵
status: active
sources:
  - ./prds/prd-ai-video-2026-07-13/AI漫剧创作平台-完整PRD.md
  - ./epics.md
  - ./architecture/architecture-ai-video-2026-07-13/ARCHITECTURE-SPINE.md
  - ./ux-designs/ux-ai-video-2026-07-13/EXPERIENCE.md
  - ../test-artifacts/test-design-qa.md
---

# AI 漫剧创作平台统一追踪矩阵

## 使用规则

- 本矩阵连接 Requirement → Story → Risk → Test → Evidence → Gate；实施 Story 文件必须引用适用行。
- `Planned` 表示已有测试设计但尚无执行证据；只有 evidence path 中出现可复核产物后才能改为 `Verified`。
- P0/P1 Gate 不允许以口头确认替代证据；UNKNOWN 阈值保持 UNKNOWN，不猜值。

## FR 追踪

| Requirement | Story | Risk | Test Type / Scenario | Evidence | Owner | Gate | Status |
|---|---|---|---|---|---|---|---|
| FR1 | 1.4 | R-017 | API/E2E：项目幂等、预算先持久化、workspace 隔离 | `reports/e2e/E2E-001` | Studio/Web | Epic 1 | Planned |
| FR2 | 1.5 | R-017 | API/E2E：候选不可变、锁定设定、expected version | `reports/e2e/E2E-001` | Studio | Epic 1 | Planned |
| FR3 | 1.6 | R-002/R-004 | COST-001～003/007、PROV-001～004、E2E-001 | `reports/cost`、`reports/provider` | Budget/Model | P0 | Planned |
| FR4 | 1.7 | R-002/R-007 | 影响计划、二次授权、候选/采用/撤销 | `reports/e2e/E2E-003` | Studio/Asset | Epic 1 | Planned |
| FR5 | 2.1 | R-016 | 叙事规则 decision table、边界/property | `reports/quality/narrative` | Studio/Quality | Epic 2 | Planned |
| FR6 | 2.2 | R-007 | DependencyManifest 完整性与失效传播 | `reports/data/DATA-002` | Studio/Asset | Epic 2 | Planned |
| FR7 | 2.3 | R-016/R-017 | Gate 权限、精确 Manifest、未批准禁止推进 | `reports/quality/QUAL-001` | Studio/Quality | Epic 2 | Planned |
| FR8 | 2.4 | R-007 | 锁定设定冲突、stale 传播、重新检查 | `reports/data/DATA-002` | Studio/Quality | Epic 2 | Planned |
| FR9 | 2.5 | R-007 | DATA-001 原子 CAS/AdoptionManifest | `reports/data/DATA-001` | Asset | Epic 2 | Planned |
| FR10 | 2.6 | R-007/R-016 | QUAL-001/002、digest 变化使证据失效 | `reports/quality` | Quality | Epic 2 | Planned |
| FR11 | 3.2 | R-002/R-009 | COST-002、COST-004～006 并发预算模型 | `reports/cost` | Budget | Epic 3 | Planned |
| FR12 | 3.1 | R-005/R-006 | PROV-005～007、COMP-001 策略矩阵 | `reports/provider`、`reports/compliance` | Model/Security | Epic 3 | Planned |
| FR13 | 3.3 | R-003/R-012/R-018 | ASY-001～006、NFR-PERF-001 | `reports/async`、`reports/performance` | Workflow/Experience | Epic 3 | Planned |
| FR14 | 3.4、4.3、4.4 | R-007/R-015 | DATA-001/002、E2E-003、MET-001 | `reports/data`、`reports/e2e` | Workflow/Asset | Epic 3/4 | Planned |
| FR15 | 3.5 | R-006/R-010 | PROV-004/005、QUAL-002 媒体金样 | `reports/media` | Model/Asset/Quality | Epic 3 | Planned |
| FR16 | 3.6 | R-004/R-006/R-009 | PROV-001～006、E2E-002 | `reports/provider` | Model/Workflow | Epic 3 | Planned |
| FR17 | 4.1、4.3 | R-006/R-007 | 媒体血缘、局部替换、无关 digest 不变 | `reports/e2e/E2E-003` | Asset/Media | Epic 4 | Planned |
| FR18 | 4.2～4.4 | R-006/R-007 | 粗剪完整性、A/B、原子采用、ROUGH_CUT Gate | `reports/e2e/E2E-003` | Asset/Studio | Epic 4 | Planned |
| FR19 | 5.2、5.3 | R-010/R-016 | QUAL-001/002、E2E-004 | `reports/quality`、`reports/e2e/E2E-004` | Quality/Delivery | Epic 5 | Planned |
| FR20 | 5.4 | R-010/R-017 | COMP-003、E2E-004、媒体规格金样 | `reports/compliance`、`reports/media` | Delivery | Epic 5 | Planned |
| FR21 | 5.1 | R-005/R-011 | COMP-001/002/004、删除 Saga fault matrix | `reports/compliance` | Studio/Asset/Model | Epic 5 | Planned |
| FR22 | 5.4 | R-010 | 转码后显式标识与元数据完整性 | `reports/media/qg6` | Asset/Delivery | Epic 5 | Planned |
| FR23 | 5.3、5.5 | R-013/R-015 | COMP-006、MET-001、NFR-DR-001 | `reports/audit`、`reports/metrics` | All/Analytics | Epic 5 | Planned |
| FR24 | 6.2、6.3 | R-010/R-011/R-017 | COMP-005/007、下架/恢复 fault matrix | `reports/governance` | Governance/Delivery | Epic 6 | Planned |
| FR25 | 6.1、6.3 | R-010/R-017 | 规则版本、PublishedContentRecord 幂等导入、资格检查 | `reports/governance` | Governance | Epic 6 | Planned |

## NFR 与架构不变量追踪

| Requirement | Story / Scope | Risk | Test Type / Scenario | Evidence | Gate | Status |
|---|---|---|---|---|---|---|
| NFR1～NFR4、NFR16 | 1.2、1.3、3.3～3.6 | R-001/R-003/R-004/R-013/R-018 | BASE-001/002、ASY-001～006、PROV-001～004、NFR-DR-001 | `reports/baseline`、`reports/async`、`reports/dr` | Sprint 0 / internal-prod | Planned |
| NFR5～NFR7 | 1.3、3.3、Web 全 Story | R-012 | NFR-PERF-001、NFR-A11Y-001、UI-STATE-001 | `reports/performance`、`reports/a11y` | Web Gate | Planned |
| NFR8、NFR13 | 1.3、3.1、5.5 | R-005/R-017 | Secret scan、RBAC/authz、跨 workspace negative matrix | `reports/security` | P0/P1 | Planned |
| NFR9～NFR12 | 3.1、5.1 | R-005/R-011 | COMP-001/004、egress spy、虚拟时钟、删除回执 | `reports/compliance` | 敏感流量 Gate | Planned |
| NFR14～NFR15 | 3.3～3.6、5.5 | R-013/R-015 | OBS-001、MET-001、审计不可变性 | `reports/observability`、`reports/metrics` | Epic 5 | Planned |
| AD-1～AD-5、AD-19、AD-32、AD-33 | 1.3、全契约 Story | R-003/R-014/R-017 | 独立构建、breaking/golden、unknown fail-closed、N-1 | `reports/contracts` | CI | Planned |
| AD-7、AD-12～AD-14、AD-22～AD-24、AD-29 | 2.5～2.6、4.4、5.2～5.4 | R-007/R-010/R-016 | DATA-001/002、QUAL-001/002、E2E-004 | `reports/data`、`reports/quality` | Epic 2/5 | Planned |
| AD-8～AD-11、AD-20、AD-25～AD-28 | 1.6、3.1～3.6 | R-002/R-004/R-005/R-006/R-009 | COST-*、PROV-*、COMP-001 | `reports/cost`、`reports/provider` | Epic 1/3 | Planned |
| AD-15～AD-18、AD-30～AD-31 | 1.3、3.3、5.1、5.5 | R-011/R-012/R-013/R-017 | authz、delete Saga、SLI、DR、通知去重 | `reports/security`、`reports/dr` | internal-prod | Planned |

## UX-DR 追踪

| Requirement | Story / Surface | Test Type / Scenario | Evidence | Gate | Status |
|---|---|---|---|---|---|
| UX-DR1、14～17 | 1.3、Web 全局 | UI-STATE-001、NFR-A11Y-001：深色 MVP、响应式、键盘、axe、reduced-motion | `reports/a11y`、`reports/ui-state` | Web Gate | Planned |
| UX-DR2～6、19 | 1.4～2.3、5.3 | Component/E2E：作品卡、状态栏、阶段轨道、画布、页面内 Gate | `reports/e2e` | Epic 1/2/5 | Planned |
| UX-DR7、13、18、21 | 1.7、4.3～4.4 | E2E-003：作用范围、二次确认、结果文案、候选/采用/撤销 | `reports/e2e/E2E-003` | Epic 4 | Planned |
| UX-DR8～9、12 | 1.6、3.2～3.6 | COST/ASY/PROV：任务抽屉、三段预算、阻断解释 | `reports/cost`、`reports/async` | Epic 3 | Planned |
| UX-DR10～11 | 1.6、3.5、4.2～4.4 | Media golden、A/B 同步、字幕与 AI 标识 | `reports/media` | Epic 1/3/4 | Planned |
| UX-DR20 | 2.6、5.2～5.4 | QUAL-001/002、E2E-004：QG 分项、覆盖权限、最终资格 | `reports/quality` | Epic 5 | Planned |

## Sprint 0 放行 Gate

| Gate | Entry | Exit Evidence | Owner | Status |
|---|---|---|---|---|
| G0-1 ag-core/工具链 | Story 1.1 ready | `reports/baseline/BASE-001/`：远端内容寻址 tool commit、受保护 root version、Go 1.25.1 clean build 7/7、13/13 负向/正向合同、`go version -m` 无 GitLab | Platform | Verified |
| G0-2 全栈 P0 | Story 1.1 done | `reports/baseline/BASE-002/`、`reports/dr/NFR-DR-001/`、最终全绿 workflow run `29323611907`、artifact `8306942633`：全栈兼容、升降级、恢复、四类 provider 前置 fail-closed 与远端证据均通过 | Architecture/SRE | Verified |
| G0-3 确定性 harness | G0-2 环境可运行 | 虚拟时钟、ID-scoped probes、provider simulator、4-worker×50 burn-in | Test Architect | Open |
| G0-4 最小付费闭环 | G0-2/G0-3 通过 | Quote → Reservation → Submit → Reconcile → Asset → Quality → Adoption 金样 | Budget/Model/Asset | Open |
| G0-5 功能 Story 放行 | R-001～R-004 无 Open | P0 100%、无 score≥6 Open、readiness 不再含 C1/C2 | PO/Architect/QA | Open |
