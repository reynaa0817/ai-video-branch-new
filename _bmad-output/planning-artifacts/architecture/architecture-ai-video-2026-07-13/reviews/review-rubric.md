---
tags:
  - ai-video
  - architecture
  - reviewer-gate
  - bmad
date: 2026-07-14
title: AI 漫剧创作平台架构 Spine Rubric 审查
---

# AI 漫剧创作平台架构 Spine Rubric 审查

## Gate Verdict

**CHANGES REQUIRED（未通过 Reviewer Gate）。** Spine 已经形成清晰的限界上下文、持久化编排、事实事件、预算预留、不可变版本、质量证据与交付快照等主干，PRD 的多数承重要求也已进入 AD-20 至 AD-31；但事实所有权仍未被唯一列举，且 AD-20 对 Attempt 的创建表述与该原则存在直接冲突。运维闭环、质量 Warning 覆盖矩阵、指标复杂度口径和派生投影所有权也仍允许下一级团队作出互不兼容的选择。

在修复 Critical 与 High 项前，不建议将 `status` 从 `draft` 改为 `final`。

## Rubric 总览

| 检查项 | 结论 | 摘要 |
| --- | --- | --- |
| 修复真实分歧点 | 部分通过 | 预算、供应商三态、采用、Gate、依赖失效、交付规格均抓到了真实分歧；事实所有权和派生投影归属仍不收敛。 |
| 每个 AD 可执行且能防止所述分歧 | 部分通过 | 多数 Rule 可转成契约测试或状态机测试；AD-1、AD-20、AD-21、AD-27、AD-29、AD-30、AD-31 仍有不可执行或不完整处。 |
| Deferred 不泄漏承重决策 | 基本通过，有保留 | 供应商、IdP、对象存储供应商均有固定边界或启用门；外部渠道治理与 FR-24/25 的绑定范围需要更清晰的阶段标识。 |
| 覆盖 PRD 能力 | 部分通过 | FR/QG/NFR/SM 均有映射；QG-1/QG-2/QG-5 覆盖权限、复杂度阈值和预算提醒等仍未形成一致契约。 |
| 平台维度均有决定或 Deferred | 未通过 | 缺发布/回滚、数据库与契约迁移、告警/值班、容量与降载、Temporal 运维基线、安全网络边界等决定或显式 Deferred。 |
| 运维环境完整 | 未通过 | 环境隔离、RPO/RTO 与部分 HA 已定义，但核心编排器 Temporal 的 HA/持久化/恢复未定义，无法证明 99.5% 控制面目标。 |
| 技术版本可验证且当前 | 待证据 | 文档给出日期和部分精确版本，但多项仍是 `x`、`兼容版本` 或 `受支持版本`；Deferred 有锁定条件，尚缺验证证据引用。 |

## Critical Findings

### C-1：事实所有权没有真正唯一化，AD-20 又让 Workflow “创建 Attempt”

**证据：**

- AD-1（spine 52–56）只列出七个服务“各自独占写模型”，没有列出 Project、Gate、Revision、Attempt、ModelTask、Reservation、Ledger、ArtifactVersion、QualityRun、ReleaseVersion、ExportRecord 等聚合分别由谁拥有。
- Capability Map（309–319）按 FR 范围把多个服务放在同一格，不能替代唯一的事实所有权表。
- AD-20（166–170）写成“Workflow 才能请求 Reservation 并创建 Attempt”；但 AD-8、AD-9、AD-11 又分别让 Model Gateway 与 Budget 管理 Attempt 相关模型和结算语义。下一级实现可能由 Workflow 落 Attempt，也可能由 Model Gateway 落 Attempt。

**为什么是承重问题：** 这会直接决定命令 API、数据库唯一约束、Outbox 事件、幂等键和补偿责任。两个 feature 团队无法从合规代码推导同一个答案。

**建议处置：autofix。** 在 AD-1 或紧随其后的约定中增加“聚合 → 唯一事实拥有服务”表；将 AD-20 改为 Workflow 请求 Budget 创建 Reservation，并命令 Model Gateway 创建 Attempt，Workflow 只保存引用。明确 `Attempt` 与 `ModelTask` 是否为同一聚合或一对多关系。

