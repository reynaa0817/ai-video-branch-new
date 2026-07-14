---
tags: [ai-video, story-1-3, a11y, playwright, axe]
date: 2026-07-14
title: Story 1.3 无障碍验收证据
---

# A11Y-001 无障碍验收证据

- Owner：Web 工作台团队
- 输入：`web/src/`、`web/public/`、Playwright Chromium、axe-core
- 命令：`bash scripts/verify-web-shell.sh`
- 视口：1440x1000、1100x900、900x900、390x844

## 输出摘要

`result.tsv` 由 Playwright reporter 在每次执行开始时先写入 `NOT_RUN`，再逐项更新为 `PASS`/`FAIL`，不会沿用上次 PASS。当前覆盖：

- 四类视口 axe 扫描（含对比度规则）。
- 键盘焦点路径：全局导航 → 六阶段轨道 → 主画布 → AI 共创 → 任务抽屉。
- 所有可见交互目标 computed box 不小于 44x44。
- `prefers-reduced-motion` 实际 computed style。

## 失败恢复

1. 查看 `result.tsv` 中的 `FAIL` 项和 Playwright 终端 trace 路径。
2. 修复 DOM/可访问名称/CSS 后重跑命令。
3. 只有 `result.tsv` 全部为 `PASS` 才可更新 Story 证据。
