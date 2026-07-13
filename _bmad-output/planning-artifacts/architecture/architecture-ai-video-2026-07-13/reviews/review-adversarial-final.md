---
tags:
  - ai-video
  - architecture
  - adversarial-review
  - final-gate
date: 2026-07-14
title: AI 漫剧平台架构对抗性最终复核
---

# AI 漫剧平台架构对抗性最终复核

## Verdict

**FAIL — 必须最小集合已大部分关闭，但仍有 2 个 Critical、1 个 High 阻塞 final。**

最新 Spine 已关闭上一版关于 Attempt 唯一归属与主顺序、ManifestRef、Money、ExpectedAdoptionVector、ArtifactRegistrationReceipt、质量发布资格、体验投影水位、Notification read/ack 和 Proto 演进的主要漏洞。以下仅列仍可使两个逐字遵守 AD 的团队产生不兼容实现的阻塞项。

## Blocking Findings

### Critical 1 — AD-2 与 AD-23 对 Workflow Signal 的规则直接冲突

- **证据：** AD-2 规定所有外部事实只能经 `workflow-signal-bridge` 进入 Temporal，并明确禁止领域服务直接 Signal；AD-23 又规定 Studio 在批准与 Project 状态同事务持久化后“向 Workflow 发 Signal”。
- **仍可出现的不兼容实现：** Workflow 团队只接受 bridge 写入 WorkflowInbox 后发送的 Signal；Studio 团队按 AD-23 直接调用 Temporal。前者会拒绝后者，或 Studio 同时写 Outbox 和直发 Signal，重新引入同一 Gate 推进两次。
- **阻塞原因：** 这正是上一版必须最小集合中的“Workflow Ingress 唯一入口”。文本自身矛盾意味着该项尚未关闭。
- **直接收紧：** 将 AD-23 后半句替换为：`批准与 Project 状态转换在 Studio 同一事务持久化，并写出唯一 GateApproved Outbox 事件；只有 workflow-signal-bridge 可将该事件写入 WorkflowInbox 并 Signal。Studio、BFF 和其他领域服务不得直接 Signal。`

### Critical 2 — 付费 Proposal 的确认事实没有唯一 owner，也没有进入唯一 Signal 链

- **证据：** AD-20 定义不可变 ChangeProposal/ImpactPlan 和“显式确认后 Workflow 创建 AttemptIntent”，但 AD-1 的事实拥有者表没有 ChangeProposal、ImpactPlan、ProposalConfirmation；AD-20 也没有规定确认由哪个服务与 expected versions/Quote 状态在同一事务持久化、通过哪个事实事件唤醒 Workflow。
- **仍可出现的不兼容实现：** Studio 团队把 Proposal 与确认当项目事实并发布事件；Workflow 团队把 BFF 的确认请求当 Workflow 命令直接创建 AttemptIntent；Model Gateway 团队则可能把 Proposal 视为模型调用产物。三种实现都没有逐字违反现有 AD，但确认审计、幂等和版本校验无法互认。
- **阻塞原因：** AD-20 的安全目标是防止自然语言直接扣费。若确认只是一次未归属的调用而不是持久化事实，重试、并发或服务恢复都可能绕过或重复使用授权。
- **直接收紧：** 在 AD-1 将 `ChangeProposal、ImpactPlan、ProposalConfirmation` 明确归 Studio；在 AD-20 增补：`Studio 在一个事务中验证 proposal_id、expected project/adoption versions、quote digest/expiry，追加 ProposalConfirmation 与 Outbox 事件。Workflow 仅在 workflow-signal-bridge 投递该事实后，以 confirmation_id 幂等创建 AttemptIntent；BFF 不得直接命令 Workflow 创建 AttemptIntent。`

### High 1 — SpendAuthorization 的唯一拥有者与“原子消费”落点仍是双解

- **证据：** AD-1 把 SpendAuthorization 归 Budget；AD-11/AD-20 又要求 Model Gateway “原子消费”后提交，但没有说明消费是修改 Budget 的授权状态，还是 Model Gateway 在 Attempt 本地记录一次使用，也没有定义两者失败时的权威结果。
- **仍可出现的不兼容实现：** Budget 团队提供 `ConsumeAuthorization` RPC 并以自身状态为唯一已用事实；Model Gateway 团队则把 `authorization_id/nonce` 原子写入 Attempt 并直接提交，Budget 只根据后续事件获知。两边都可解释为满足“单次、原子消费”，但 API、恢复与对账协议不兼容。
- **阻塞原因：** 该接缝直接控制外部付费副作用。消费落点不唯一会造成授权已用但未提交、已提交但 Budget 仍显示可用，或恢复时重复提交。
- **直接收紧：** 明确采用单一模式：`SpendAuthorization 是 Budget 签发的不可变 capability，不在 Budget 侧变更为 consumed。Model Gateway 在自己的 Attempt 事务中验证绑定与过期时间，并以 authorization_id + nonce 唯一约束原子记录授权使用，同时把 Attempt 从 PENDING_AUTHORIZATION 变为 SUBMITTING；该 Attempt 转换是唯一消费事实。Budget 只消费 AttemptAuthorizationUsed/ProviderCostFact 事件更新投影和结算，不提供第二个 Consume RPC。` 若选择 Budget 远程消费模式，则必须反向删除 Model Gateway“原子消费”措辞，并定义提交前后故障恢复协议；两种模式不可并存。

## Final Gate Condition

修正上述三处后，可判定上一版“必须先收紧的最小集合”关闭，并进入 final。其余上一版发现已经由 AD-1、AD-2、AD-5、AD-7、AD-10..AD-14、AD-21、AD-29、AD-31..AD-33 足够约束，不再作为本 Gate 的阻塞项。
