---
tags:
  - ai-video
  - BMAD
  - Correct-Course
  - Sprint变更
date: 2026-07-14
title: AI 漫剧创作平台 Sprint 变更提案
status: approved-applied
approved_date: 2026-07-14
change_scope: moderate
mode: batch
trigger: implementation-readiness-report-2026-07-14
---

# Sprint Change Proposal：实施前风险收敛与 Backlog 重组

## 0. 提案状态

- 当前状态：**已批准并应用**。
- 用户已于 2026-07-14 明确批准；`epics.md`、`sprint-status.yaml`、技术基线、UX、测试引用和追踪矩阵已同步更新。
- 变更分类：**Moderate**。需要 Product Owner / Developer 重组 Backlog，并由架构、测试和开发共同完成 Sprint 0 放行。
- 执行模式：Batch。

## 1. Issue Summary

### 1.1 触发问题

2026-07-14 的实施就绪度评估给出 **NOT READY** 结论。项目的产品范围、UX、架构与 25/25 FR 覆盖完整，但当前 Epic/Story 结构存在两个会阻断按序实施的问题：

1. **缺少全栈 P0 技术基线 Story。** Story 1.1 仅覆盖 ag-core 与生成工具，现 Story 1.2 却直接要求 Temporal、Kafka、MySQL、对象存储、Web lockfile、FFmpeg 与 Kubernetes 可运行；`技术基线锁定.md` 仍将这些项目标记为待锁定。
2. **Story 3.1 对未来 Story 3.2 存在前向依赖。** 正式生产计划需要版本化模型、价格、配额、最大责任和供应商资格快照，但这些事实到 Story 3.2 才建立。

### 1.2 支持证据

- `implementation-readiness-report-2026-07-14.md`：2 项 Critical、5 项 Major、3 项 Minor，最终状态为 NOT READY。
- `技术基线锁定.md`：远端 ag-core immutable ref、CI 可恢复验证、生成工具链和六类其他技术均仍有 P0 阻塞。
- `epics.md`：现 Story 3.1 明确引用 `PricingQuote`、`CostPolicy` 和最大计费责任；现 Story 3.2 才发布 `ModelProfile`、`ConfigSnapshot`、`QuotaPolicy`、`CapabilityContract` 等。
- `sprint-status.yaml`：全部 Epic/Story 仍在 backlog，没有已完成或进行中的 Story，因此可以安全重排，不需要代码或 Story 回滚。

### 1.3 问题类型

- 主要类型：实施就绪度评估发现的技术与计划依赖缺陷。
- 次要类型：Story 规模过大、测试追踪不足、UX 范围措辞歧义与阶段 C 验收输入边界缺失。

## 2. Impact Analysis

### 2.1 Epic Impact

| Epic | 影响 | 结论 |
|---|---|---|
| Epic 1 | 新增全栈 P0 技术基线 Story；现 1.2～1.6 顺延；平台骨架增加明确 Gate | 必须修改 |
| Epic 2 | 依赖 Epic 1 首个闭环，业务范围不变 | 无内容修改 |
| Epic 3 | 交换模型策略与生产计划顺序；对 3.1、3.3 增加原子任务拆分 | 必须修改 |
| Epic 4 | 依赖稳定编排和资产闭环，Story 内容不变 | 无内容修改 |
| Epic 5 | Story 5.5 增加三类实施切片 | 需要轻量修改 |
| Epic 6 | Story 6.1 增加受控 PublishedContentRecord 登记/导入边界 | 需要修改 |

Epic 1→2→3→4→5 的价值链仍成立；Epic 6 继续不反向阻塞内部 MVP。无需新增用户价值 Epic，也无需删除既有 Epic。

### 2.2 Story Impact

1. 新增 `Story 1.2：锁定全栈 P0 技术基线`。
2. 现 Story 1.2～1.6 顺延为 1.3～1.7；所有 FR 引用、状态键和文档交叉引用同步更新。
3. Epic 3 中将模型/价格/配额/合规快照前置为 Story 3.1，将生产计划调整为 Story 3.2。
4. Story 1.3、3.1、3.3、5.5 在实施 Story 文件中按风险面拆成原子任务，每项有独立输入、验收命令、恢复方式和证据。
5. Story 6.1 增加不可变外部发布记录的受控登记/导入接口，明确不实现自动公开发布。