## High Findings

### H-1：Temporal 是唯一推进器，但没有 internal-prod 运维基线

**证据：** AD-2（58–62）把 Temporal 定义为唯一流程推进器，AD-30（226–230）要求控制面月可用性 99.5%；内部生产基线（303）却只明确核心 API、MySQL、Kafka、Nacos、对象存储的 HA/RPO/RTO，没有 Temporal 集群副本、持久化数据库、可见性存储、Namespace 隔离、备份恢复、升级/回滚和故障演练要求。

**为什么是承重问题：** 平台团队可能部署单节点 Temporal，也可能部署多副本；可能复用业务 MySQL，也可能独立持久化。它们都不违反当前文字，却产生完全不同的故障域和恢复能力。

**建议处置：autofix。** 增加运维 AD 或环境基线，至少固定 Temporal frontend/history/matching/worker 的 HA 目标、独立持久化边界、Namespace 隔离、备份/恢复与升级演练；若当前不决定，必须进入 Deferred 并规定 internal-prod 禁用条件。

### H-2：AD-29 声称固定质量覆盖权限，但只覆盖 QG-3、QG-4、QG-6

**证据：** AD-29（220–224）的 Prevents 是“各界面或服务自行决定谁能接受 Warning”，Rule 只规定 QG-3 创作者、QG-4 双接受、QG-6 不可覆盖。PRD 还规定 QG-1 提醒由创作者覆盖、QG-2 阻断只能修改创作宪法后重检、QG-5 提醒由创作者接受；这些没有进入统一策略。

**为什么是承重问题：** Quality、Studio、BFF 和 Delivery 会对 QG-1/QG-2/QG-5 生成不同的按钮、授权命令和放行条件，AD-14 的 Release 条件因而无法一致执行。

**建议处置：autofix。** 把 QG-1 至 QG-6 的 `severity × actor × action × recheck requirement` 完整矩阵作为 `QualityRolePolicy` 的固定 MVP 基线，所有 WarningAcceptance 与 Gate/Release 校验引用同一策略版本。

### H-3：AD-27 冻结了复杂度快照，却没有冻结 PRD 的复杂度分类算法

**证据：** AD-27（208–212）定义 `ComplexitySnapshot`、前 20 部校准和 p75 冻结，但没有带入 PRD §7.1 的简单/中等/复杂阈值：集数、总时长、主要角色数、主要场景数，以及“超过任一中等上限即复杂型”。

**为什么是承重问题：** Studio、分析投影和报表可各自计算复杂度；即便都不可变，冻结的也可能是不同分类，SM-7、SM-14、SM-15 失去共同分母。

**建议处置：autofix。** 让 `ComplexityPolicySnapshot` 固定四个输入、精确阈值、边界包含关系、缺失值处理和分类时点；`ComplexitySnapshot` 必须引用该策略版本与原始输入。

### H-4：体验读模型与通知投影没有唯一组件所有权

**证据：** AD-21（172–176）只说“事件投影生成 `ProjectExperienceView`”，AD-31（232–236）只说“Notification Projection 从领域事实构建”，Structural Seed（272–281）没有 projection/read-model 服务或明确归属，Capability Map 只写“体验读投影”。

**为什么是承重问题：** BFF、Studio、Workflow 或独立 projection worker 都可能实现并持久化这些视图。事件订阅、重建、游标、数据保留、授权过滤和部署伸缩将出现重复实现或无人负责。

**建议处置：autofix。** 指定唯一 owner 与部署单元，例如独立 `experience-projection`（只读派生，不是事实源），或明确归 BFF/Studio；同时规定其数据库、订阅 Topic、重建入口、workspace 授权过滤和 SLO 归属。

### H-5：运维与交付维度仍整块静默

**证据：** spine 定义了服务构建边界和基础设施拓扑，却没有决定或 Deferred 以下内容：镜像与配置发布/回滚、数据库迁移顺序与向后兼容窗口、Proto/Kafka 契约兼容门、Temporal Workflow 版本演进、告警与值班责任、供应商限流时的容量/背压/降载、密钥轮换、灾备演练频率。

**为什么是承重问题：** 这些不是单个 story 的实现细节，而是所有服务和环境必须共享的演进规则。独立团队会采用互不兼容的 rollout 和 migration 方式。

