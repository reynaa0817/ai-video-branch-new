---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: 2026-07-14T10:53:54+08:00
storyId: "1.1"
storyKey: 1-1-锁定可恢复的-ag-core-与生成工具基线
storyFile: _bmad-output/implementation-artifacts/1-1-锁定可恢复的-ag-core-与生成工具基线.md
atddChecklistPath: _bmad-output/test-artifacts/atdd-checklist-1-1-锁定可恢复的-ag-core-与生成工具基线.md
generatedTestFiles:
  - tests/acceptance/baseline/base_001_test.sh
generatedFixtureFiles:
  - tests/acceptance/baseline/fixtures/base_001_fixture_factory.sh
inputDocuments:
  - _bmad/tea/config.yaml
  - _bmad-output/implementation-artifacts/1-1-锁定可恢复的-ag-core-与生成工具基线.md
  - _bmad-output/planning-artifacts/traceability-matrix.md
  - _bmad-output/test-artifacts/test-design-progress.md
  - _bmad-output/test-artifacts/test-design-qa.md
  - _bmad-output/test-artifacts/test-design/ai-video-handoff.md
  - .agents/skills/bmad-testarch-atdd/resources/tea-index.csv
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/data-factories.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/component-tdd.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-quality.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-healing-patterns.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-levels-framework.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/test-priorities-matrix.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/ci-burn-in.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/overview.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/api-request.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/auth-session.md
  - .agents/skills/bmad-testarch-atdd/resources/knowledge/recurse.md
---

# ATDD Checklist：Story 1.1 ag-core 与生成工具基线

## Step 1：Preflight 与上下文

### 输入确认

- Story：`1.1`，状态 `ready-for-dev`，验收标准清晰。
- Mandatory scenario：`BASE-001`，P0，风险关联 `R-001`（Score 9）。
- 测试栈：`backend/platform`。仓库尚无应用 manifest，本 Story 是 CI/供应链门禁，不适用前端、浏览器或 API 测试。
- 测试框架：GNU Bash 3.2 兼容的自包含验收脚本；统一入口已由 Story 冻结为 `bash tests/acceptance/baseline/base_001_test.sh`。
- 开发环境：Bash、Git、Go 与本地只读 ag-core checkout 可用于 preflight；红测不得依赖本机 checkout、全局工具或共享 cache。
- UI/Playwright：不适用；`tea_use_playwright_utils=true` 已读取，但本 Story 不生成 Playwright 测试。
- Pact/contract testing：不适用；本 Story不涉及服务 API 合同。

### 受影响组件

- ai-video：验收测试、fixtures、baseline manifest schema、未来权威验证脚本与 CI job。
- ag-core：远端 immutable tool source、root dependency 版本以及七个工具的构建 provenance。
- 证据：`reports/baseline/BASE-001/`。

### 红测设计约束

- 测试必须 deterministic、无 sleep、无真实远端写操作、无本机全局 PATH 依赖。
- 负向 fixtures 必须纯本地、每个 case 使用独立临时目录并自动清理。
- 正向远端恢复/真实 clean build 在实现前应因缺少签署 manifest 与权威 gate 而稳定失败，不得伪造通过。
- 单个测试脚本小于 300 行；若超限，抽取无断言 helper，断言仍留在测试主体。

### Preflight 结论

通过。Story、测试合同与开发环境满足 ATDD 红阶段要求，可以进入生成模式。

## Step 2：生成模式

- 选择：`AI Generation`。
- 理由：检测栈为 backend/platform，Acceptance Criteria、工具清单、manifest 双锁字段、负向错误码和唯一执行入口均已明确；没有浏览器录制或 UI selector 需求。
- 生成依据：Story 1.1、`BASE-001` 测试设计、ag-core 工具目录与本地只读 preflight 事实。

## Step 3：测试策略

### AC → 场景映射

