---
workflowStatus: 'complete'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-07-14'
workflowType: 'testarch-test-design'
mode: 'system-level'
title: 'AI 漫剧创作平台 QA 测试设计'
date: '2026-07-14'
author: 'Codex'
status: 'Draft - Sprint 0 Blocked'
project: 'ai-video'
inputDocuments:
  - _bmad-output/test-artifacts/test-design-architecture.md
  - _bmad-output/test-artifacts/test-design-progress.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/implementation-readiness-report-2026-07-14.md
---

# AI 漫剧创作平台 QA 测试设计

**目的：** 为 QA/开发提供可执行配方，验证异步生成、供应商故障、成本、合规与关键创作旅程。架构 blocker 和缓解责任见 `test-design-architecture.md`。

## 执行摘要

- **风险：** 18 项；16 项分数 ≥6，R-001～R-004 为 9 分 P0 blocker。
- **覆盖：** 40 个原子场景；规则优先 Unit/Property，事务与异步边界用 Integration/Contract，关键旅程才用 E2E。
- **当前状态：** 仓库尚无代码、测试框架或可运行环境；只可进入 Sprint 0 测试能力建设。
- **投入：** 初始自动化约 350～580 小时，随 Epic 增量交付；不要求 Sprint 0 一次完成。

## Not in Scope

| Item | Reasoning | Mitigation |
|---|---|---|
| 自动公开发布 | MVP 明确仅内部导出 | 阶段 C 只测试规则、案件与 PublishedContentRecord 导入 |
| 真实敏感人脸/声音 | 供应商条款与删除证据未锁 | 使用合成授权夹具；真实流量 Gate 保持关闭 |
| 真实供应商高成本回归 | PR 不得产生不可控费用 | provider simulator；sandbox 仅 weekly/候选版本 |
| 最终 NFR PASS/FAIL | 尚无实现证据 | 实现后运行 `nfr-assess` |

## Dependencies & Test Blockers

### Backend/Architecture Dependencies

1. **R-001 全栈可恢复基线**（Platform/Architecture，Sprint 0）：immutable ref/digest、兼容/回滚矩阵、干净构建与环境 smoke。
2. **R-002 预算可观测账本**（Budget，Story 1.6 前）：一致快照、整数 Money、Reservation/Authorization/Receipt 和平台差额科目。
3. **R-003 确定性异步控制**（Workflow，Sprint 0）：虚拟时钟、crash point、ID-scoped fact/event probes、Workflow history。
4. **R-004/R-008 供应商模拟器**（Model/Security，Sprint 0）：三态、签名/重复/乱序回调、计费、删除、临时 URL、配额/限流。
5. **Story 顺序修复：** 最小 Model/Pricing/Quota/Eligibility snapshot 必须先于正式生产计划。

### QA Infrastructure Setup

- Go：table/property/fuzz、Temporal test environment、Testcontainers MySQL/Kafka/Object Store、provider simulator。
- Web/API：Playwright API-first；UI 只覆盖关键 Gate、预算、故障、A/B、Release/Export 和无障碍。
- 数据：workspace/project/attempt 唯一工厂、合成授权材料、媒体金样、自动 cleanup；禁止生产数据。
- 观测：事件 journal 只按实体 ID 查询和清理；禁止全局 reset 和硬等待。

```ts
import { test } from '@seontechnologies/playwright-utils/api-request/fixtures';
import { expect } from '@playwright/test';

test('UNKNOWN 提交不会重放 @p0', async ({ apiRequest }) => {
  const result = await apiRequest({ method: 'POST', path: '/test/scenarios/provider-unknown' });
  expect(result.status).toBe(202);
  const attempt = await apiRequest({ method: 'GET', path: `/test/attempts/${result.body.attemptId}` });
  expect(attempt.body.submitCount).toBe(1);
  expect(attempt.body.state).toBe('HELD_RECONCILING');
});
```

## Risk Assessment

### High-Priority Risks