**建议处置：discuss 后 autofix。** 用一个精简的“演进与运维不变量”AD 固定兼容迁移、渐进发布、回滚和告警所有权；尚未选择的具体工具进入 Deferred，但必须有触发条件和 internal-prod 放行门。

## Medium Findings

### M-1：AD-2 允许领域事件或 Signal 两种唤醒路径，没有唯一桥接规则

AD-2（62）允许供应商回调持久化后“以受信事件或 Signal”唤醒 Workflow。若有的服务由 Kafka consumer 发 Signal，有的直接 Signal，重放、去重、顺序和恢复语义不同。应固定由哪个组件把哪类已持久化事实桥接为 Signal，并要求 `event_id`/业务版本作为 Workflow 去重键。

### M-2：AD-30 的 SLI 边界仍是待办句，不是可执行 Rule

“明确 SLI 边界与外部供应商排除项”没有给出控制面可用性的请求集合、成功判定、计划维护、观测窗口，也没有列出“主要 Web 交互”。99.5% 和 p95 数值因此无法生成同一验收查询。应至少定义版本化 SLI catalog 的 owner 与最低事件字段。

### M-3：预算 70%/90% 提醒没有成为事实事件或统一体验状态

AD-11 固定 100% 硬预算责任，AD-21 暴露 consumed/held/remaining，但 PRD FR-11 的 70% 与 90% 提醒没有事件、去重或重入语义。Budget、Notification Projection 与 Web 可分别计算，造成重复提醒或漏提醒。建议规定 Budget 基于 `consumed + held` 还是仅 consumed 触发，并输出单调阈值事件。

### M-4：外部治理能力的绑定范围与 Deferred 阶段边界不够精确

Frontmatter 声明绑定 FR-1..FR-25，Capability Map 也映射 FR-21..FR-25；Deferred 又把外部渠道发布与治理 SLA 留到后续。PRD 明确 FR-24/FR-25 是阶段 C 能力。建议在 `scope`/`binds` 或 Capability Map 标记“内部阶段只预留承载字段，阶段 C 才启用完整状态机”，避免 feature 团队误以为 MVP 必须实现投诉、申诉和紧急下架全流程。

### M-5：技术版本表不能单独证明“已验证当前且适配”

Stack（252–268）给出了版本日期，但 Temporal、Nacos、Redis、OpenTelemetry 和部分语言/框架仍以系列或兼容描述表示。Deferred 对 patch 锁定有合理 P0 条件，因此不是阻断；但 finalize 前应链接兼容性/故障测试证据，或明确所有未锁定项均不得进入 internal-prod。当前文档内无法验证“current”与 ag-core 适配结论。

## Low Findings

### L-1：AD-1 的 Binds 过宽

`FR-1..FR-25，全部核心服务` 不足以帮助契约测试定位影响。增加聚合所有权后，可让 Binds 指向聚合、命令与事件边界，而不是整个 PRD。

### L-2：AD-6 只列出存在多个状态机，没有定义最低非法转换原则

目前仍可由不同 feature 自行设计 Project lifecycle、Attempt、Gate、Reservation 的终态与重开语义。聚合所有权表修复后，应由各 owner 契约维护状态机，并至少固定“终态不可回退、重试新建 Attempt、批准追加写”等跨域原则。

### L-3：Deployment 图没有表现 Redis、投影存储和 Temporal 持久化

Stack 与 Consistency Conventions 提到 Redis，AD-21/31 引入投影，图中却没有对应组件；这会降低 Structural Seed 的冷启动准确性。补图即可，不需要新增 AD。

## AD 可执行性抽查

