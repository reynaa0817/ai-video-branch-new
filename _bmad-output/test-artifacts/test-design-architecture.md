---
workflowStatus: 'complete'
totalSteps: 5
stepsCompleted:
  - step-01-detect-mode
  - step-02-load-context
  - step-03-risk-and-testability
  - step-04-coverage-plan
  - step-05-generate-output
lastStep: 'step-05-generate-output'
nextStep: ''
lastSaved: '2026-07-14'
workflowType: 'testarch-test-design'
mode: 'system-level'
title: 'AI 漫剧创作平台架构测试设计'
date: '2026-07-14'
author: 'Codex'
status: 'Architecture Review Pending'
project: 'ai-video'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-ai-video-2026-07-13/AI漫剧创作平台-完整PRD.md
  - _bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/implementation-readiness-report-2026-07-14.md
  - _bmad-output/test-artifacts/test-design-progress.md
---

# AI 漫剧创作平台架构测试设计

**目的：** 明确测试开发前架构与工程团队必须提供的可测试性能力、NFR 证据接口和高风险缓解契约；本文只描述 WHAT/WHY，场景、工具与执行方法见 `test-design-qa.md`。

**日期：** 2026-07-14  
**作者：** Codex  
**状态：** Architecture Review Pending  
**PRD：** `_bmad-output/planning-artifacts/prds/prd-ai-video-2026-07-13/AI漫剧创作平台-完整PRD.md`  
**架构：** `_bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/ARCHITECTURE-SPINE.md`

---

## 执行摘要

**范围：** 从 idea、样片到内部验证版本的异步生产、供应商故障恢复、预算责任、质量门、敏感数据和受控导出；覆盖 25 FR、16 NFR、6 个 Epic/31 个 Story。

**业务背景：** 平台必须在不牺牲故事完整性、完整动态质量和用户预算上限的前提下自动推进；MVP 只允许受控内部导出，外部商业化需另行关闭供应商、法务和渠道阻断项。

**架构决策：** 业务事实限界上下文微服务；Temporal 唯一推进长流程；Saga + Outbox/Inbox 保证跨域收敛；供应商提交采用 `NOT_ACCEPTED/ACCEPTED/UNKNOWN` 三态；预算采用 Reservation/Authorization/Receipt；Artifact、Manifest、Quality Evidence 和 Release 追加写且显式采用。

**已确认门槛：** 控制面月可用性 99.5%，非生成 Web p95 ≤2 秒，业务元数据 RPO ≤5 分钟/RTO ≤2 小时，敏感原始素材 ≤30 天删除，预算 70%/90% 提醒与 100% 停止新增付费，未经授权越界率 0。

**风险摘要：** 共 18 项：16 项高风险（≥6）、2 项中风险、0 项低风险；R-001～R-004 均为 9 分阻断项。当前结论是 **仅可进入 Sprint 0 风险消减，不可直接进入功能 Story 实施**。

## 快速决策指南

### 🚨 阻断项——实施前必须决定并交付

1. **B-001 / R-001：可恢复技术基线**——锁定 Temporal、Kafka/agsarama、MySQL、Nacos/Redis、对象存储、FFmpeg、Node/Web 与 Kubernetes 的版本/digest、兼容和回滚契约。（Platform/Architecture，Sprint 0）
2. **B-002 / R-003、R-018：确定性异步控制面**——提供可控时钟、按 ID 查询的事件/事实探针、去重历史与故障点控制。（Workflow/Platform，Sprint 0）
3. **B-003 / R-004、R-008：供应商仿真与契约边界**——覆盖三态提交、重复/乱序/签名回调、临时 URL、限流、计费和删除结果。（Model Gateway/Security，Sprint 0）
4. **B-004 / R-002：预算账本可验证边界**——提供整数 Money、原子预留、最大责任、结算与补偿的不可变事实及一致快照。（Budget，Story 1.6 前）
5. **B-005 / R-005、R-011：合规准入与删除责任**——锁定敏感度策略、供应商条款、外发审计、删除回执和异常责任模型。（Security/Legal/Model，真实敏感素材接入前）
6. **B-006：Story 顺序 Gate**——Story 3.1 先交付最小模型/价格/配额/供应商资格快照，再由 Story 3.2 验收正式生产计划。（Product/Architecture，Epic 3）

### ⚠️ 高优先级——团队需批准

1. **恢复策略：** 有限尝试后必须进入可解释暂停或人工接管，阈值未量化前不得形成放行结论。（Architecture/Ops）
2. **质量与降级：** 回退只能在能力、预算、质量和合规均兼容时发生，禁止静默降级成静态或低质量镜头。（Model/Quality/Product）
3. **成本责任：** 供应商异常超额进入平台差额科目，不得追溯转嫁用户；长期对账占用需有 aging 责任。（Budget/Finance/Ops）
4. **外部发布：** Seedance 商用、价格、容量、保留删除与渠道规则仍 UNKNOWN，只允许内部受控验证。（Legal/Security/Product）

