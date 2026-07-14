---
tags:
  - ai-video
  - BMAD
  - Correct-Course
  - ag-core
date: 2026-07-14
title: ag-core 本地快照误冻结纠偏提案
status: approved-applied
approved_date: 2026-07-14
change_scope: moderate
mode: batch
trigger: Story-1.1-hermetic-preflight
---

# Sprint Change Proposal：ag-core 本地快照误冻结纠偏

## 0. 提案状态

- 当前状态：**已批准并应用**。
- 执行模式：Batch。
- 变更分类：**Moderate**。不改变产品方向、Epic 顺序或 MVP 范围，但需要同步修改架构约束、活动 Story、ATDD 合同和门禁实现。
- 推荐路径：Direct Adjustment。

## 1. Issue Summary

### 1.1 触发问题

Story 1.1 实施时，hermetic preflight 证明被规格写死的 SHA `7bc2f4561a9284728cb92b15b9ae9ee760abfa5c` 无法从规范 remote `https://github.com/aif-go/ag-core.git` 恢复：

```text
git fetch --depth=1 origin 7bc2f4561a9284728cb92b15b9ae9ee760abfa5c
fatal: remote error: upload-pack: not our ref 7bc2f4561a9284728cb92b15b9ae9ee760abfa5c

SOURCE_SNAPSHOT_REACHABLE=false
```

该 SHA 的原始含义只是用户确认采用 GitHub 版 ag-core 时，本机 `/Users/zhangyong/Downloads/ag-core` checkout 的现场 HEAD。它不是用户批准的发布版本，也不是远端可恢复基线。

### 1.2 根因分类

- 类型：对原始要求的误解。
- 具体根因：把“采用 GitHub 版 ag-core”错误扩张成“采用本机 checkout 当前提交”。
- 流程缺陷：在远端可恢复性 preflight 之前冻结 SHA，并让 Story、ATDD 和 schema 机械继承现场值。

### 1.3 矛盾证据

架构记录同时包含两条互相冲突的结论：

1. 将 `7bc2...` 记为架构基线；
2. 明确该提交只在本地分支、无远端分支包含、不能作为 CI 可恢复锁。

后续 Story 又把该已知不可恢复值写成 Acceptance Criteria、fixture、JSON Schema `const` 和验证脚本常量，导致 BASE-001 从定义上无法通过。

## 2. Impact Analysis

### 2.1 Epic Impact

| Epic | 影响 | 结论 |
| --- | --- | --- |
| Epic 1 | Story 1.1 的候选选择与验收顺序需修正 | 修改 Story 1.1，不改 Epic 目标或编号 |
| Epic 2～6 | 不依赖具体 ag-core SHA | 无内容修改 |

Epic 1 仍然可以按原计划完成；Story 1.2、1.3 的依赖关系不变。无需新增、删除或重排 Epic/Story。

### 2.2 Story Impact

- Story 1.1 从“发布已核验本机快照”改为“从规范远端选择可达候选，或完成必要 PR 后使用 merge SHA，再发布 immutable ref”。
- `source_snapshot_sha` 不再是发布 manifest 的强制字段或固定常量。
- `tool_source_ref/tool_source_sha` 与 `root_dep_version/root_dep_sha` 仍是签署 manifest 的强制双锁。
- Story 1.1 保持 `in-progress`；Task 1～5 均未完成，不需要回滚完成状态。

### 2.3 Artifact Conflicts

| Artifact | 当前冲突 | 调整 |
| --- | --- | --- |
| PRD | 不涉及 ag-core SHA | 不修改 |
| Epics | Story 1.1 使用“已核验工作快照”作为起点 | 改为远端候选选择策略 |
| Architecture Spine | Stack/Deferred 把本机 SHA 当作待发布基线 | 改为待选远端可达候选 |
| 系统架构说明 | 要求先发布本机 SHA | 改为先选择/产生远端可达候选 |
| 技术基线锁定 | 工作快照 SHA 被列为已核验基线 | 改为历史调查证据；新增候选 ref/SHA 待锁定 |
| 架构 review | 记录的是历史现场事实 | 保留并标记已被本提案纠偏，不作为规范输入 |
| Story 1.1 | AC、Tasks、Dev Notes 多处写死 SHA | 批量替换为候选选择与 manifest 双锁规则 |
| ATDD | fixture 与 checklist 固定 SHA | 删除固定 source snapshot 断言 |
| Manifest/schema | `source_snapshot_sha` 为必填/const | 删除该发布字段；只保留最终双锁与审批证据 |
| Gate script | 编译期常量校验 `7bc2...` | 删除常量；验证 manifest 与远端 ref 解析一致 |
| 失败记录 | 把发布本地 SHA列为恢复选项 | 标记为 superseded；保留调查证据 |
| UX | 无关系 | 不修改 |

### 2.4 Technical Impact

保留以下不变量：

