---
workflowStatus: 'completed'
totalSteps: 5
stepsCompleted: ['step-01-detect-mode', 'step-02-load-context', 'step-03-risk-and-testability', 'step-04-coverage-plan', 'step-05-generate-output']
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-07-14'
inputDocuments:
  - _bmad/tea/config.yaml
  - _bmad-output/planning-artifacts/prds/prd-ai-video-2026-07-13/AI漫剧创作平台-完整PRD.md
  - _bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/系统架构说明.md
  - _bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/技术基线锁定.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/implementation-readiness-report-2026-07-14.md
  - _bmad-output/planning-artifacts/ux-designs/ux-ai-video-2026-07-13/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-ai-video-2026-07-13/EXPERIENCE.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/adr-quality-readiness-checklist.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/nfr-criteria.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/test-levels-framework.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/risk-governance.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/probability-impact.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/test-priorities-matrix.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/test-quality.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/contract-testing.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/recurse.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-testing-fundamentals.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-waiting-querying.md
  - .agents/skills/bmad-testarch-test-design/resources/knowledge/webhook-risk-guidance.md
---

# Test Design Progress

## Mode Detection

- **Mode:** System-Level
- **Reason:** PRD、架构/ADR、Epic/Stories 均已存在；按技能优先级先建立系统级风险与测试架构，再把高风险链路映射到 Epic/Story。
- **Required inputs:** 已满足。
  - PRD：最终合并版，含 FR1～FR25、NFR1～NFR16、QG1～QG6。
  - Architecture/ADR：ARCHITECTURE-SPINE 及 companion。
  - Epics/Stories：6 Epic、30 Story、85 组 BDD AC。
- **User focus:** 异步生成、供应商故障、成本与合规链路。
- **Readiness constraint:** 仅可进入 Sprint 0 风险消减；Correct Course 已消除 Story 前向依赖，功能实施仍受全栈 P0 基线与 R-001～R-004 证据阻断。

## Loaded Context

### Configuration

- Playwright utils: enabled；Pact.js utils: disabled；Pact MCP: none。
- Browser automation: auto；当前无可运行站点或 UI 测试，跳过浏览器探索。
- Test stack detection: 仓库未发现 `go.mod`、`package.json` 或测试配置；当前为规划阶段。目标架构是 Go 微服务 + React 全栈，但不能视为已物化能力。

### Technology and Integration Boundaries

- Go 1.25/ag-core 独立模块服务、React 19/Vite、Temporal、Kafka KRaft、MySQL 8.4、Nacos、Redis、S3 兼容对象存储、FFmpeg、Kubernetes、OpenTelemetry。
- 外部边界：OIDC IdP、模型供应商提交/轮询/回调/计费/删除、对象存储、内部通知与未来外部渠道。
- 关键一致性：Saga + Outbox/Inbox、WorkflowInbox/Signal bridge、三态供应商提交、预算 Reservation/Authorization/Receipt、不可变 Asset/Manifest/Release、QG 证据。

### NFR Thresholds

- 控制面月可用性 99.5%；非生成 Web p95 ≤2 秒；业务元数据 RPO ≤5 分钟、RTO ≤2 小时。
- 敏感原始素材删除 ≤30 天；内部审计 ≥180 天。
- 预算 70%/90% 提醒、100% 停止新增付费；未经授权越界率 0。
- 内部正式镜头动态覆盖 100%；故事/视听相关目标 95%；局部问题不全片重做 ≥90%；系统无效重生成成本 ≤2%。

### Missing Thresholds / Evidence Questions

- Seedance/备用供应商单价、失败扣费、并发、QPS、队列、回调签名、取消、幂等、最大任务时长、数据保留和删除 SLA 未锁定。
- 自动恢复最大尝试数、退避、熔断阈值和人工接管响应目标未量化。
- 事件端到端传播、体验投影陈旧度、SSE 恢复、对象转存与对账时限未量化。
- 外部商业化的端到端 SLO、投诉/申诉/紧急下架 SLA 尚未确定。
- 精确技术版本/digest、兼容矩阵、测试框架和仿真器尚未物化。