| Risk | Cat | Description | Score | QA Coverage |
|---|---|---|---:|---|
| R-001 | TECH | 栈不可恢复 | 9 | BASE-001/002 clean build、rollback smoke |
| R-002 | DATA | 预算竞态/重复扣费 | 9 | COST-001～003、005、007 model/property/integration |
| R-003 | TECH | 异步重复推进/事实分叉 | 9 | ASY-001～003 fault matrix |
| R-004 | OPS | UNKNOWN 盲重放 | 9 | PROV-001/002 provider request count |
| R-005 | SEC | 敏感数据发给不合格供应商 | 6 | COMP-001 policy matrix + egress spy |
| R-006 | BUS | 回退静默降级 | 6 | PROV-005 + QUAL-002 media golden |
| R-007 | DATA | 部分采用/stale 证据 | 6 | DATA-001/002 concurrent CAS/digest mutation |
| R-008 | SEC | 伪造/重复回调或跨租户 | 6 | PROV-003 auth/replay/isolation matrix |
| R-009 | BUS | 超额转嫁/长期占用 | 6 | COST-005/006 reconciliation |
| R-010 | SEC | 无权利/标识仍导出 | 6 | COMP-003 + E2E-004 |
| R-011 | DATA | 删除传播残留 | 6 | COMP-004 virtual clock/fault matrix |
| R-013 | OPS | 恢复不满足 RPO/RTO | 6 | NFR-DR-001 timed drill |
| R-015 | DATA | 失败项目被排除 | 6 | MET-001 cohort oracle |
| R-016 | BUS | AI 越权阻断/错误覆盖 | 6 | QUAL-001 exhaustive role matrix |
| R-017 | SEC | 跨 workspace 泄露 | 6 | authz/cache negative matrix |
| R-018 | TECH | 硬等待/共享 journal 假绿 | 6 | ASY-006 50-run parallel burn-in |

### Medium Risks

| Risk | Cat | Description | Score | QA Coverage |
|---|---|---|---:|---|
| R-012 | PERF | 投影陈旧/控制面延迟误导 | 4 | ASY-005、NFR-PERF-001 |
| R-014 | TECH | Proto/事件破坏升级 | 4 | breaking/golden/N-1 matrix |

## NFR Test Coverage Plan

| Category | Requirement | Validation | Tool/Level | Evidence | Priority |
|---|---|---|---|---|---|
| Security | OIDC/RBAC、密钥不泄露、租户隔离 | authz/secret/cross-workspace matrix | API/SAST | reports/security | P0 |
| Compliance | 合格供应商；敏感原件≤30天 | egress spy、virtual clock、delete receipts | Unit/Integration | reports/compliance | P0 |
| Reliability | 控制面99.5%、有限恢复 | duplicate/crash/chaos + SLI replay | Integration/Monitoring | reports/reliability | P0/P1 |
| DR | RPO≤5m、RTO≤2h | PITR/Temporal/Kafka/object restore | Weekly drill | reports/dr | P1 |
| Performance | 非生成 Web p95≤2s | BFF/domain/projection split load | k6/APM | reports/perf | P1 |
| Cost | 未授权越界0；无效重生成≤2% | ledger/cohort oracle | Property/Integration | reports/cost | P0 |
| Quality | 动态100%；故事/视听95%；局部≥90% | media goldens + human calibration | Integration | reports/qg | P1 |
| Accessibility | WCAG 2.1 AA 核心 | axe、键盘、reduced-motion | Component/E2E | reports/a11y | P1 |
| Maintainability | 独立构建/兼容/可观测 | build、breaking、coverage/flake | CI | reports/ci | P1 |

**Missing:** 供应商并发/QPS/回调/删除 SLA、最大尝试与熔断阈值、投影陈旧度、代表性负载、外部治理 SLA；均保持 UNKNOWN，不猜值。

## Entry Criteria

- [ ] R-001～R-004 对应 harness 可运行，Story 3.1 模型/价格/配额/资格快照已先于 Story 3.2 正式生产计划。
- [ ] local/CI 环境、合成数据、媒体金样、虚拟时钟与自动清理可用。
- [ ] 当前 Story 的 Proto/事件/状态/错误码已冻结，P0/P1 ATDD 已 red。
- [ ] 真实敏感/供应商 sandbox 访问具备明确审批；否则使用 simulator。

## Exit Criteria

- [ ] P0 100% 通过；P1 ≥95%；无 open P0/P1 缺陷或 score≥6 风险。
- [ ] P0/P1 AC trace 100%，总体自动化需求覆盖 ≥80%。
- [ ] 预算、三态提交、Gate/QG 权限和状态机合法转移分支 100%；领域纯逻辑 branch ≥80%。
- [ ] P0/P1 4-worker burn-in 50 次无随机失败、无硬等待。
- [ ] 当前 Epic 的 NFR evidence artifact 已生成；最终 NFR 结论交给 `nfr-assess`。

## Test Coverage Plan

> P0/P1/P2/P3 表示风险优先级，不表示执行时机。

### P0 — Critical

| Test IDs | Requirement | Level | Risk | Notes |
|---|---|---|---|---|
| BASE-001/002 | 可恢复栈 | CI/Integration | R-001 | Sprint 0 Gate |
| ASY-001～003 | 唯一推进/恢复 | Unit+Integration | R-003 | duplicate/reorder/crash |
| PROV-001～003 | 三态/UNKNOWN/回调 | Unit+Integration | R-004/R-008 | simulator |
| COST-001～003/005/007 | 预算/授权/责任 | Property+MySQL | R-002/R-009 | ledger oracle |
| COMP-001/003～005 | 准入/导出/删除/RBAC | Unit+Integration+E2E | R-005/R-010/R-011 | fail-closed |
| DATA-001 | 原子采用 | Concurrency Integration | R-007 | all-or-nothing |
| QUAL-001 | QG 权限 | Unit/API | R-016 | exhaustive matrix |
| E2E-001/002/004 | 样片/故障/Release | API-first E2E | R-002～R-010 | critical journeys |