### 📋 信息项——无需架构决策

1. QA 场景优先级、层级、数据和执行节奏统一收录于 `test-design-qa.md`，本文不重复。
2. 现有事实 owner、不可变 Manifest、Attempt/Reservation/Receipt、trace/correlation 和投影水位为自动化证据提供了良好边界。
3. 最终 NFR PASS/CONCERNS/FAIL 必须等待实现证据，并由后续 `nfr-assess` 给出。

## 风险评估

**共 18 项：16 项高风险、2 项中风险、0 项低风险。** 概率与影响均取 1～3，分数 = P×I。

### 高风险（分数 ≥6）

| ID | 类别 | 风险 | P | I | 分数 | 缓解方向 | Owner | 时限 |
|---|---|---|---:|---:|---:|---|---|---|
| **R-001** | TECH | 全栈版本/digest 未锁定，环境不可恢复 | 3 | 3 | **9** | 不可变基线、兼容/回滚证据 | Platform/Architecture | Sprint 0 |
| **R-002** | DATA | 并发预留/结算造成越界或重复扣费 | 3 | 3 | **9** | 原子账本、不变量和一致快照 | Budget | Story 1.6 前 |
| **R-003** | TECH | Kafka/Signal/重启造成重复推进或事实分叉 | 3 | 3 | **9** | 单一 ingress、事务去重、推进历史 | Workflow | Sprint 0/1 |
| **R-004** | OPS | `UNKNOWN` 被盲重放造成重复任务与费用 | 3 | 3 | **9** | 三态持久化、只对账不重提 | Model Gateway | Story 1.6 前 |
| **R-005** | SEC | 敏感人脸/声音发送给不合格供应商 | 2 | 3 | **6** | fail-closed 准入与外发审计 | Security/Model | Story 3.1 前 |
| **R-006** | BUS | 故障回退静默降级为静态/低质量镜头 | 2 | 3 | **6** | 能力契约、质量门、可见暂停 | Model/Quality | Story 3.5 前 |
| **R-007** | DATA | 多资产采用部分成功或复用 stale 证据 | 2 | 3 | **6** | 原子 CAS、digest 失效传播 | Asset/Quality | Epic 2 |
| **R-008** | SEC | 伪造/重复/乱序回调推进或跨 workspace 污染 | 2 | 3 | **6** | 签名、nonce、时窗与租户作用域 | Model/Security | Sprint 0/1 |
| **R-009** | BUS | 异常超额转嫁用户或对账长期占用预算 | 2 | 3 | **6** | 用户封顶、平台差额、aging | Budget/Ops | Story 3.6 |
| **R-010** | SEC | 权利声明或 AI 标识缺失仍可导出 | 2 | 3 | **6** | QG6 fail-closed 与转码后证明 | Delivery/Legal | Epic 5 |
| **R-011** | DATA | 删除只清本地指针，外部/对象副本残留 | 2 | 3 | **6** | 删除 Saga、回执、hold 责任 | Security/Asset/Model | Epic 5 |
| **R-013** | OPS | 备份存在但无法满足 RPO/RTO | 2 | 3 | **6** | 可恢复拓扑与计时恢复证据 | SRE | internal-prod 前 |
| **R-015** | DATA | 排除失败/放弃项目导致指标失真 | 2 | 3 | **6** | 五终态强制归档与统一分母 | Analytics/Product | Story 5.5 |
| **R-016** | BUS | AI 语义评分直接阻断或错误覆盖权限 | 2 | 3 | **6** | 人工复核和角色权限事实 | Quality | Epic 2/5 |
| **R-017** | SEC | workspace 推导/缓存复用造成跨租户泄露 | 2 | 3 | **6** | 服务端租户推导与缓存隔离 | All services/Security | Sprint 1 |
| **R-018** | TECH | 硬等待和共享 journal 导致假绿/随机失败 | 3 | 2 | **6** | 虚拟时钟、ID 作用域探针 | Platform/Architecture | Sprint 0 |

### 中风险（分数 3～5）

| ID | 类别 | 风险 | P | I | 分数 | 缓解方向 | Owner |
|---|---|---|---:|---:|---:|---|---|
| R-012 | PERF | 投影陈旧或控制面延迟误导预算/状态 | 2 | 2 | 4 | watermark、陈旧原因和恢复游标 | Experience/Web |
| R-014 | TECH | Proto/事件破坏升级导致混合版本失败 | 2 | 2 | 4 | 兼容窗口、unknown fail-closed | Contract owners |