### 2.3 Artifact Conflicts

| Artifact | 冲突/缺口 | 调整 |
|---|---|---|
| PRD | MVP 目标和 FR 完整，无范围冲突 | 不修改 |
| Epics | 缺少 P0 Story、存在前向依赖、部分 Story 过大 | 修改 Story 编号、顺序与实施拆分要求 |
| Architecture | 约束已完整，但 P0 Gate 尚未绑定独立 Story | 在 `技术基线锁定.md` 增加责任 Story 与放行规则引用 |
| UX | “账号与设置”中的“主题”可能被解释为 MVP 浅色主题 | 明确仅展示当前深色主题信息/未来入口 |
| Sprint Status | 需要新增、重命名和重排 Story 键 | 批准后原子更新 |
| Test Design / Traceability | 缺少统一 FR/NFR/AD/UX-DR → Story → 测试 → 证据矩阵 | 新增追踪矩阵并把高风险约束前置 |
| Readiness Report | 是历史评估证据 | 不回写结论；后续重新运行 readiness 生成新报告 |

### 2.4 Technical Impact

- Sprint 0 先锁定可恢复工具链、基础设施兼容矩阵、供应商沙箱合同、故障恢复与金样证据。
- Story 1.3（顺延后的平台骨架）只有在 Story 1.1 与新 Story 1.2 均通过后才能进入完整脚手架和 internal-prod 放行。
- 正式生产计划只有在版本化模型、价格、配额、成本与供应商资格快照可用后才能验收。
- 不改变七个领域事实服务、Temporal 唯一推进器、Outbox/Inbox、预算预留、显式采用和质量门等架构不变量。

### 2.5 Timeline / Effort / Risk

- 规划文档与 Backlog 调整：约 0.5～1 人日。
- Sprint 0 风险收敛：约 11～21 工程人日，取决于供应商证据、环境可用性和兼容性故障；可在 1～2 个 Sprint 内由不同责任面并行推进。
- 对功能 Story 的影响：功能开发推迟到 Sprint 0 Gate 通过之后。
- 当前变更风险：中等；主要风险是版本锁定与供应商契约证据无法按期取得。
- 不变更的风险：高；会把依赖缺陷推迟到脚手架、计费和正式生产计划阶段，以返工或预算语义错误的形式暴露。

## 3. Recommended Approach

选择 **Option 1：Direct Adjustment**，并配套 Moderate 级 Backlog 重组。

### 3.1 推荐理由

- 所有 Story 尚未开始，不存在回滚收益，Option 2 不适用。
- PRD 的 MVP 目标、FR 覆盖和用户价值链保持成立，不需要缩减或重定义 MVP，Option 3 不适用。
- 缺陷可以通过新增 P0 Story、重排 Epic 3 和拆分实施任务解决，不需要推翻架构或 UX。
- Sprint 0 会产生可复用的版本、契约、故障恢复和金样证据，降低后续 Story 的返工和验收歧义。

### 3.2 Sprint 0 建议顺序

1. Story 1.1：发布可远端恢复的 ag-core immutable ref，并重建全部生成工具。
2. 新 Story 1.2：锁定 Temporal、Kafka/agsarama、Nacos/Redis、对象存储、FFmpeg、Node/Web 与 Kubernetes 的精确版本、兼容性、恢复和回滚证据。
3. 测试框架、供应商模拟器与高风险追踪矩阵。
4. Seedance/供应商沙箱合同测试：提交三态、计费、配额、回调、取消、转存、删除与敏感数据资格。
5. 顺延后的 Story 1.3：按三个原子任务建立平台骨架，并打通最小 Quote → Reservation → Submit → Reconcile → Asset → Quality → Adoption 金样闭环。
6. Sprint 0 Gate 复核；通过后才排入功能 Story。