### Knowledge Application

- 风险使用 Probability 1–3 × Impact 1–3；分数 ≥6 必须有 owner/mitigation，分数 9 阻断 Gate。
- 业务规则优先 unit/property/state-machine；事务和服务边界用 integration/contract；关键用户与合规旅程才用 E2E。
- 异步测试禁止硬等待，以实体 ID/attempt ID 隔离的轮询、事件 journal、drain pattern 和富超时诊断验证 eventual consistency。
- 微服务契约需兼容性与消费者/提供者验证；Pact.js utils 当前禁用，首期可使用 Proto golden/breaking test 与自建 contract harness，后续再决定 Pact。

## Testability and Risk Assessment

### 🚨 Testability Concerns

1. **没有可运行的测试栈。** 当前仓库只有规划文档，无法执行 unit/integration/E2E、故障注入或 NFR 证据采集。
2. **没有供应商仿真器。** 必须可脚本化返回 `NOT_ACCEPTED/ACCEPTED/UNKNOWN`、延迟/乱序/重复回调、临时 URL 过期、错误计费、删除超时、配额和限流。
3. **没有确定性时钟与调度控制。** Quote/Authorization 过期、退避、重试、Temporal timer、预算阈值和 30 天删除不能依赖真实等待。
4. **没有跨域状态探针。** 测试需要按 workspace/project/workflow/logical_task/attempt/event/manifest/trace 查询事实、Inbox/Outbox、账本和采用状态，而不是直接篡改生产表。
5. **缺少合成测试数据与清理协议。** 需提供不含真实人脸/声音的授权材料夹具、敏感/非敏感分类、不同授权状态、并行 worker 隔离和自动 teardown。
6. **供应商与异步阈值仍 UNKNOWN。** 最大尝试、退避/熔断、callback/reconcile/transfer SLA、投影陈旧度与人工接管目标未量化，相关 Gate 暂不能 PASS。
7. **缺少契约样例与错误向量。** Proto 有规则但尚无 producer/consumer golden vectors、未知 enum、重复/乱序事件、签名回调和破坏升级样例。
8. **没有媒体金样与质量 oracle。** QG-4/QG-5/QG-6 需要短小合法的动态/静态/损坏/错帧/字幕错位/标识丢失素材及确定性 FFprobe/FFmpeg 断言。

### ✅ Testability Assessment Summary

- 事实 owner、状态机、Manifest/digest、Attempt/Reservation/Receipt 和 Release 边界明确，适合建立状态模型与属性测试。
- Outbox/Inbox、WorkflowInbox、dedupe key、三态提交和不可变记录提供可验证的不变量，而不是依赖日志猜测结果。
- 架构规定 trace/correlation、任务成本/失败/质量字段、体验投影水位和 staleness reason，观测面设计充分。
- fail-closed、有限重试、暂停语义、平台承担异常差额、QG 覆盖权限和删除 Saga 都给出了明确负向测试目标。
- RPO/RTO、可用性、Web p95、删除/审计期限、预算/质量/成本指标具备部分可量化门槛。

### Architecturally Significant Requirements