**类别：** TECH 技术/架构；SEC 安全；PERF 性能；DATA 数据完整性；BUS 业务影响；OPS 运维。

## NFR 可测试性要求

| NFR | 门槛/要求 | 当前支持 | 架构缺口/决定 | 后续证据 |
|---|---|---|---|---|
| 安全/合规 | 资源授权；敏感素材仅发合格供应商；≤30 天删除 | 部分 | IdP、供应商条款、删除 SLA/回执语义未锁 | 授权矩阵、外发审计、删除责任链 |
| 性能 | 非生成 Web p95 ≤2 秒 | 部分 | 代表性并发、投影陈旧度和事件传播阈值 UNKNOWN | 负载与 SLI 报告 |
| 可靠性/DR | 控制面 99.5%；RPO ≤5m、RTO ≤2h | 部分 | 重试/退避/熔断/接管阈值与恢复拓扑未锁 | 故障矩阵、恢复计时报告 |
| 成本完整性 | 未授权越界率 0；无效重生成成本 ≤2% | 设计支持 | 供应商价格、失败扣费和对账时限 UNKNOWN | 账本/供应商成本对账 |
| 质量 | 动态覆盖 100%；故事/视听 95%；局部重做 ≥90% | 部分 | 媒体金样与评估者校准未物化 | QG evidence 与复核一致性 |
| 可维护/可观测 | 独立构建、兼容演进、任务全链可追踪 | 部分 | 技术栈、契约向量和覆盖目标未锁全 | 构建、兼容、trace/flake 报告 |

**UNKNOWN 处理：** 所有缺失阈值保持 UNKNOWN，并作为阻断或风险跟踪；不得以猜测值替代。最终 NFR 状态不在本文判定。

## 可测试性缺口

### 🚨 快速反馈阻断

| 缺口 | 影响 | 架构必须提供 | Owner | 时限 |
|---|---|---|---|---|
| 无可运行测试栈 | 无法产出任何实现证据 | 可恢复全栈基线与独立构建边界 | Platform | Sprint 0 |
| 无供应商仿真边界 | 三态、回调、计费、删除无法确定复现 | 可脚本化 Provider contract port | Model Gateway | Sprint 0 |
| 无确定性时间/故障控制 | 重试、过期、30 天删除不可快速证明 | 注入式时钟、timer/故障点控制 | Workflow/Platform | Sprint 0 |
| 无跨域只读探针 | 只能读日志或改生产表判断结果 | 按租户/项目/attempt/event/manifest/trace 查询事实 | Domain owners | Sprint 0/1 |
| 无合法金样与清理协议 | 合规、媒体质量、并行隔离不可证明 | 合成数据分类、授权事实、隔离与生命周期契约 | Security/Asset | Sprint 0/1 |
| 无契约错误向量/媒体 oracle | 兼容和 QG 结果不可稳定复核 | golden vectors、损坏/错帧/错位/标识素材 | Contract/Quality | 首个消费者前 |

### 必要架构改进

1. **统一证据关联键：** 生产事实和观测必须贯通 `workspace/project/workflow/logical_task/attempt/event/manifest/trace`；否则无法证明跨域收敛。Owner：Architecture；Sprint 0/1。
2. **显式故障终态：** 重试耗尽、对账超时、删除失败和恢复失败必须形成可查询终态、责任 owner 与用户可见原因；否则故障会长期悬空。Owner：Workflow/Ops；首个相关 Story 前。
3. **Gate 输入不可变：** QG、Release、Export 必须绑定输入与规则 digest，变更即失效；否则 stale 证据可能放行。Owner：Quality/Delivery；Epic 2/5。

## 高风险缓解计划

以下 16 项必须在对应里程碑前完成架构/生产能力缓解；QA 验证方法见 companion 文档。

