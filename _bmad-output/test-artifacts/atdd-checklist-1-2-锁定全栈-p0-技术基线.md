---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: 2026-07-14T12:47:00+08:00
storyId: "1.2"
storyKey: 1-2-锁定全栈-p0-技术基线
storyFile: _bmad-output/implementation-artifacts/1-2-锁定全栈-p0-技术基线.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-2-锁定全栈-p0-技术基线.md
generatedTestFiles:
  - tests/acceptance/baseline/base_002_test.sh
generatedFixtureFiles:
  - tests/acceptance/baseline/fixtures/base_002_fixture_factory.sh
inputDocuments:
  - _bmad/tea/config.yaml
  - _bmad-output/implementation-artifacts/1-2-锁定全栈-p0-技术基线.md
  - _bmad-output/implementation-artifacts/1-1-锁定可恢复的-ag-core-与生成工具基线.md
  - _bmad-output/planning-artifacts/traceability-matrix.md
  - _bmad-output/test-artifacts/test-design-progress.md
  - _bmad-output/test-artifacts/test-design-qa.md
  - _bmad-output/test-artifacts/test-design/ai-video-handoff.md
  - _bmad-output/test-artifacts/atdd-checklist-1-1-锁定可恢复的-ag-core-与生成工具基线.md
  - .agents/skills/bmad-testarch-atdd/resources/tea-index.csv
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/data-factories.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/component-tdd.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-healing-patterns.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-priorities-matrix.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/ci-burn-in.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/contract-testing.md
---

# ATDD Checklist：Story 1.2 全栈 P0 技术基线

## Step 1：Preflight 与上下文

### 输入确认

- Story：`1.2`，状态 `ready-for-dev`，六项 Acceptance Criteria 清晰。
- Mandatory scenarios：`BASE-002`、`NFR-DR-001` 最小 smoke；关联 Sprint 0 G0-2 和 R-001/R-013/R-018。
- 测试栈：`backend/platform`。仓库尚无应用 manifest，但已有可执行 Bash acceptance framework、fixture factory 和权威 gate 模式。
- 测试框架：GNU Bash 3.2 兼容的自包含验收脚本；统一入口为 `bash tests/acceptance/baseline/base_002_test.sh`。
- 开发环境：Bash、Git、Docker CLI、Go 和现有 BASE-001 证据可用于 preflight；任何容器、Kubernetes、媒体或恢复依赖都必须通过 capability probe 显式判定。
- UI/Playwright：不适用。本 Story 不创建 Web shell 或页面，只验证 frozen lockfile fixture。
- Pact：不适用。组件兼容性通过 manifest/schema、CLI contract 与隔离 integration harness 验证。

### 当前前置状态

- Story 1.1 已进入 `review`，G0-1 为 `Verified`，`reports/baseline/BASE-001/` 可复核。
- Story 1.2 文件 Dev Notes 中“Story 1.1 仍为 in-progress”是创建时快照，ATDD 与开发以当前 sprint/traceability 状态为准。
- BASE-002 尚无 manifest、schema、权威 gate、fixture 或证据，因此具备稳定 RED 条件。

### 受影响组件

- 运行时/数据：Temporal、MySQL、Kafka/agsarama、Nacos、Redis、S3 兼容对象存储。
- Web/媒体工具：Node/包管理器/lockfile、React/Vite/TypeScript fixture、FFmpeg/ffprobe/font/subtitle/AI label 金样。
- 部署/恢复：Kubernetes/CNI/CSI/Ingress、升级/回滚、PITR、RPO/RTO、对象引用一致性。
- 测试与证据：`tests/acceptance/baseline/`、`scripts/verify-full-stack-baseline.sh`、`reports/baseline/BASE-002/`、`reports/dr/NFR-DR-001/`。

### 红测设计约束

- deterministic、无固定 sleep、每 case 独立 `mktemp` 并 trap 清理。
- 红阶段不启动真实集群、不下载大镜像、不调用云服务或真实模型供应商。
- fixture 只表达 manifest、兼容矩阵、隔离、媒体/恢复报告和错误分类；真实 clean integration 由开发阶段 capability-gated profile 执行。
- 断言保留在测试主体，factory 只生成输入；错误必须包含组件、字段、预期/实际值和稳定错误码。
- 快速合同 suite 目标 `<15 分钟`；完整故障/恢复/媒体 profile 由权威 gate 引用最新有效证据，不能以 fixture GREEN 冒充真实放行。

### Preflight 结论

通过。Story、现有 Bash 测试框架、开发环境与 RED 条件满足 ATDD 创建模式要求，可以进入生成模式。

## Step 2：生成模式