| ASR | Classification | Required evidence |
|---|---|---|
| 单一事实 owner + Saga/Outbox/Inbox | ACTIONABLE | 重复/乱序/丢失注入下状态收敛与无双写 |
| Temporal 唯一推进 + WorkflowInbox | ACTIONABLE | bridge 重启、Signal 重复、Kafka 重放下只推进一次 |
| 预算零越界与整数 Money | ACTIONABLE | 并发属性测试、账本模型比对、溢出/舍入/过期/补偿 |
| 供应商三态提交 | ACTIONABLE | UNKNOWN 不重放、NOT_ACCEPTED 才回退、ACCEPTED 可对账 |
| Artifact/Manifest/Adoption 不可变 | ACTIONABLE | expected-version 冲突全拒绝、stale 传播、撤销追加 |
| QG1～QG6 证据与权限 | ACTIONABLE | digest 变化失效、AI Finding 人工复核、不可覆盖项 |
| 敏感数据供应商准入与删除 | ACTIONABLE | policy matrix、禁止发送、30 天计时、供应商回执/异常 |
| Release/Export 分离 | ACTIONABLE | attestation 一致性、过期、导出不修改 Release |
| Proto 兼容窗口与 unknown fail-closed | ACTIONABLE | breaking/golden/old-new version matrix |
| 控制面 99.5%、Web p95≤2s | FYI target / ACTIONABLE evidence | k6/SLI 报告与故障排除口径 |
| RPO≤5m、RTO≤2h | FYI target / ACTIONABLE evidence | 备份恢复与滚动回滚演练 |

### Risk Register

| ID | Category | Risk | P | I | Score | Priority | Mitigation / Evidence | Owner | Timeline |
|---|---|---|---:|---:|---:|---|---|---|---|
| R-001 | TECH | 全栈版本/digest 未锁定导致环境不可恢复或工具链漂移 | 3 | 3 | 9 | P0 BLOCK | Sprint 0 技术矩阵、干净构建、升级/回滚/恢复 smoke | Platform/Architecture | Sprint 0 |
| R-002 | DATA | 并发预留与结算竞态造成预算越界、重复扣费或错误释放 | 3 | 3 | 9 | P0 BLOCK | model-based/property tests + MySQL 并发集成 + ledger oracle | Budget team | Story 1.6 前 |
| R-003 | TECH | Kafka/Signal/重启造成工作流重复推进或事实分叉 | 3 | 3 | 9 | P0 BLOCK | duplicate/reorder/crash-point fault matrix；每个 key 仅推进一次 | Workflow team | Sprint 0/1 |
| R-004 | OPS | `UNKNOWN` 被盲目重放导致重复供应商任务与费用 | 3 | 3 | 9 | P0 BLOCK | provider simulator；提交点断网；对账后单一 Attempt 结果 | Model Gateway | Story 1.6 前 |
| R-005 | SEC | 敏感人脸/声音发送给不合格供应商 | 2 | 3 | 6 | P1 | policy decision table、egress spy、负向合同测试 | Security/Model | Story 3.1 前 |
| R-006 | BUS | 故障回退静默降级为静态/低质量镜头 | 2 | 3 | 6 | P1 | capability contract + QG4 金样 + UI 可见暂停 | Model/Quality | Story 3.5 前 |
| R-007 | DATA | 多资产采用部分成功或 stale 证据被复用 | 2 | 3 | 6 | P1 | 并发 CAS、原子 AdoptionManifest、digest mutation tests | Asset/Quality | Epic 2 |
| R-008 | SEC | 伪造、重复、乱序回调推进任务或跨 workspace 污染 | 2 | 3 | 6 | P1 | 签名/nonce/时窗/ID scope、replay tests、parallel journal isolation | Model/Security | Sprint 0/1 |
| R-009 | BUS | 异常结算超额转嫁用户或对账长期占用预算 | 2 | 3 | 6 | P1 | excess-cost oracle、reconcile SLA/aging、平台差额科目 | Budget/Ops | Story 3.6 |
| R-010 | SEC | 权利声明或 AI 标识缺失仍可导出 | 2 | 3 | 6 | P1 | QG6 negative matrix、转码前后 metadata/visible-mark golden | Delivery/Legal | Epic 5 |
| R-011 | DATA | 删除只删本地指针，供应商或对象副本残留 | 2 | 3 | 6 | P1 | virtual 30-day clock、Saga fault matrix、receipt/hold tests | Security/Asset/Model | Epic 5 |
| R-012 | PERF | 体验投影陈旧或控制面延迟导致误导性预算/状态 | 2 | 2 | 4 | P2 | k6 read/write split、watermark/staleness assertions、SSE reconnect | Experience/Web | Epic 3 |
| R-013 | OPS | 备份存在但恢复失败，无法满足 RPO/RTO | 2 | 3 | 6 | P1 | PITR/Temporal/Kafka/object-store restore drill | SRE | internal-prod 前 |
| R-014 | TECH | Proto/事件破坏升级导致混合版本不可工作 | 2 | 2 | 4 | P2 | breaking check、golden vectors、N/N-1/N+1 matrix | Contract owners | 每次契约变更 |
| R-015 | DATA | 失败/放弃项目被排除使成本和完成率失真 | 2 | 3 | 6 | P1 | cohort property tests、五终态分母 reconciliation | Analytics/Product | Story 5.5 |
| R-016 | BUS | AI 语义评分直接成为阻断或错误覆盖权限 | 2 | 3 | 6 | P1 | role/permission decision table、human-review required property | Quality | Epic 2/5 |
| R-017 | SEC | workspace 推导或缓存复用错误造成跨租户素材泄露 | 2 | 3 | 6 | P1 | authorization matrix、cross-workspace checksum/cached-result negative tests | All services/Security | Sprint 1 |
| R-018 | TECH | 异步测试使用硬等待和共享 journal，导致假绿/随机失败 | 3 | 2 | 6 | P1 | virtual clock、ID-scoped probes、drain pattern、parallel burn-in | Test Architecture | Sprint 0 |