- canonical remote 固定为 `https://github.com/aif-go/ag-core.git`；
- 禁止 GitLab module/provenance；
- 七个工具必须在隔离环境重建，`gendb` 名称不变；
- 禁止本地 replace、根 go.work、PATH 旧二进制和 module cache 掩盖；
- tool source 与 root dependency 双锁必须远端可解析并精确匹配 manifest；
- VCS stamping、签署审批、ref protection 和失败关闭规则不变。

变化仅在候选来源：不再预先规定本机 SHA，先验证远端可达候选或受审 PR merge SHA，再冻结最终 immutable ref。

### 2.5 Timeline / Effort / Risk

- 文档与合同修正：约 0.5 人日。
- 重新运行本地 ATDD 与远端只读 preflight：约 0.5 人日，不含真实工具构建下载时间。
- ag-core 若无需修改：可直接评估现有远端 tag/commit 候选。
- ag-core 若需修改：另走受审 PR；等待时间取决于 repo owner。
- 变更风险：低到中。主要风险是误选“远端可达但工具不可重复构建”的候选，已由 BASE-001 clean build 和 provenance 门禁覆盖。
- 不变更风险：确定性失败，Story 1.1 永远无法通过。

## 3. Recommended Approach

选择 **Option 1：Direct Adjustment**。

- Option 2 Rollback 不适用：没有已完成 Story；现有 gate 初版可直接修正，无需丢弃全部工作。
- Option 3 MVP Review 不适用：产品目标、功能范围和用户旅程均不受影响。
- 不应把 `7bc2...` 强行推入远端，因为这会把错误规格变成远端历史和治理负担。

正确顺序：

1. 从规范 remote 枚举可达候选，或确认 ag-core 是否必须先修复。
2. 对候选执行 Go 版本、七工具、root dependency 和 provenance 只读 preflight。
3. 若需修复，合并受审 ag-core PR 后使用 merge SHA 作为 tool source 候选。
4. Architecture 批准 tool/root 双锁关系。
5. 满足远端写入 Entry Criteria 后创建/保护 immutable ref。
6. 将最终 ref/SHA 写入签署 manifest，再运行真实 BASE-001。

## 4. Detailed Change Proposals

### 4.1 Epic Story 1.1

**OLD：**

```text
Given 已核验的工作快照 SHA 和规范 GitHub remote
When 发布并记录 immutable ref...
```

**NEW：**

```text
Given 规范 GitHub remote 与候选选择规则已确认
When 从远端可达 immutable version 选择 root dependency，并对现有远端候选或受审 PR merge SHA 完成 clean-build preflight
Then 将最终 tool source 与 root dependency ref/version+SHA 写入签署 manifest
And 任一候选在冻结前必须已从规范远端可恢复，不得引用本机 checkout SHA。
```

理由：冻结发布结果，不冻结调查现场。

### 4.2 Story 1.1 实施文件

批量修改 AC1、Task 1～3、Dev Notes、测试矩阵与“当前现场事实”：

- 删除 `7bc2...` 作为 `source_snapshot_sha` 的强制要求；
- 删除“无需修复时 tool source 必须等于源快照”的规则；
- 增加候选选择记录：候选 ref/SHA、选择理由、clean-build 结果和批准人；
- 本机 checkout 只允许用于调查差异，不得成为候选身份或验收输入；
- 保留历史 preflight 失败作为规格缺陷证据。

### 4.3 Architecture Spine / 系统架构说明

**OLD：**

```text
本地已验证工作快照 7bc2...，远端不可变 ref 待 P0 发布。
实施前必须先将确认快照发布为远端 ref。
```

**NEW：**

```text
ag-core 发布候选尚待 Story 1.1 从规范远端可达提交或受审 PR merge SHA 中选择。
实施前必须先通过 clean-build/provenance preflight，再发布受保护 immutable ref。
本机 checkout 仅为调查证据，不能决定发布候选。
```

AD-19 本身无需改变，因为它只要求 CI 使用远端可达 immutable ref+SHA。

### 4.4 技术基线锁定

将：

```text
工作快照 SHA | 7bc2... | 已核验
```

替换为：

```text
历史调查 checkout/SHA | /Users/.../ag-core @ 7bc2... | 非规范证据，不参与放行
候选 tool source ref/SHA | 待 Story 1.1 preflight 后选择 | P0 阻塞
候选 root dep version/SHA | 待 Story 1.1 preflight 后选择 | P0 阻塞
```

### 4.5 Manifest、Schema 与 Gate

- 从发布 manifest 删除 `source_snapshot_sha`。
- Schema required/properties 删除该字段与 `const`。
- fixture factory 不再生成该字段。
- gate 删除 `SOURCE_SNAPSHOT_SHA` 常量和固定值校验。
- refs 检查继续验证 `tool_source_ref → tool_source_sha`、`root_dep_version → root_dep_sha`。
- 增加测试：manifest 使用任意合法、与 fixture remote 精确匹配的 SHA 可通过；不允许重新引入本机路径或固定 SHA。