- 选择：`AI Generation`。
- 理由：检测栈为 backend/platform，Acceptance Criteria、mandatory scenario、证据路径和唯一 CLI 入口均已明确，不存在需要录制的 UI selector 或浏览器交互。
- 生成依据：Story 1.2、BASE-001 已验证模式、系统级测试设计、G0-2/NFR-DR-001 风险与现有 Bash fixture 约定。
- 浏览器会话：未创建，不需要清理。

## Step 3：测试策略

### AC → 场景映射

| AC | 场景 | 层级 | 优先级 | RED 预期 |
| --- | --- | --- | --- | --- |
| AC1 | BASE-002-P01：manifest 所有组件含精确 version/digest、license、owner、兼容、回滚和证据 | Static/CLI Integration | P0 | 缺少 BASE-002 gate 与 manifest，失败 |
| AC2 | BASE-002-P02：clean integration 环境、Namespace/Topic/DB/Bucket/Secret 完全隔离 | CLI Integration | P0 | 隔离验证器不存在，失败 |
| AC2 | BASE-002-P03：Temporal/MySQL、Kafka、Nacos/Redis、S3 合同和故障矩阵完整 | Contract Integration | P0 | 兼容矩阵与证据不存在，失败 |
| AC4 | BASE-002-P04：Web frozen install 双跑 digest 一致且 lockfile 不变 | Build Integration | P0 | Web fixture/gate 不存在，失败 |
| AC5 | BASE-002-P05：FFmpeg 金样满足 DeliveryProfile、字幕、字体、AI 标识与元数据 | Media Integration | P0 | 媒体 fixture/gate 不存在，失败 |
| AC3/6 | BASE-002-P06：升级、回滚、恢复和四类 fail-closed 证据通过 | DR/CLI Integration | P0 | rollback/fault report 不存在，失败 |
| AC3 | NFR-DR-001-S01：RPO≤5m、RTO≤2h、对象引用一致 | DR Contract Integration | P1/Gate | 计时恢复报告不存在，失败 |
| AC1 | BASE-002-N01：必填字段缺失或占位值 | Static Contract | P0 | 未来命中 `B002-E01` |
| AC1 | BASE-002-N02：`latest`、浮动 ref、本地缓存或 tag/digest 不符 | Static Contract | P0 | 未来命中 `B002-E02` |
| AC1/2/4 | BASE-002-N03：组件/SDK/schema/lockfile 不兼容 | Compatibility Contract | P0 | 未来命中 `B002-E03` |
| AC2 | BASE-002-N04：共享 Namespace/Topic/DB/Bucket/Secret | Isolation Contract | P0 | 未来命中 `B002-E04` |
| AC3 | BASE-002-N05：核心依赖不可用时仍产生新付费推进 | Fail-closed Contract | P0 | 未来命中 `B002-E05` |
| AC5 | BASE-002-N06：媒体静态、错规格、无字幕/标识/元数据 | Media Contract | P0 | 未来命中 `B002-E06` |
| AC3 | BASE-002-N07：恢复超阈值或对象引用不一致 | DR Contract | P0 | 未来命中 `B002-E07` |
| AC6 | BASE-002-N08：G0-1/G0-2 未通过却放行 Story 1.3 | Aggregate Gate Contract | P0 | 未来命中 `B002-E08` |

### 分层与去重

- 一个 Bash acceptance suite 负责 CLI/static/integration contract，不生成浏览器 E2E。
- fixture factory 生成最小 manifest、矩阵、Web/media/DR 报告和隔离标识；断言与错误码检查留在测试主体。
- 快速 suite 只验证权威 gate 的行为和证据合同；真实 Docker/Kubernetes/媒体/恢复执行由开发阶段 profile 生成证据，不在红测中重复。
- `NFR-DR-001-S01` 独立于 BASE-002-P06：前者断言量化阈值，后者断言报告、升级/回滚及 fail-closed 完整性。

### 优先级与 RED 合同

- 除量化 DR smoke 标为 P1/Gate 外，其余 14 个场景均为 P0；P0 必须 100% 通过。
- 默认 scaffold 可 skip；`BASE002_ATDD_ACTIVATE=1` 必须执行全部 15 个场景并在权威 gate 尚不存在时稳定非零。
- 不允许通过空断言、真实云资源、固定 sleep、共享卷或复用 BASE-001 fixture 伪造 GREEN。

## Step 4：红测生成与聚合

### 执行模式

- Requested：`auto`。
- Resolved：`sequential`，遵循当前会话不启动子代理的约束。
- CLI/API applicability worker：生成 BASE-002 Bash contract 红测。
- E2E applicability worker：确认 Story 无 UI journey，生成 0 个浏览器测试。

### 生成文件

- `tests/acceptance/baseline/base_002_test.sh`
- `tests/acceptance/baseline/fixtures/base_002_fixture_factory.sh`