### NFR Planning Assessment

| NFR Area | Threshold | Planned evidence | Status now |
|---|---|---|---|
| Security/Auth | OIDC、资源级授权、密钥不泄露 | auth matrix、secret scan、cross-workspace API tests | Planned; IdP 未选 |
| Sensitive data/compliance | 合格供应商；本地敏感原件≤30天删除 | policy tests、egress spy、virtual clock、delete receipts | Planned; supplier terms UNKNOWN |
| Reliability | 控制面月 99.5%；有限恢复 | SLI replay、chaos/fault matrix、workflow history assertions | Planned; thresholds partially UNKNOWN |
| DR | RPO≤5m、RTO≤2h | PITR/restore/rollback drill artifacts | Planned; stack not locked |
| Performance | 非生成 Web p95≤2s | k6 API/BFF/projection tests，供应商等待排除 | Planned; workload model UNKNOWN |
| Cost integrity | 未授权越界率0；无效重生成≤2% | ledger model tests、cohort reports、replay tests | Planned |
| Quality | 动态100%；故事/视听95%；局部重做≥90% | media golden corpus、QG evidence replay、human-review samples | Planned; evaluator calibration needed |
| Accessibility | WCAG 2.1 AA 核心 | axe/component/keyboard/reduced-motion E2E | Planned; Web not materialized |
| Maintainability | 独立模块、兼容演进、测试门禁 | independent builds、breaking checks、coverage/flake reports | Planned; exact coverage threshold UNKNOWN |
| Observability | task/provider/config/cost/failure/quality 可追踪 | trace continuity, structured log/metric schema tests | Planned |

### Highest-Risk Summary

Gate 当前为 **FAIL**：R-001～R-004 均为 9 分阻断风险。Sprint 0 必须先物化可恢复技术基线、供应商仿真器、确定性时间/事件探针和预算/工作流 model-based harness。高风险合规、质量与 DR 项必须在其首个消费 Story 前具有 owner、自动化证据路径与不可过期的放行 Gate。

## Coverage Plan and Execution Strategy

### Coverage Matrix