## 4. Detailed Change Proposals

### 4.1 Epic 1：新增全栈 P0 技术基线 Story

**Artifact:** `epics.md`  
**Section:** Epic 1 / Story 1.1 与现 Story 1.2 之间

**OLD:**

```text
Story 1.1：锁定可恢复的 ag-core 与生成工具基线
Story 1.2：建立可独立构建的最小平台骨架
```

**NEW:**

```text
Story 1.1：锁定可恢复的 ag-core 与生成工具基线
Story 1.2：锁定全栈 P0 技术基线
Story 1.3：建立可独立构建的最小平台骨架
```

**新增 Story 1.2 建议正文：**

```markdown
### Story 1.2：锁定全栈 P0 技术基线（架构 P0）

As a 平台研发与架构负责人,
I want 为运行平台所需的基础设施和工具建立可恢复、可回滚、可验证的精确基线,
So that 平台骨架、CI 和 internal-prod 不依赖猜测版本或仅在单机成立的组合。

Given Story 1.1 的远端工具链基线已通过
When 锁定 Temporal Server/SDK/schema、Kafka/agsarama、Nacos/Redis、对象存储、FFmpeg、Node/Web lockfile 与 Kubernetes 发行版
Then 每项记录精确版本或镜像 digest、许可证、兼容矩阵、配置来源和 owner
And 未锁定项保持 P0 阻塞，不得以 latest、浮动 tag 或本地缓存放行。

Given 候选技术组合已部署到干净 integration 环境
When 执行启动、契约、故障注入、升级、回滚和恢复验收
Then 保存可重复命令、金样、日志/trace、RPO/RTO 与失败证据
And Budget、对象持久化、质量门或编排不可用时验证 fail-closed。

Given Web 与媒体工具链准备放行
When 执行独立构建和金样验证
Then Node 镜像和 lockfile 可重复安装，FFmpeg 输出满足内部 DeliveryProfile、字幕、字体和 AI 标识要求
And Story 1.3 只有在本 Story 全部 Gate 通过后才能执行完整脚手架与 internal-prod 放行。
```

**Rationale:** 把架构已经声明的 P0 阻断变成可排期、可验收、可追踪的工作单元。

### 4.2 Epic 1：顺延编号并拆分平台骨架实施任务

**OLD:** Story 1.2～1.6。  
**NEW:** Story 1.3～1.7；FR1～FR4 分别改由 Story 1.4～1.7 覆盖。

顺延后的 Story 1.3 首个 Given 从：

```text
Given Story 1.1 的技术基线已通过
```

改为：

```text
Given Story 1.1 与 Story 1.2 的 P0 技术基线均已通过
```

并在实施 Story 文件中固定三个有序任务：

1. 仓库 / Proto / 事件契约 / 独立构建；
2. local 基础设施 / 可观测性 / 最小事件往返；
3. Web shell / 设计 token / 响应式 / WCAG 门禁。

每个任务必须有独立验收命令、失败恢复和完成证据；仍保留为一个用户价值 Story，不新增技术型 Epic。

### 4.3 Epic 3：消除 3.1 → 3.2 前向依赖

**OLD:**

```text
Story 3.1：批准可解释且不会越界的生产计划（FR11）
Story 3.2：配置具备能力与合规边界的模型策略（FR12）
```

**NEW:**

```text
Story 3.1：配置具备能力与合规边界的模型策略（FR12）
Story 3.2：批准可解释且不会越界的生产计划（FR11）
```

Story 3.1 的实施任务按序拆为：

1. 模型配置、价格、配额与 CostPolicy 快照；该切片是 Story 3.2 的前置 Gate；
2. CapabilityContract 与 FallbackPolicy；
3. DataPolicySnapshot 与 ProviderEligibilityPolicy。

Story 3.2 增加前置条件：

```text
Given Story 3.1 已发布仍有效的模型、价格、配额、成本与供应商资格快照
When 系统计算正式生产计划
...
```

**Rationale:** 保证每个 Story 只依赖已完成 Story 所提供的事实，恢复按编号推进的可验收性。