| AC | 场景 | 层级 | 优先级 | 红阶段预期 |
| --- | --- | --- | --- | --- |
| AC1 | BASE-001-P01：tool source/root dep 两组远端 immutable ref/version 与 manifest SHA 一致 | CI Integration | P0 | 缺少签署 manifest 与权威 gate，失败 |
| AC2 | BASE-001-P02：隔离 `GOWORK`/cache 后构建七工具，数据库工具名为 `gendb` | CI Integration | P0 | 构建 gate 尚未实现，失败 |
| AC3 | BASE-001-P03：七份 metadata 分别匹配 tool/root 双锁，VCS stamping 完整且未修改 | CI Integration | P0 | provenance gate 尚未实现，失败 |
| AC5 | BASE-001-P04：manifest、保护证据、回滚与 traceability 证据完整 | Static/CI Integration | P0 | evidence 尚不存在，失败 |
| AC4 | BASE-001-N01～N09：每类异常返回稳定 `B001-E01～E09` 且非零退出 | Shell Contract Integration | P0 | 权威 gate 尚不存在，九个场景均失败 |

### 测试分层决策

- 只生成一个 Bash acceptance suite，覆盖脚本接口、fixtures 和 CI 门禁行为；不复制为 UI、API 或 E2E 测试。
- 正向场景是远端恢复/构建/provenance/evidence 的 CI integration contract。
- 负向场景使用本地 fixture factory 生成最小 manifest、metadata 和伪 ref 解析结果，验证错误分类；不访问真实 GitHub、不写远端状态。
- helper 只负责 fixture 生成、临时目录和命令捕获；错误码/退出码断言保留在测试主体。

### P0 理由

`BASE-001` 对应 R-001（概率 3 × 影响 3 = 9）和 G0-1；假绿会让 Story 1.3 在不可恢复工具链上运行，因此全部场景均为 P0，要求 100% 通过。

### 红阶段合同

- 生成测试后立即执行统一命令。
- 当前必须稳定返回非零；预期首个明确失败原因为缺少 `scripts/verify-ag-core-baseline.sh` 或缺少已签署 baseline manifest。
- 不允许用 `skip`、空断言、固定 sleep、真实 push 或本机 `/Users/zhangyong/Downloads/ag-core` 让测试变绿。

## Step 4：红测生成与聚合

### 执行模式

- Requested：`auto`
- Resolved：`agent-team`
- Backend worker：生成 CLI/CI contract 红测。
- E2E worker：确认无适用 UI journey，生成 0 个浏览器测试。

### 生成文件

- `tests/acceptance/baseline/base_001_test.sh`
- `tests/acceptance/baseline/fixtures/base_001_fixture_factory.sh`

### Bash 红阶段等价语义

工作流的 `test.skip()` 要求在 Bash 中实现为显式 activation guard：

- 默认：`bash tests/acceptance/baseline/base_001_test.sh` 输出 TAP skip 并返回 0，不污染普通 CI。
- 激活：`BASE001_ATDD_ACTIVATE=1 bash tests/acceptance/baseline/base_001_test.sh` 执行 13 个 P0 场景；在权威 gate 尚未实现时必须返回非零，证明 RED。
- Green 条件：开发实现 `scripts/verify-ag-core-baseline.sh` 后，激活命令 13/13 通过。

### 覆盖汇总

- 正向：4 个（P01～P04）。
- 负向：9 个（N01～N09，对应 `B001-E01～E09`）。
- API：0；E2E：0；Component：0。
- Fixture：1 个纯本地 factory，每 case 独立临时目录并自动清理。

### 安全与确定性

- fixture 只生成本地 manifest、metadata、build/evidence 记录，不访问真实 GitHub。
- 测试不 push、不修改 GitHub ruleset、不调用开发机 ag-core checkout、不使用固定 sleep 或共享 cache。
- `gendb` 二进制的 metadata source path 明确为 `tool/cmd/gen-go-db`，避免把安装名误当源码目录。

### 实施激活顺序

1. 运行默认命令确认 scaffold 为 skip。
2. 使用 activation 命令确认 RED。
3. 按当前开发任务实现权威 gate。
4. 重复 activation 命令直至 13/13 GREEN。

## Step 5：实施清单与最终校验

### DEV 实施清单