| Scenario ID | Requirement/Risk | Atomic scenario | Level / Tool | Priority | Evidence |
|---|---|---|---|---|---|
| BASE-001 | R-001 / Arch P0 | 从 immutable ref 在干净容器重建 ag-core 工具，build metadata 无 GitLab | CI/static | P0 | build log、binary metadata、SHA |
| BASE-002 | R-001 | 锁定栈的 Compose/K8s smoke、升级/回滚最小矩阵 | Integration/CI | P0 | digest manifest、smoke/rollback report |
| ASY-001 | AD2/AD3/R-003 | Workflow 状态机对每个合法/非法事件保持单调且确定 | Unit/model/property | P0 | state transition/property report |
| ASY-002 | AD2/AD4/R-003 | 重复、乱序 Kafka 事件与 Signal 只推进一次 | Integration/Temporal+Kafka harness | P0 | inbox/outbox/workflow history diff |
| ASY-003 | NFR1/2/R-003 | 在持久化前后各 crash point 重启，状态收敛且无重复副作用 | Integration/fault injection | P0 | crash matrix、fact snapshot |
| ASY-004 | AD28 | USER/BUDGET/BLOCKED/STALLED 暂停停止新调度但保留在途责任 | Unit + integration | P1 | schedule/attempt/ledger assertions |
| ASY-005 | AD21/31/NFR6 | 投影延迟、SSE 断线重连后快照+游标无遗漏重复，陈旧原因可见 | API/component | P1 | watermark trace、UI assertions |
| ASY-006 | R-018 | 4+ parallel workers 使用唯一 workspace/project/attempt，事件 journal 不串扰 | Integration burn-in | P1 | 50-run flake report |
| PROV-001 | AD9/R-004 | 所有提交响应/超时只归类为三态之一 | Unit decision table | P0 | exhaustive branch report |
| PROV-002 | AD9/R-004 | 提交点断网形成 UNKNOWN，重启/超时均不重放 POST，最终对账一次 | Integration/provider simulator | P0 | provider request count、Attempt history |
| PROV-003 | R-008 | 回调签名错误、过期、nonce replay、跨 workspace ID 全部拒绝 | API/security integration | P0 | auth matrix、audit log |
| PROV-004 | AD10 | 临时 URL 过期/转存失败只重试获取或转存，不重新生成 | Integration/provider+object store simulator | P1 | provider POST count=1、receipt identity |
| PROV-005 | AD26/R-006 | fallback 仅在 NOT_ACCEPTED 且能力/质量/合规兼容时发生 | Unit contract + integration | P1 | capability decision evidence |
| PROV-006 | NFR16 | 429/5xx/慢响应触发有限重试、退避、熔断和人工接管 | Integration/virtual clock | P1 | attempt count/timer/circuit metrics |
| PROV-007 | NFR12 | 供应商删除成功/拒绝/超时/异步回执均有终态与责任 | Contract + integration | P1 | deletion receipt/aging report |
| COST-001 | AD11/R-002 | Money minor_units、币种、指数、舍入、溢出/负数决策 | Unit/property/fuzz | P0 | invariant/fuzz corpus |
| COST-002 | FR11/R-002 | N 个并发 Reservation 原子竞争，`settled+active liability≤limit` | MySQL integration/property | P0 | ledger oracle vs DB snapshot |
| COST-003 | AD11 | 单次 SpendAuthorization 重试幂等，不同绑定/nonce/过期拒绝 | Integration | P0 | immutable receipt comparison |
| COST-004 | FR11 | 70/90 各提醒一次，100 停止新付费，乱序结算不重复提醒 | Unit + event integration | P1 | event multiset assertions |
| COST-005 | FR11/R-009 | ProviderCostFact 超最大责任时用户成本封顶、差额进入平台科目 | Unit/model + integration | P0 | dual-ledger reconciliation |
| COST-006 | SM10-14 | 取消/失败/结算释放差额；成功/失败项目成本口径一致 | Integration + analytics reconciliation | P1 | reservation aging/metric report |
| COST-007 | AD20 | Quote 过期或 expected version 变化要求重新确认，旧确认不可扣费 | API integration/virtual clock | P0 | proposal/auth/attempt audit chain |
| COMP-001 | NFR9-11/R-005 | 敏感度×供应商条款×区域×训练/保留/删除矩阵 fail-closed | Unit decision table + egress spy | P0 | policy matrix、zero forbidden calls |
| COMP-002 | FR21 | 授权有效/过期/撤回/范围不足影响关联资产和 Release | Integration | P1 | rights graph/state assertions |
| COMP-003 | FR20/22/R-010 | 标识/元数据/权利/权限任一缺失都阻止导出，转码不丢标识 | Media golden + E2E | P0 | FFprobe/视觉 golden、Export absence |
| COMP-004 | NFR12/R-011 | 删除 Saga 在每个故障点可恢复，30 天内完成或显示 hold/外部责任 | Integration/virtual clock/fault matrix | P0 | tombstone/object/provider receipt chain |
| COMP-005 | NFR13 | 普通创作者无法改模型配置、审计、质量覆盖或治理案件 | API authz matrix | P0 | 401/403 + unchanged fact digest |
| COMP-006 | FR23 | 审计追加不可篡改、敏感字段最小化、跨链 trace 可重建 | Integration + security scan | P1 | audit chain/hash/PII scan |
| COMP-007 | FR24/25 | PublishedContentRecord 导入、渠道规则版本、紧急下架与恢复不改历史 | Contract + integration | P1 | case/channel/publication history |
| DATA-001 | AD7/R-007 | 多 Slot CAS 任一冲突全拒绝；撤销追加且不半更新 | MySQL integration/concurrency | P0 | slot vector before/after |
| DATA-002 | AD12/22 | 任一输入/规则/tool digest 变化使 QualityRun stale 并传播最小范围 | Unit graph/property + integration | P1 | dependency graph oracle |
| QUAL-001 | AD29/R-016 | QG1～QG6 warning/blocker 角色权限穷举，AI Finding 未复核不能阻断 | Unit decision table + API | P0 | exhaustive permission matrix |
| QUAL-002 | QG4-6 | 动态/静态/损坏/音画错位/字幕语义/标识金样分类稳定 | Media integration + human calibration | P1 | golden corpus report、review agreement |
| MET-001 | SM1-15/R-015 | 五终态全入分母、复杂度 Snapshot 不回写、样本不足5不冻结 | Unit/property + analytics integration | P1 | cohort/metric oracle |
| E2E-001 | UJ1/FR1-4 | 创建项目→简报 Gate→付费授权→样片候选→采用 | API-first E2E + minimal UI | P0 | trace/ledger/asset/UX assertions |
| E2E-002 | FR13/16 | 供应商故障→自动有限恢复→解释性暂停→安全继续/停止 | API-first E2E/provider simulator | P0 | end-to-end state/charge proof |
| E2E-003 | FR14/17/18 | 局部反馈→影响/报价→候选→A/B→原子采用/撤销 | E2E | P1 | unchanged unrelated digests |
| E2E-004 | FR19-23 | QG/权利/成本→Release→受控 Export；任一阻断失败关闭 | E2E + media evidence | P0 | Release/Export manifest chain |
| NFR-DR-001 | R-013 | MySQL PITR、Temporal/Kafka/object restore 满足 RPO/RTO | Weekly DR drill | P1 | timed restore report |
| NFR-PERF-001 | NFR4-6 | 代表性控制面负载下 p95≤2s、错误率/可用性口径正确 | k6 + SLI queries | P1 | k6 JSON、dashboard snapshot |
| NFR-A11Y-001 | NFR7 | Gate/预算/阻断/播放器键盘、对比度、axe、reduced-motion | Component + Playwright E2E | P1 | axe/keyboard/video report |