### 4.4 Story 3.3：拆分两个风险面

Story 编号和 FR13 不变，在实施文件中固定两个有序任务：

1. 领域事实 → Outbox/Inbox → WorkflowInbox/Signal Bridge → Temporal 的可恢复推进与故障注入；
2. ProjectExperienceView、SSE 游标、断线恢复与 staleness reason。

前者通过后才能接入后者；两者分别保存恢复、重复事件和断线场景的证据。

### 4.5 Story 5.5：拆分审计、运营投影与指标冻结

Story 编号和 FR23 不变，在实施文件中固定三个有序任务：

1. 不可篡改生产审计与关联 ID；
2. 只读运营投影与全样本分母；
3. Cohort / Complexity / MetricPolicy 快照和第 21 部前冻结。

### 4.6 Story 6.1：补充外部发布记录输入边界

在 Story 6.1 增加 AC：

```markdown
Given 阶段 C 需要验收既有外部发布内容的规则复核、冻结或下架
When 授权运营人员通过受控后台登记或导入 PublishedContentRecord
Then 系统保存不可变的外部内容、ReleaseVersion、渠道、外部标识/链接、首次发布时间、当前状态和来源证据
And 重复导入幂等、普通创作者无权写入，且该接口不触发自动公开发布。
```

**Rationale:** 为 Story 6.3 的“既有链接、重复发布和紧急下架”提供可验收事实输入，同时守住 MVP 不自动公开发布的边界。

### 4.7 UX：消除浅色主题范围歧义

**Artifact:** `EXPERIENCE.md` / 4.1 全局层级

**OLD:**

```text
账号与设置 | 账号、主题、通知、数据与安全设置 | 是
```

**NEW:**

```text
账号与设置 | 账号、当前深色主题信息与未来主题入口、通知、数据与安全设置 | 是
```

并补充：`MVP 不提供浅色主题切换；“主题”入口不得被视为浅色主题验收范围。`

### 4.8 技术基线文档：绑定责任 Story

**Artifact:** `技术基线锁定.md`

在“其他 P0”前增加：

```text
责任与放行：ag-core/生成工具由 Story 1.1 关闭；其余全栈 P0 由 Story 1.2 关闭。
Story 1.3 的完整脚手架与 internal-prod 放行必须同时取得两项 Story 的可恢复证据。
```

### 4.9 统一追踪矩阵

批准后新增 `planning-artifacts/traceability-matrix.md`，字段至少包含：Requirement ID、Story、Task/Test Level、Risk、Test Type、Evidence、Owner、Gate、Status。

首批强制覆盖：

- 硬预算与最大计费责任；
- `NOT_ACCEPTED / ACCEPTED / UNKNOWN` 三态提交；
- 生成候选与显式采用分离；
- QG-1～QG-6 覆盖权限；
- 敏感数据供应商准入、删除传播和 30 天目标；
- Outbox/Inbox、Signal Bridge、重复事件与恢复；
- WCAG 2.1 AA、非颜色单一编码、键盘和 reduced-motion。

### 4.10 Sprint Status 原子更新

批准并完成 Epic 文档改写后，在同一次变更中：

1. 新增 `1-2-锁定全栈-p0-技术基线: backlog`；
2. 将现 1.2～1.6 的键顺延为 1.3～1.7；
3. 交换 3.1/3.2 的标题键；
4. 保持所有 Epic/Story 状态为 backlog；
5. 更新 `last_updated` 和 workflow notes；
6. 运行编号、FR 覆盖和 YAML 解析校验，禁止只改文档不改状态。

## 5. Checklist Results

### 5.1 Understand Trigger and Context

- [x] 1.1：触发来源为实施就绪度评估；无进行中的触发 Story。
- [x] 1.2：核心问题已分类并精确定义。
- [x] 1.3：评估报告、技术基线、Epic 依赖与 Sprint 状态构成充分证据。

### 5.2 Epic Impact Assessment