- [ ] 实现唯一权威入口 `scripts/verify-ag-core-baseline.sh`，支持 `refs` / `build` / `metadata` / `evidence` / `all` 检查。
- [ ] 实现 baseline manifest schema，覆盖 source snapshot、tool source 双字段、root dependency 双字段、环境冻结、签署/审批与保护证据。
- [ ] 实现 remote+immutable ref 解析和 SHA 精确匹配，禁止本机 checkout 或可移动 ref 掩盖失败。
- [ ] 在隔离 `GOWORK` / `GOMODCACHE` / `GOCACHE` 的环境中构建七个工具，并保证数据库工具输出名为 `gendb`。
- [ ] 验证七份 Go build metadata 的 tool/root 双锁 provenance、GitHub 路径、VCS revision 和 `vcs.modified=false`。
- [ ] 实现 `B001-E01`～`B001-E09` 稳定错误分类，输出具体工具、字段和实际值，以非零退出阻断下游。
- [ ] 生成 `reports/baseline/BASE-001/` 的 manifest、环境、保护、回滚、negative cases 与 traceability 证据。
- [ ] 增加 CI job，只从 canonical remote+ref 恢复，并以激活命令作为 P0 gate。
- [ ] 完成授权的 immutable ref/保护规则外部写操作，将真实 SHA 回填到签署 manifest；无批准时不得尝试。
- [ ] 运行 RED 激活命令直至 13/13 GREEN，然后移除 activation guard，使 Story 冻结的默认命令成为权威 CI 入口。

### Red-Green-Refactor

1. **RED（TEA 已完成）**：默认 scaffold 为 skip；显式激活后 13/13 因缺少权威 gate 而确定性失败。
2. **GREEN（DEV）**：按 P01→P04、N01→N09 逐项实现，不得放宽断言或把 fixture 特判为通过。
3. **REFACTOR（DEV）**：在 13/13 持续通过后抽取无断言 helper，保持单一权威 gate、稳定错误码和 hermetic 边界。

### 执行命令

```bash
# 默认：开发前不污染普通 CI
bash tests/acceptance/baseline/base_001_test.sh

# 当前开发任务：激活 RED/GREEN 契约
BASE001_ATDD_ACTIVATE=1 bash tests/acceptance/baseline/base_001_test.sh

# 静态语法校验
bash -n tests/acceptance/baseline/base_001_test.sh
bash -n tests/acceptance/baseline/fixtures/base_001_fixture_factory.sh
```

本 Story 不适用 headed/debug 浏览器命令。建议 DEV 工作量为 5 story points，其中不含等待 GitHub owner 批准或凭据的时间。

### 最终验证证据

- `bash -n`：测试与 fixture factory 均通过；本机未安装 `shellcheck`，未把安装新工具扩展到本工作流。
- 默认执行：退出码 `0`，输出 `1..0 # SKIP ATDD RED scaffold`。
- 显式激活：连续两次均退出 `1`，输出一致，`pass=0 fail=13`；明确根因为尚无 `scripts/verify-ag-core-baseline.sh`。
- 负向场景在 gate 实现前不伪造错误码；当前因缺少 gate 而失败，实现后必须分别命中 `B001-E01`～`B001-E09`才可 GREEN。
- 无 sleep、无开发机 ag-core checkout 路径、无 push/GitHub ruleset 写操作；两次 RED 输出确定且每 case 自动清理。
- YAML frontmatter 可解析，Story 回链、Story ID/Key、测试与 fixture 路径完整。
- 本次未打开 browser/Playwright/Pact/CLI browser session，无孤儿会话需清理。

### 适用性说明

ATDD 通用清单中的 Playwright/Cypress、HTTP API、UI component、`data-testid`、faker 和 browser network-first 条目对 backend/platform Bash 供应链门禁不适用。对应品质目标已通过隔离目录、确定性 fixture factory、无网络红测、自动清理和稳定 CLI 合同实现。`test.skip()` 以 Bash activation guard 等价表达。

### 交付汇总

- Story：`1.1`
- Primary level：CLI/CI integration（backend/platform）
- Tests：13（P0 正向 4，P0 负向 9；API/E2E/Component 均为 0）
- Test files：1
- Fixture factories：1
- External mock endpoints：0
- `data-testid`：0
- DEV implementation tasks：10
- 估算：5 story points，不含外部授权等待
- 下一步：进入 `[DS] Dev Story`，以显式激活命令维持 RED→GREEN 循环。