### NFR Coverage and Evidence Plan

- **Security/compliance:** API authz decision tables、egress spy、secret/PII scan、signed callback tests；证据为矩阵、扫描报告、审计链。供应商条款仍 UNKNOWN，是接入真实敏感素材的 blocker。
- **Reliability/DR:** Temporal/Kafka/MySQL/object-store fault matrix、PITR 与回滚演练；证据为工作流历史、事实快照、RPO/RTO 计时报告。精确栈未锁是 blocker。
- **Performance/scalability:** k6 对 BFF/领域命令/体验投影分别施压；生成供应商等待不计控制面 SLI；证据为负载模型、p50/p95/p99、错误率和资源曲线。代表性并发仍 UNKNOWN。
- **Maintainability/compatibility:** 独立模块构建、Proto breaking/golden、N/N-1、生成代码无手改、测试 flake/coverage；证据为 CI artifacts。纯领域逻辑 branch coverage 目标 ≥80%，预算/状态机关键分支 100%。
- **Accessibility:** axe + component + 少量关键 E2E；证据为无障碍报告和键盘录制。
- **Business quality/cost:** media golden、human calibration、ledger/cohort oracle；证据为 QG 运行、复核一致性与统计 reconciliation。

### Execution Strategy

- **PR (<15 min):** P0/P1 unit/property、Proto breaking/golden、静态/secret scan、选定 API contract、短 MySQL/Temporal integration；真实供应商调用为 0。
- **Nightly:** 全 integration、4-worker burn-in、provider/object-store fault matrix、媒体金样、关键 E2E、短时 k6 与 accessibility。
- **Weekly / release candidate:** DR/PITR、滚动升级/回滚、长时并发/chaos/endurance、供应商 sandbox 合同、完整 QG/Release/Export 与删除演练。
- 测试按 `workspace_id + project_id + attempt_id` 隔离，使用虚拟时间、ID-scoped event probes 和自动清理；禁止硬等待和全局 journal reset。

