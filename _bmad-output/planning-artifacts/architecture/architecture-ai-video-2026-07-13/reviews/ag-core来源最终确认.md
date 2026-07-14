---
tags:
  - ai-video
  - architecture
  - ag-core
  - correction
date: 2026-07-14
title: ag-core 来源最终确认
status: superseded
superseded_by: ../../sprint-change-proposal-2026-07-14-ag-core基线纠偏.md
---

# ag-core 来源最终确认

> **历史材料，已被 2026-07-14 Correct Course 纠偏。** 本文中的本机 SHA 只记录当时调查现场，不是用户批准的发布版本，也不得作为 BASE-001 不变量。规范规则以 Architecture Spine、技术基线锁定和纠偏提案为准。

ai-video 的框架与工具链统一采用 GitHub 版 ag-core：

- 规范 remote：`https://github.com/aif-go/ag-core.git`
- 本机核验 checkout：`/Users/zhangyong/Downloads/ag-core`
- module：`github.com/aif-go/ag-core`
- 已验证工作快照：`7bc2f4561a9284728cb92b15b9ae9ee760abfa5c`，当前尚无远端分支包含，不是可恢复 CI 锁
- Go：`1.25.0`

明确排除 `/Users/zhangyong/Desktop/ag-core` 的 GitLab 版。

当前技能目录中的已安装工具仍不能作为 GitHub 版工具链放行。实施前须从规范远端可达提交/tag 或受审 PR merge SHA 中选择候选，通过 clean-build/provenance preflight 后发布不可变 ref，再从该 ref 重建 `aggo`、`gendb` 与全部 `protoc-gen-go-ag*`，并用 `go version -m` 验证 module 来源后再执行脚手架。
