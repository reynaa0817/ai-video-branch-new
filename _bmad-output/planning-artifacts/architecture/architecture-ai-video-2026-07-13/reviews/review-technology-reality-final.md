---
tags:
  - ai-video
  - architecture
  - reviewer-gate
  - technology-reality
  - final
date: 2026-07-14
title: AI漫剧创作平台GitHub ag-core技术现实性最终复核
---

# AI 漫剧创作平台 GitHub ag-core 技术现实性最终复核

## Verdict

**PASS FOR ARCHITECTURE，BLOCKED FOR SCAFFOLDING。** GitHub 版 ag-core 的架构方向成立；当前仍缺远端可恢复 ref 和一致工具链，因此可以提交架构，但在 P0 关闭前不得运行脚手架或进入 internal-prod。

## 本地核验证据

| 检查项 | 证据 | 结论 |
| --- | --- | --- |
| GitHub 来源 | remote `https://github.com/aif-go/ag-core.git` | 通过 |
| Module | `github.com/aif-go/ag-core` | 通过 |
| Go 基线 | `go 1.25.0` | 通过 |
| 已验证工作快照 | 本机 checkout commit `7bc2f4561a9284728cb92b15b9ae9ee760abfa5c` | 通过，但仅本地 |
| 远端可恢复性 | `git branch -r --contains 7bc2f456...` 无结果 | 阻塞脚手架/CI |
| aggo | build metadata 指向 GitLab module `v0.9.24+dirty` | 必须重建 |
| gendb | build metadata 指向 GitLab module `v0.9.28+dirty` | 必须重建 |
| protoc-gen-go-ag* | 抽查仍引用 GitLab module | 必须全部重建 |
| GitHub 工具源码 | `tool/cmd/aggo`、`tool/cmd/gen-go-db`、`tool/cmd/protoc-gen-go-ag*` 均存在 | 可重建 |

## P0 关闭条件

1. 将确认的 GitHub 工作快照发布为远端可达的不可变 tag/ref，并记录 ref + 完整 SHA。
2. 从该 ref 重建 `aggo`、`gendb`、全部 `protoc-gen-go-ag*`。
3. 对每个二进制运行 `go version -m`，不得出现 `gitlab.allinfinance.com/aifgo/ag-core`。
4. 在干净 clone/build context 中生成最小 BFF 与领域服务，并脱离本地 go.work 编译。
5. 再执行 Kafka/Nacos/Redis/DB 兼容矩阵与故障测试。

旧的 GitLab 技术审查不属于最终提交证据；本文件是唯一技术现实性结论。