### RED 语义

- Bash activation guard 等价于通用工作流的 `test.skip()`。
- 默认运行输出 TAP skip 并返回 0。
- `BASE002_ATDD_ACTIVATE=1 bash tests/acceptance/baseline/base_002_test.sh` 激活 15 个场景；在 `scripts/verify-full-stack-baseline.sh` 尚不存在时必须非零。
- 测试断言的是最终行为和稳定错误码，不含 `expect(true)` 等占位断言。

### 覆盖汇总

- 正向：BASE-002-P01～P06，共 6 个 P0。
- DR：NFR-DR-001-S01，共 1 个 P1/Gate。
- 负向：BASE-002-N01～N08，共 8 个 P0，对应 `B002-E01`～`B002-E08`。
- API endpoint：0；浏览器 E2E：0；Component：0。
- Fixture：1 个纯本地 factory，生成 manifest、license、compatibility、isolation、Web、media、resilience、DR 与 gate decision 输入。

### 安全与确定性

- 每 case 独立 `mktemp`、自动清理、最小 PATH、无固定 sleep。
- 红测不启动容器/集群、不访问云资源、不调用供应商、不写远端。
- 完整 integration profile 必须在开发阶段产生真实证据；fixture GREEN 不得升级 G0-2。

## Step 5：实施清单与最终校验

### DEV 实施清单

- [ ] 实现 `scripts/verify-full-stack-baseline.sh` 唯一权威入口，支持 `manifest/isolation/compatibility/web/media/resilience/dr/all`。
- [ ] 建立 `reports/baseline/BASE-002/baseline-manifest.yaml` 与 schema，拒绝缺值、占位、`latest`、浮动 ref 和未审批组合。
- [ ] 锁定并验证 Temporal/MySQL、Kafka/agsarama、Nacos/Redis、S3 兼容对象存储组合及许可证。
- [ ] 建立 integration/internal-prod 的 Namespace/Topic/DB/Bucket/Secret 隔离证据。
- [ ] 建立 Web frozen lockfile 双跑 fixture，验证 lockfile、依赖树和产物 digest 一致。
- [ ] 建立 FFmpeg/ffprobe 媒体金样 profile，验证 1080×1920/30fps/H.264/AAC/字幕/中文字体/AI 标识/元数据。
- [ ] 建立四类核心依赖故障下 zero-new-paid-work、升级与回滚证据。
- [ ] 建立 `reports/dr/NFR-DR-001/`，验证 RPO≤5m、RTO≤120m 和对象引用一致。
- [ ] 建立 `.github/workflows/full-stack-baseline.yml`，只编排权威脚本、capability profile 和证据上传。
- [ ] 将 15 个激活场景逐项从 RED 推到 GREEN；完成真实 clean integration 之前不得将 G0-2 更新为 Verified。

### Red-Green-Refactor

1. **RED（已完成）**：默认 scaffold skip；显式激活连续两次均为 `pass=0 fail=15`，退出码 1，根因为权威 gate 尚不存在。
2. **GREEN（DEV）**：先实现确定性 fixture gate，再锁定精确版本/digest、生成真实 integration/media/DR 证据。
3. **REFACTOR（DEV）**：保持单一权威入口、稳定错误码、profile 分层与 `<15 分钟` 快速合同边界。

### 执行命令

```bash
bash tests/acceptance/baseline/base_002_test.sh
BASE002_ATDD_ACTIVATE=1 bash tests/acceptance/baseline/base_002_test.sh
bash -n tests/acceptance/baseline/base_002_test.sh
bash -n tests/acceptance/baseline/fixtures/base_002_fixture_factory.sh
```

### 最终验证证据

- `bash -n`：测试与 fixture factory 通过。
- 默认执行：退出 0，输出 `1..0 # SKIP ATDD RED scaffold`。
- 激活执行：连续两次退出 1，输出一致，`pass=0 fail=15 expected_to_fail=true tdd_phase=RED`。
- 无 sleep、无开发机 ag-core 路径、无 push/远端写操作；每 case 自动清理。
- YAML frontmatter 可解析，Story ID/Key、Story 回链、测试与 fixture 路径完整。
- UI/E2E/Component、HTTP API、`data-testid`、browser session、Pact、外部 mock endpoint 均不适用，数量为 0。

### 交付汇总

- Story：`1.2`
- Primary level：CLI/static/integration contract（backend/platform）
- Tests：15（P0 14，P1/Gate 1；E2E/API endpoint/Component 均为 0）
- Test files：1
- Fixture factories：1
- DEV tasks：10
- 下一步：进入 `bmad-dev-story`，以激活命令执行 RED→GREEN。