- [x] 2.1：Epic 1 可完成，但必须新增 P0 Story 并顺延编号。
- [x] 2.2：修改 Epic 1 与 Epic 3；无需新增/删除 Epic。
- [x] 2.3：Epic 2、4、5、6 的依赖已检查。
- [x] 2.4：没有 Epic 失效；无需新 Epic。
- [x] 2.5：需要重排 Story，不改变 Epic 总优先级。

### 5.3 Artifact Conflict and Impact Analysis

- [x] 3.1：PRD 无冲突，MVP 可实现。
- [x] 3.2：架构不变量不变；技术基线需绑定责任 Story。
- [x] 3.3：UX 仅修正主题措辞。
- [x] 3.4：Sprint 状态、追踪矩阵和后续 readiness 需更新。

### 5.4 Path Forward Evaluation

- [x] 4.1：Direct Adjustment 可行；规划努力低、整体风险中等。
- [N/A] 4.2：无已完成/进行中的 Story，回滚没有收益。
- [N/A] 4.3：MVP 目标和范围无需缩减或重定义。
- [x] 4.4：选择 Direct Adjustment + Moderate Backlog Reorganization。

### 5.5 Proposal Components

- [x] 5.1：问题摘要完成。
- [x] 5.2：Epic 与 Artifact 影响完成。
- [x] 5.3：推荐路径和替代方案完成。
- [x] 5.4：MVP 不变，Sprint 0 行动和依赖已定义。
- [x] 5.5：交接计划已定义。

### 5.6 Final Review and Handoff

- [x] 6.1：适用检查项已完成。
- [x] 6.2：提案已进行一致性复核。
- [x] 6.3：用户已明确批准。
- [x] 6.4：`sprint-status.yaml` 已按 Epic 变更原子更新并通过 YAML/编号校验。
- [x] 6.5：执行责任、时间、成功标准和下一工作流已确认。

## 6. Implementation Handoff

### 6.1 Scope Classification

**Moderate：需要 Backlog 重组与 PO/DEV 协同。** 不需要 PM/Architect 重新定义产品方向，但架构负责人必须对 P0 证据签字。

### 6.2 Recipients and Responsibilities

| 角色 | 责任 |
|---|---|
| Product Owner / Planner | 批准 Story 编号、顺序、Sprint 0 范围与状态更新 |
| Architect / Platform Developer | 完成 Story 1.1、1.2 的版本、兼容、恢复和回滚证据 |
| Test Architect | 建立追踪矩阵、风险测试、模拟器、故障注入和 Gate 证据 |
| Developer | 在 Gate 通过后按原子任务执行顺延后的 Story 1.3 及后续 Story |
| Model / Compliance Owner | 提供供应商生产、计费、配额、数据与删除契约证据 |

### 6.3 Success Criteria

1. `技术基线锁定.md` 状态由 provisional 变为 locked，所有 P0 均有可恢复证据。
2. Epic 文档不存在前向 Story 依赖，Story 编号与 `sprint-status.yaml` 一致。
3. 干净环境可从远端 immutable refs 和锁定镜像重复构建并运行最小闭环。
4. 供应商提交三态、预算预留、对账、转存、质量和显式采用具备合同测试与金样。
5. 高风险 Requirement → Story → Test → Evidence 可追踪。
6. 重新运行 Implementation Readiness 后不再出现 C1/C2，状态至少允许进入功能 Story 实施。

## 7. Approval and Application Result

- Approval：用户已明确批准。
- Applied：Epics、技术基线、UX、Sprint Status、测试设计引用与追踪矩阵已更新。
- Validation：31 个 Story 与 31 个 Sprint 状态键对应；YAML/frontmatter 可解析；旧编号引用已清理；`git diff --check` 通过。
- Readiness：复核结论为 **NEEDS WORK — 可进入 Sprint 0，不可进入功能 Story**；原 C1/C2 已关闭，剩余 2 项 Major 实施边界与开放 P0 证据。
- Handoff：下一必需工作流为 `[CS] Create Story`，目标 Story 1.1；随后建议 `[AT] ATDD`，再进入 Dev Story。