### Resource Estimates

- P0 coverage and harness: **约 120–190 小时**
- P1 core resilience/compliance/NFR: **约 150–240 小时**
- P2 secondary UI/observability/analytics: **约 60–110 小时**
- P3 exploratory/benchmark polish: **约 20–40 小时**
- Total initial automation: **约 350–580 小时**；建议 2–4 名具备 Go/Temporal/测试架构能力的工程师跨 6–10 周随 Epic 增量交付，而非在 Sprint 0 一次完成。

### Quality Gates

- P0 pass rate = **100%**；任一 R-001～R-004 开放即 FAIL。
- P1 pass rate ≥ **95%**，且所有 score≥6 风险有 owner、mitigation、deadline 和可复现证据；无无限期 waiver。
- 25 FR 与 16 NFR 均映射到 Story/风险/测试级别；P0/P1 AC coverage = 100%，总体自动化需求覆盖 ≥80%。
- 领域纯逻辑 branch coverage ≥80%；预算不变量、三态提交、Gate/QG 权限和状态机合法转移分支 = 100%。生成代码和基础库 wrapper 不以行覆盖率代替契约/集成证据。
- flake gate：P0/P1 并行 burn-in 50 次无随机失败；禁止硬等待。
- 每个 NFR 类别必须有预期 evidence artifact；最终 PASS/CONCERNS/FAIL 推迟到实现后 `nfr-assess`。
- 真实供应商敏感数据、internal-prod 与外部发布分别设独立 Gate，不能用模拟器通过替代供应商合同/法务/恢复证据。

## Completion Report

- **Mode:** System-Level；执行模式从 auto 解析为并行，架构文档并行成功，QA 分支超时后按确定性 fallback 切换 sequential 完成。
- **Outputs:**
  - `_bmad-output/test-artifacts/test-design-architecture.md`
  - `_bmad-output/test-artifacts/test-design-qa.md`
  - `_bmad-output/test-artifacts/test-design/ai-video-handoff.md`
- **Validation:** 三份文件均覆盖 R-001～R-018；架构文档 196 行、QA 文档 214 行、handoff 125 行；无未替换模板占位符。
- **Gate:** 当前 FAIL；R-001～R-004 必须在 Sprint 0 关闭，P0=100%、P1≥95%、总体需求自动化覆盖≥80%。
- **Open assumptions:** 供应商 SLA/计费/删除、重试/熔断阈值、代表性负载、投影陈旧度与外部治理 SLA 仍 UNKNOWN。