| 风险 | 缓解策略（按顺序） | Owner / 时限 | 状态 | 验证结果要求 |
|---|---|---|---|---|
| R-001 | 1. 锁 ref/digest；2. 定义兼容矩阵；3. 固化升级/回滚/恢复契约 | Platform/Arch / Sprint 0 | Planned | 干净环境可重建且可回退 |
| R-002 | 1. 定义账本不变量；2. 原子预留结算；3. 暴露一致快照 | Budget / Story 1.6 前 | Planned | 并发下责任总额不越界 |
| R-003 | 1. 单一 ingress；2. 事务 Inbox 去重；3. 持久化消费游标 | Workflow / Sprint 0/1 | Planned | 重放/重启只推进一次 |
| R-004 | 1. 持久化三态；2. UNKNOWN 禁止重提；3. 对账收敛 Attempt | Model Gateway / Story 1.6 前 | Planned | 单次逻辑任务无重复供应商 POST |
| R-005 | 1. 建供应商资格事实；2. egress 前决策；3. fail-closed 审计 | Security/Model / Story 3.1 前 | Planned | 禁止组合产生零次外发 |
| R-006 | 1. 版本化能力契约；2. 回退校验质量/合规；3. 降级显式暂停 | Model/Quality / Story 3.5 前 | Planned | 不兼容回退无法推进 |
| R-007 | 1. Expected vector；2. 单事务全验全改；3. digest 变更传播 stale | Asset/Quality / Epic 2 | Planned | 冲突时零部分采用 |
| R-008 | 1. 签名/nonce/时窗；2. 服务端租户绑定；3. 回调幂等持久化 | Model/Security / Sprint 0/1 | Planned | 伪造/重放不改变事实 |
| R-009 | 1. 用户责任封顶；2. 平台差额科目；3. 对账 aging 与升级责任 | Budget/Ops / Story 3.6 | Planned | 用户账本永不吸收异常差额 |
| R-010 | 1. QG6 绑定权利/标识；2. 转码后再验证；3. Export fail-closed | Delivery/Legal / Epic 5 | Planned | 任一缺失均无 Export |
| R-011 | 1. 删除 Saga；2. 本地/对象/供应商回执；3. hold 与升级责任 | Security/Asset/Model / Epic 5 | Planned | 30 天内终态或显式 hold |
| R-013 | 1. 定义恢复拓扑；2. 锁备份一致点；3. 保留计时恢复证据 | SRE / internal-prod 前 | Planned | 实测满足 RPO/RTO |
| R-015 | 1. 强制五终态；2. 冻结 cohort 口径；3. 总体/成功样本并列 | Analytics/Product / Story 5.5 | Planned | 失败与放弃均进入分母 |
| R-016 | 1. AI Finding 非最终事实；2. 人工复核；3. 角色覆盖规则固化 | Quality / Epic 2/5 | Planned | AI 未复核不能阻断 |
| R-017 | 1. 服务端推导 workspace；2. 缓存 key 含租户；3. 跨域授权一致 | Services/Security / Sprint 1 | Planned | 跨租户读取/复用为零 |
| R-018 | 1. 注入虚拟时钟；2. ID-scoped probes；3. journal 隔离与归档 | Platform/Arch / Sprint 0 | Planned | 并行运行无共享状态干扰 |

## 可测试性现状摘要

- 事实 owner、状态机、不可变 Manifest/Attempt/Reservation/Receipt 和 Release 边界明确，适合证明业务不变量。
- Outbox/Inbox、WorkflowInbox、dedupe key 与三态提交为重复、乱序、重启下的确定性收敛提供设计基础。
- trace/correlation、成本/失败/质量字段、投影水位和 staleness reason 已进入架构契约。
- **可接受阶段性权衡：** 外部商业化 SLO、渠道和投诉下架规则可推迟到阶段 C，但不得因此允许真实敏感素材流向未批准供应商，也不得替代 internal-prod 恢复证据。

## 假设、依赖与计划风险

### 架构假设

1. Temporal 是唯一流程推进器，Kafka 仅传播已持久化事实；任何旁路推进均视为缺陷。
2. 业务元数据 RPO/RTO 覆盖 MySQL、Temporal/Kafka 恢复关系和对象引用一致性，而非仅数据库文件恢复。
3. 供应商成功不等于业务成功；只有绑定输入 digest 的质量证据通过后才能进入下游。

### 依赖

1. 全栈 P0 技术基线与 B-001～B-004 —— Sprint 0 完成，Story 1.2/1.6 前必须关闭。
2. 模型/价格/配额/资格快照 —— Story 3.1 完成并形成 Gate 后，才执行正式生产计划 Story 3.2。
3. 供应商商用、数据、删除、容量与 SLA 归档证据 —— 真实敏感素材和外部商业化前完成。
4. 媒体金样、授权数据与 QG 复核口径 —— Epic 2/5 首个消费 Story 前完成。

### 计划风险

- **风险：** 供应商生产契约继续 UNKNOWN。**影响：** 真实合同、容量、成本与删除证据无法完成。**应对：** Sprint 仅使用受控仿真边界；阻断真实敏感素材和外部发布。
- **风险：** 全栈锁定延迟。**影响：** 所有环境与 NFR 证据不可复现。**应对：** 保持功能 Story 停止，只推进文档化决策和可独立验证的领域模型。

---

**架构团队下一步：** 在 Sprint 0 指派 B-001～B-006 与所有高风险 owner/时限；关闭 R-001～R-004 后再复核功能实施就绪度。  
**QA 团队下一步：** 以同一 R-001～R-018 编号生成 `test-design-qa.md`，待阻断能力可用后实施验证；本文不自动启动 ATDD。

**文档结束**
