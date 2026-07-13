---
tags:
  - ai-video
  - architecture
  - adversarial-review
  - final-gate
date: 2026-07-14
title: AI 漫剧平台架构对抗性最终定点复核（二）
---

# AI 漫剧平台架构对抗性最终定点复核（二）

## Verdict

**FAIL — 2 项已关闭，SpendAuthorization 消费恢复仍有 1 个 High 阻塞。**

## 定点结果

- **PASS，Signal 冲突已关闭：** AD-23 已改为 Studio 同事务持久化并经 Outbox 发布事实，且只能由 `workflow-signal-bridge` 转为 Signal，与 AD-2 的唯一 Workflow Ingress 一致。
- **PASS，提案 owner 已关闭：** AD-1 已将 ChangeProposal、ImpactPlan、ProposalConfirmation 明确归 Studio；AD-20 规定确认在 Studio 持久化并发布事实，经唯一 Workflow Ingress 推进。
- **FAIL，授权消费权威仍未完全关闭：** AD-1 和 AD-11 已选择 Budget 为 SpendAuthorization/Receipt 的权威 owner，方向正确；但 AD-11 允许重复消费“返回同一回执或明确拒绝”。若 Budget 已从 `ISSUED` 提交为 `CONSUMED`，但回执响应在 Model Gateway 持久化前丢失，重试若被“明确拒绝”，Model Gateway 永远拿不到提交供应商所需回执，Reservation 和 Attempt 将永久卡死。返回同一回执与拒绝是两个不兼容且恢复性质不同的实现，仍未满足远程消费模式的故障恢复要求。

## 唯一剩余修复

将 AD-11 的“重复消费返回同一回执或明确拒绝”收紧为：

`ConsumeSpendAuthorization 以 attempt_id + authorization_id + nonce 为幂等键。首次成功时 Budget 在同一事务将授权从 ISSUED 转为 CONSUMED 并持久化不可变 SpendAuthorizationReceipt；相同幂等键的所有重试必须返回同一回执。只有绑定字段不一致、授权未签发、已过期或已被不同幂等键消费时才返回明确拒绝。`

应用这句后，三个定点阻塞项均可判定关闭。
