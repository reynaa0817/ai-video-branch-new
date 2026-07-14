---
tags: [ai-video, story-1-3, responsive, playwright, ui-state]
date: 2026-07-14
title: Story 1.3 响应式状态验收证据
---

# UI-STATE-001 响应式状态验收证据

- Owner：Web 工作台团队
- 输入：React 工作台、Vite 开发服务、Playwright Chromium
- 命令：`bash scripts/verify-web-shell.sh`
- 视口：1440x1000、1100x900、900x900、390x844

## 输出摘要

- `result.tsv`：真实浏览器中的区域可见性、横向溢出、AI 共创折叠/侧滑路径和手机简单确认行为。
- `static-result.tsv`：锁定版本、React 挂载、base-aware 资源与 reduced-motion 结构检查。
- `viewport-1440.png`、`viewport-1100.png`、`viewport-900.png`、`viewport-390.png`：四类视口全页截图。

## 失败恢复

1. 从 `result.tsv` 确认失败视口，查看 Playwright 失败截图/trace。
2. 修复布局、面板开关或移动端操作后重跑命令。
3. 核对新生成的四张视口截图，不得复用旧 PASS 证据。