### P1 — High

| Test IDs | Requirement | Level | Risk | Notes |
|---|---|---|---|---|
| ASY-004～006 | 暂停/投影/并行 | Integration/Component | R-012/R-018 | no hard waits |
| PROV-004～007 | 转存/回退/限流/删除 | Contract/Integration | R-006/R-011 | virtual clock |
| COST-004/006 | 阈值/释放/统计 | Unit+Integration | R-009/R-015 | monotonic events |
| COMP-002/006/007 | 权利/审计/治理 | Integration | R-010/R-011/R-017 | immutable history |
| DATA-002/QUAL-002/MET-001 | stale/QG/cohort | Property+Integration | R-007/R-015/R-016 | golden/oracle |
| E2E-003 | 局部重做 | E2E | R-006/R-007 | unrelated digest unchanged |
| NFR-* | DR/性能/无障碍 | Drill/k6/E2E | R-012/R-013 | separate evidence |

### P2 — Medium

| Test ID | Requirement | Level | Risk | Notes |
|---|---|---|---|---|
| UI-STATE-001 | 主题/响应式/状态文案 | Component | R-012 | dark MVP only |
| OBS-001 | trace/log/metric schema | Integration | R-014 | no sensitive values |
| ADMIN-001 | 管理配置普通错误流 | API/UI smoke | R-005 | secondary admin flow |

### P3 — Low

| Test ID | Requirement | Level | Notes |
|---|---|---|---|
| EXP-001 | 供应商/媒体探索性兼容 | Exploratory | sandbox only |
| BENCH-001 | 非 Gate 性能基准趋势 | Benchmark | no release promise |

## Execution Strategy

- **PR（<15 分钟）：** 全部可快速运行的 functional tests：unit/property、breaking/golden、静态/secret scan、短 MySQL/Temporal integration；真实供应商调用为 0。
- **Nightly（30～90 分钟）：** 全 integration、4-worker burn-in、provider/object fault matrix、媒体金样、关键 E2E、短时 k6、axe。
- **Weekly / Release Candidate（小时级）：** DR/PITR、滚动升级/回滚、长时 chaos/endurance、供应商 sandbox 合同、完整 Release/Export/删除演练。
- 原则：除昂贵基础设施或长时运行外，功能测试都进 PR；不按 P0/P1 再创建重复执行层级。

## QA Effort Estimate

| Priority | Effort Range | Notes |
|---|---|---|
| P0 | 约 120～190 小时 | simulator、时钟/探针、model/property、关键 E2E |
| P1 | 约 150～240 小时 | resilience/compliance/NFR/媒体证据 |
| P2 | 约 60～110 小时 | 次要 UI、观测与管理回归 |
| P3 | 约 20～40 小时 | 探索与趋势基准 |
| Total | 约 350～580 小时 | 2～4 人随 Epic 约 6～10 周增量交付 |

估算包含设计、实现、调试和 CI；不含生产代码、环境采购、供应商/法务工作，持续维护另计。

## Implementation Planning Handoff

- **Sprint 0 / Platform+QA：** BASE、provider simulator、virtual clock、event/fact probes、数据/媒体工厂、最小 CI。
- **Budget/Workflow/Model：** 在首次付费样片前完成 COST/ASY/PROV P0；模型/价格/资格快照先于生产计划。
- **每个 Story：** `create-story` 引用 `_bmad-output/test-artifacts/test-design/ai-video-handoff.md` 的 mandatory scenario IDs；随后单独运行 ATDD。
- **Epic Gate：** 以风险和 evidence 为依据，不以“供应商 API 返回成功”或 UI 演示替代。

## Appendix A: Code Examples & Tagging

- Tag：`@p0 @p1 @integration @provider @budget @compliance @media`。
- 异步断言只使用条件轮询/虚拟时间；超时错误必须携带最后事实、收到事件和 matcher 详情。
- 并行测试按实体 ID 隔离，顺序事件先 drain 前置事件；cleanup 只删除本测试匹配记录。
- 断言保留在测试体中，测试自清理、唯一数据、单文件 <300 行、单用例目标 <90 秒。

## Appendix B: Knowledge Base References

- `risk-governance.md`, `probability-impact.md`, `test-levels-framework.md`, `test-priorities-matrix.md`
- `nfr-criteria.md`, `test-quality.md`, `contract-testing.md`, `recurse.md`
- `webhook-testing-fundamentals.md`, `webhook-waiting-querying.md`, `webhook-risk-guidance.md`