| AD | 结论 | 说明 |
| --- | --- | --- |
| AD-1 | 不通过 | 没有聚合到 owner 的唯一映射。 |
| AD-2 | 部分通过 | 唯一推进器清晰；Event/Signal 桥接仍双轨。 |
| AD-3 | 通过 | 明确 Workflow 不成为业务事实源。 |
| AD-4 | 通过 | 本地事务、Outbox/Inbox、at-least-once 可验证。 |
| AD-5 | 通过 | Proto owner、兼容演进与 Topic 规则可做 CI 门。 |
| AD-6 | 部分通过 | 分离建模正确，状态机 owner/最低转换约束不足。 |
| AD-7 | 通过 | 不可变候选与 expected version Adoption 可验证。 |
| AD-8 | 通过 | 模型出口、凭证边界与 Snapshot 明确。 |
| AD-9 | 通过 | 三态与 UNKNOWN 禁止自动重放清晰。 |
| AD-10 | 通过 | 转存、checksum、Asset 登记形成完成边界。 |
| AD-11 | 通过 | 最大责任预留、定点金额与追加账本清晰。 |
| AD-12 | 通过 | QualityRun、证据失效和人工复核边界清晰。 |
| AD-13 | 通过 | 媒体规范化、版本和跨 workspace 复用边界清晰。 |
| AD-14 | 通过 | Release/Export 分离及放行条件清晰。 |
| AD-15 | 通过 | BFF、领域授权与短期凭证边界清晰。 |
| AD-16 | 通过 | 删除 Saga 的服务责任与保全优先级清晰。 |
| AD-17 | 通过 | 只读投影、关联键与全结果分母清晰。 |
| AD-18 | 通过 | 关键依赖 fail-closed 边界清晰。 |
| AD-19 | 通过 | Go Module、CI 与 import 禁区可静态检查。 |
| AD-20 | 不通过 | “Workflow 创建 Attempt”与事实所有权未收敛。 |
| AD-21 | 部分通过 | View 契约清晰，owner/部署单元缺失。 |
| AD-22 | 通过 | DependencyManifest、stale 传播与复用条件清晰。 |
| AD-23 | 通过 | 五 Gate、Manifest、事务与 Signal 顺序清晰。 |
| AD-24 | 通过 | 单一 Profile、元数据、转码与 QG-6 引用清晰。 |
| AD-25 | 通过 | 敏感数据准入、30/180 天与例外审计清晰。 |
| AD-26 | 通过 | 能力契约和回退证据清晰。 |
| AD-27 | 部分通过 | cohort 冻结清晰，复杂度分类算法缺失。 |
| AD-28 | 通过 | 暂停分类、在途责任与恢复点清晰。 |
| AD-29 | 不通过 | 覆盖矩阵未覆盖 QG-1/QG-2/QG-5。 |
| AD-30 | 部分通过 | 数值明确，SLI 定义仍是待办句。 |
| AD-31 | 部分通过 | 去重与可重建清晰，owner/存储/授权边界缺失。 |

## Deferred 审查

- **安全 Deferred：** Seedance 参数在 P0 契约测试前禁止生产流量；精确基础设施 patch 有兼容/滚动升级/恢复测试条件；IdP 与对象存储供应商未定但协议、加密、版本、生命周期边界已定；Service Mesh/Schema Registry/分析仓库明确首版不引入。
- **需收紧：** 外部渠道治理 Deferred 应与 FR-24/FR-25 的阶段 C 启用条件显式绑定；所有“P0 锁定”项应指向可审计验证产物和 owner。
- **未发现：** Deferred 中没有允许绕过预算、质量、资产持久化、身份授权或不可变 Release 的条目。

## PRD 覆盖结论

FR-1..FR-20 的核心生产闭环已获得较好覆盖，尤其是付费授权、五类 Gate、依赖失效、供应商三态、预算最大责任、质量证据、完整动态交付规格、暂停/恢复与体验读模型。FR-21..FR-25 的内部承载与敏感数据部分也有覆盖。

仍需补齐的不是新功能清单，而是会让团队算出不同答案的共享合同：聚合所有权、完整质量覆盖矩阵、复杂度分类策略、预算提醒事件与外部治理阶段边界。

## 推荐修复顺序

1. 修复 C-1，建立唯一事实所有权表并纠正 AD-20 的 Attempt 创建责任。
2. 修复 H-1，补齐 Temporal 与 internal-prod 运维基线。
3. 修复 H-2、H-3、H-4，收敛质量策略、指标分类与投影 owner。
4. 用一个精简 AD 或明确 Deferred 补齐 H-5 的演进和运维维度。
5. 处理 Medium 项后重跑 lint 与 Reviewer Gate，再将 spine 标为 `final`。