### 4.6 历史材料

- `.memlog.md` 不改写历史记录，只追加纠偏 decision。
- `ag-core来源最终确认.md` 与 technology-reality review 增加 `superseded_by`/醒目标注，说明其中本机 SHA 仅为历史现场事实。
- `远端源快照预检失败记录.md` 保留，状态改为“已触发规格纠偏”；删除“将该 SHA 引入远端”作为推荐恢复路径。

### 4.7 Sprint Status

- Story 1.1 保持 `in-progress`。
- 不新增、删除、重命名或重排 Story。
- 批准应用时仅更新 `last_updated` 和 workflow note，记录本次 Correct Course。

## 5. Checklist Results

### 5.1 Trigger and Context

- [x] 1.1：触发 Story 为 1.1。
- [x] 1.2：问题属于原始要求误解与错误不变量。
- [x] 1.3：直接 fetch、完整 refs clone、架构 memlog 与 Story 常量构成充分证据。

### 5.2 Epic Impact

- [x] 2.1：Epic 1 可继续完成，只需修正 Story 1.1。
- [x] 2.2：无需新增、删除或重定义 Epic。
- [x] 2.3：Epic 2～6 不依赖具体 SHA。
- [x] 2.4：没有 Epic 失效或新增缺口。
- [N/A] 2.5：无需调整 Epic/Story 顺序或优先级。

### 5.3 Artifact Impact

- [x] 3.1：PRD 无冲突，MVP 不变。
- [x] 3.2：架构方向不变，候选选择和基线描述需修正。
- [N/A] 3.3：UX 无影响。
- [x] 3.4：Story、ATDD、manifest/schema、gate、证据文档和 sprint note 需同步。

### 5.4 Path Forward

- [x] 4.1：Direct Adjustment 可行；努力低到中，风险低到中。
- [N/A] 4.2：无已完成 Story，回滚无收益。
- [N/A] 4.3：MVP 无需缩减或重定义。
- [x] 4.4：选择 Option 1 Direct Adjustment。

### 5.5 Proposal Components

- [x] 5.1～5.5：问题、影响、路径、行动与交接均已定义。

### 5.6 Final Review

- [x] 6.1：适用检查项已完成。
- [x] 6.2：提案与 PRD/Epics/Architecture/UX/Story 交叉核对完成。
- [x] 6.3：用户于 2026-07-14 明确批准批量实施。
- [N/A] 6.4：无需变更 Story/Epic 键。
- [x] 6.5：批准后由 Developer 批量应用，Architect 复核候选选择规则。

## 6. Implementation Handoff

### 6.1 Scope Classification

**Moderate**：Developer 可直接完成文档、测试和 gate 修正；Architect/Platform owner 负责批准最终候选与双锁，repo owner 只在确需发布 ref 或合并 ag-core PR 时介入。

### 6.2 Success Criteria

1. 规范性文档和可执行代码中不再把 `7bc2...` 作为 BASE-001 不变量。
2. 历史调查材料仍能说明该 SHA 的来源和失败，但明确不参与放行。
3. fixture ATDD 覆盖任意合法双锁，不依赖特定源码 SHA。
4. gate 只依据签署 manifest 与规范远端解析结果判定。
5. 远端候选选择发生在 immutable ref 发布之前，并有 clean-build/provenance 证据。
6. Story 1.1 保持失败关闭，直到真实双锁、保护规则和七工具证据全部通过。

### 6.3 批准后执行顺序

1. 更新 Story/Epics/Architecture/技术基线/历史 review 标注。
2. 更新 ATDD checklist、fixture、manifest/schema、gate 和发布合同。
3. 更新 sprint note 与 Obsidian 记录。
4. 运行静态校验和 13 个 fixture 场景。
5. 从规范 remote 重新选择候选并执行只读 preflight。
6. 若 preflight 发现需 ag-core 修改，再单独提交 PR/发布权限请求，不擅自写远端。

## 7. Approval and Application Result

- Approval：用户于 2026-07-14 明确批准批量实施。
- Applied：Epics、Architecture Spine、系统架构说明、技术基线、历史 review 标注、Story 1.1、ATDD checklist、manifest/schema、fixture、gate、Sprint Status、证据报告与 Obsidian 记录已同步。
- Static validation：Shell 语法、JSON Schema JSON 解析与 `git diff --check` 通过。
- Contract validation：BASE-001 fixture ATDD 13/13 通过，且可执行合同不再包含固定本机 SHA 或 `source_snapshot_sha`。
- Remote preflight：`main@d199072...` 与 `v0.0.1-alpha.3@1624c77...` 均为 2/7 工具构建通过；五个 protoc 插件因 root dependency `go.sum` 校验项缺失失败。
- Scope outcome：Correct Course 完成；Story 1.1 保持 `in-progress` 和失败关闭，下一交接为 ag-core owner/Developer 创建受审修复 PR。
