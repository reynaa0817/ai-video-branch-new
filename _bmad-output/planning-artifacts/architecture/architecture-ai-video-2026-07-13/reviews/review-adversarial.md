---
tags:
  - ai-video
  - architecture
  - adversarial-review
  - reviewer-gate
date: 2026-07-14
title: AI 漫剧平台架构对抗性兼容审查
---

# AI 漫剧平台架构对抗性兼容审查

## Verdict

**FAIL — 当前 Architecture Spine 不能作为两个独立下游团队的无歧义构建契约。**

31 条 AD 已经覆盖了大多数业务不变量，但在跨服务接缝上仍允许多组“逐字合规、运行时不兼容”的实现。最高风险集中在 Attempt/Reservation 的循环创建关系、Workflow 的双唤醒入口、Manifest 的共享形状、Quality/Studio/Delivery 的确认权威，以及读模型跨聚合一致性。建议先收紧下列契约，再进入并行服务实现。

## 审查方法

本审查不假设团队粗心或违反 AD。每条发现都构造两个团队可从现有文字合理推出的实现，若两种实现均满足字面规则但无法互操作，则判定为 compatibility hole。审查范围聚焦共享数据形状、事实所有权、状态推进、确认、预算、资产、质量和读模型接缝，不重复技术选型或纯实现质量问题。

## Findings

### 1. Attempt 与 Reservation 存在循环创建和双重所有权

- **不兼容实现对 A：** Workflow 团队按 AD-20 先创建 Attempt，再用 `attempt_id` 请求 Budget 预留；Model Gateway 把该 ID 当外部请求 ID，另建自己的 Attempt 聚合。
- **不兼容实现对 B：** Model Gateway 团队按 AD-8 把 Attempt 视为自身事实；Budget 团队按 AD-11 要求已存在的 Attempt 才能幂等预留，而 Workflow 团队按 AD-20 又在预留后才“创建 Attempt”。
- **为何都字面合规：** AD-8 说“每个 Attempt 锁定”模型快照但没声明 owner；AD-11 说“以 Attempt 幂等原子预留”；AD-20 把“请求 Reservation 并创建 Attempt”并列给 Workflow；AD-1/AD-3 没有消除这一歧义。
- **后果：** 同一付费尝试出现两个 ID、预算无法绑定供应商提交、重试重复预留，或因创建先后互相等待。
- **可直接应用的收紧建议：** 在 AD-8/AD-11/AD-20 增补：`Model Gateway 是 Attempt 唯一事实拥有者；Workflow 只创建 LogicalTask/AttemptIntent 和幂等键。Model Gateway 以 AttemptIntent 原子创建 PENDING_AUTHORIZATION Attempt，并返回唯一 attempt_id 与锁定 Snapshot refs；Budget 仅以该 attempt_id 创建 Reservation；取得 Budget 签发的 SpendAuthorization 后，Model Gateway 才可提交供应商。Workflow 不持久化或复制 Attempt 状态。`

### 2. 预算授权没有跨服务可验证的单次提交凭证

- **不兼容实现对 A：** Budget 返回 `reservation_id`，Model Gateway 只检查状态为 HELD 后提交；Quote 在两次调用之间过期，但 Reservation 仍有效。
- **不兼容实现对 B：** Budget 把 Quote 到期同时视为 Reservation 到期；Model Gateway 认为确认时 Quote 有效就可在稍后提交，提交后 Budget 拒绝结算绑定。
- **为何都字面合规：** AD-11 要求 Quote 可验证且未过期，AD-20 也要求确认时 Quote 有效，却没有规定有效性检查发生在确认、预留还是供应商提交时，也没有规定 Reservation 与 Snapshot/最大责任的不可伪造绑定。
- **后果：** 无预算覆盖的外部费用、合法预留被拒用、重复提交共享同一预留，或确认价格与实际责任不一致。
- **可直接应用的收紧建议：** 在 AD-11 新增：`Budget 成功预留后签发单次 SpendAuthorization，至少绑定 workspace_id、attempt_id、reservation_id、quote_digest、cost_policy_digest、max_liability、currency、expires_at 与 nonce。Model Gateway 在供应商提交事务前验证并原子消费该凭证；一个凭证只能使一个 Attempt 从 PENDING_AUTHORIZATION 进入 SUBMITTING。Quote 到期不撤销已签发且未过期的 SpendAuthorization，其独立有效期由 Budget 决定。`

### 3. Kafka 事件与 Temporal Signal 允许同一事实推进两次

- **不兼容实现对 A：** Studio 在 Gate 批准事务后直接 Signal Workflow，同时 Outbox 发布 `GateApproved`；Workflow 的 Kafka bridge 再 Signal 一次。
- **不兼容实现对 B：** Studio 只发事件，Workflow 直接消费 Kafka；另一个团队按 AD-2 的“受信事件或 Signal”让 BFF/服务走直接 Signal 快路径。
- **为何都字面合规：** AD-2 明确允许“受信事件或 Signal”唤醒；AD-4 的 Inbox 约束领域消费者事务，却没有定义 Temporal Signal 的持久化收件箱、去重键和唯一入口；架构图又画了 Kafka 到 Workflow。
- **后果：** 同一 Gate 批准启动两批生成、重复请求 Reservation、或在重放时跨过一个等待点。
- **可直接应用的收紧建议：** 收紧 AD-2/AD-4：`所有外部事实只经 Workflow Ingress 进入 Temporal。Ingress 先以 event_id + target_workflow_id 持久化 WorkflowInbox，再发送带同一 dedupe_key 的 Signal；Workflow 在历史中记录已消费 key 后才推进。领域服务不得直接 Signal 业务 Workflow。若保留直接 Signal，则对应事实不得同时进入 Kafka→Workflow 路径，二者必须按事件类型静态互斥。`

### 4. Manifest 只是名称相同，没有统一身份、规范化和摘要语义

- **不兼容实现对 A：** Asset 将 `DependencyManifest` 的列表顺序视为语义无关并排序后哈希；Quality 保留输入顺序并按 protojson 字节哈希。
- **不兼容实现对 B：** Delivery 的 `ReleaseCandidateManifest` 内嵌 adopted version 列表；Studio 的 `AdoptionManifest` 只保存 slot 指针与 project version，双方都称其为“同一 Manifest”。
- **为何都字面合规：** AD-12、AD-14、AD-22、AD-23 多次要求“精确/同一 Manifest”，AD-5 只规定 Proto-first 和兼容演进，没有定义共同的 ManifestRef、canonicalization、内容摘要、成员顺序和嵌套引用闭包。
- **后果：** 相同输入被判为不同版本，或不同输入碰巧被当作同一质量证据；重做、质量失效和 Release eligibility 在服务间漂移。
- **可直接应用的收紧建议：** 新增共享契约 AD：`跨域只传不可变 ManifestRef，不共享可写 Manifest。ManifestRef 固定包含 manifest_id、manifest_type、schema_version、owner_domain、content_digest、created_at；每种 Manifest 的 owner、必填成员、排序规则、重复项规则、空值语义、引用闭包与确定性 protobuf canonicalization 在 contracts/manifest/v1 定义并做 golden-vector 兼容测试。任何“同一 Manifest”均指 manifest_id 与 content_digest 同时相等。`

### 5. WarningAcceptance、GateApproval 与 Release 确认的权威来源重叠

- **不兼容实现对 A：** Quality 拥有 WarningAcceptance，Studio 的 GateApproval 只缓存“已接受”；Delivery 查询 Quality 后创建 Release。
- **不兼容实现对 B：** Studio 在 GateApproval 内记录用户对 Warning 的接受，Quality 只产 Finding；Delivery 认为 Studio Gate 足够。两边都可援引 AD-1、AD-14、AD-23、AD-29。
- **为何都字面合规：** AD-29 定义 WarningAcceptance 字段和角色规则但没有明确 owner；AD-23 让 Studio 拥有 GateApproval；AD-14 同时要求 Warning 被接受和用户确认，却未定义 Release 使用哪一个不可变授权包。
- **后果：** 一个界面显示已批准，Delivery 却拒绝导出；更坏时，旧证据上的接受被应用到新 QualityRun。
- **可直接应用的收紧建议：** 收紧 AD-14/AD-23/AD-29：`Quality 是 Finding、Blocker 与 WarningAcceptance 的唯一事实拥有者；Studio GateApproval 只能引用精确 quality_run_id、evidence_digest 和 acceptance_ids，不复制接受事实。Studio 是创作 Gate 与 FinalReleaseConsent 的唯一 owner。Delivery 只接受由 Studio 签发的 ReleaseAuthorization，其中绑定 ReleaseCandidateManifestRef、QualityEligibilityAttestation、FinalReleaseConsent、expected adoption versions 与过期时间。`

### 6. Release 创建存在跨服务 TOCTOU 窗口

- **不兼容实现对 A：** Delivery 先读取 adopted versions，再读取 Quality，最后写 Release；读取期间用户完成一次新 Adoption。
- **不兼容实现对 B：** Delivery 接受事件投影里的“可发布”状态并写入旧 Manifest；Studio 认为只要用户曾确认该 Manifest 就合法。
- **为何都字面合规：** AD-14 要求精确 adopted versions、有效质量和用户确认，但没有给出跨 Asset/Quality/Studio 的版本绑定协议；AD-4 禁止 2PC，因此普通 read-check-write 仍然符合字面规则。
- **后果：** Release 声称基于“当前采用版本”，实际创建时已不是当前；质量证据和用户确认可能针对不同快照。
- **可直接应用的收紧建议：** 在 AD-14 增补：`创建 Release 前由 Workflow 编排 PrepareRelease Saga。Asset、Quality、Studio 分别针对同一 ReleaseCandidateManifestRef 与 expected aggregate versions 签发短期不可变 attestation；Delivery 仅在全部 attestation 的 manifest_id/content_digest 一致且未过期时创建 ReleaseVersion。任一 owner 版本变化即拒绝签发或使准备流程失败；Release 记录全部 attestation IDs。`

### 7. Asset 登记与 ModelTask 完成之间没有唯一收据协议

- **不兼容实现对 A：** Asset 接收 staging URL 后创建 ArtifactVersion 并发布事件；Model Gateway 等事件后将 ModelTask 标为 COMPLETED。
- **不兼容实现对 B：** Model Gateway 同步调用 Asset，拿到 artifact ID 就完成；Asset 的异步规范化稍后失败并 tombstone 该版本。
- **为何都字面合规：** AD-10 只说“转存、校验并由 Asset 登记候选引用后”完成；AD-13 说 Asset 唯一校验和登记，但未定义同步收据的状态、幂等键、失败终态和候选何时可被下游消费。
- **后果：** ModelTask 完成但资产不可用，或 Asset 已登记而 Model Gateway 永久停在 TRANSFERRING；重试可能生成重复 ArtifactVersion。
- **可直接应用的收紧建议：** 收紧 AD-10/AD-13：`Asset 以 attempt_id + provider_result_id + checksum 作为登记幂等键，仅在对象已进入 canonical key、checksum/媒体探测通过且 ArtifactVersion 状态为 AVAILABLE 后签发 ArtifactRegistrationReceipt。Receipt 绑定 artifact_version_id、checksum、normalized_metadata_digest。Model Gateway 只有持久化该 Receipt 后才能把 ModelTask 置为 COMPLETED；重复请求必须返回同一 Receipt。`

### 8. Quality 失效依赖事件及时性，间接 stale 可漏过发布门

- **不兼容实现对 A：** Quality 只按 AD-12 监听“直接引用变化”失效 QualityRun；Asset 的 DependencyManifest 将下游标为 stale，但事件延迟。
- **不兼容实现对 B：** Quality 每次查询 DependencyManifest 递归判断 stale；Delivery 只检查 QualityRun 自身状态，未检查当前依赖闭包。
- **为何都字面合规：** AD-12 的直接引用失效与 AD-22 的边传播并存，但没有规定 Release eligibility 必须基于内容寻址的完整依赖闭包，也没有规定 stale 传播完成前能否签发质量资格。
- **后果：** 已失效的画面、字幕或音轨仍携带 PASS 的 QualityRun 进入 Release。
- **可直接应用的收紧建议：** 在 AD-12/AD-14/AD-22 增补：`QualityRun 必须绑定完整输入闭包的 manifest content_digest；QualityEligibilityAttestation 只能在 Quality 当前重算该 digest 与 ReleaseCandidateManifestRef 一致、且闭包内无 stale 节点时签发。事件驱动 invalidation 只用于提示和加速，不能作为发布正确性的唯一保障。`

### 9. `expected_current_version` 没有指定是哪一个版本

- **不兼容实现对 A：** Web 把当前 `artifact_version_id` 作为 expected_current_version；Asset 把字段解释为 AssetSlot 的 `aggregate_version`。
- **不兼容实现对 B：** Studio 使用 project aggregate_version 防并发；Asset 对多 slot AdoptionManifest 使用每个 slot 的版本向量。
- **为何都字面合规：** AD-6 同时存在实体 ID、aggregate_version、内容 revision 和采用指针；AD-7 使用未定型的 `expected_current_version`；AD-22 又引入 expected current manifest。
- **后果：** 合法采用被持续冲突拒绝，或并发采用静默覆盖；跨多个 slot 的局部重做无法判断原子前置条件。
- **可直接应用的收紧建议：** 收紧 AD-7/AD-22：`单 slot AdoptionCommand 必须携带 slot_id、expected_slot_aggregate_version、expected_adopted_artifact_version_id 与 target_artifact_version_id。多 slot AdoptionManifest 必须携带按 slot_id 排序的完整 ExpectedAdoptionVector；Asset 在一个本地事务中验证并原子切换全部指针，任一项不匹配则全部拒绝。禁止使用 project_version 代替 slot 并发版本。`

### 10. ProjectExperienceView 的“单调游标”不能表达跨聚合一致快照

- **不兼容实现对 A：** 投影团队用 Kafka offset 作为全局游标，但各 domain topic/partition 的 offset 不可比较；SSE 看似单调，快照却可能混合新预算与旧 Gate。
- **不兼容实现对 B：** 团队用投影数据库自增 revision，能续传 UI 更新，但无法证明该 view 已包含各 owner 的哪个 aggregate_version。
- **为何都字面合规：** AD-21 只要求版本化 View、单调游标和“明确陈旧”，没有定义投影 owner、per-source watermark、一致性边界和 UX status 的确定性归并表。
- **后果：** 用户在看见错误的 consumed/held/remaining 或待确认状态时发出命令；两个 BFF 实例给出不同“下一成果”。
- **可直接应用的收紧建议：** 在 AD-21 增补：`ProjectExperience Projection 是该 View 的唯一 owner。每个 ViewRevision 必须携带 project_id、projection_revision、source_watermarks{domain, aggregate_id, aggregate_version/event_id}、computed_at 与 staleness_reason；UX status 和优先级使用版本化 ExperiencePolicy 的穷举映射。SSE cursor 只标识投影日志位置，不宣称 Kafka 全局顺序。所有写命令仍必须携带 owner aggregate 的 expected version，并由事实 owner 校验。`

### 11. Money 允许两种表示，跨服务必然出现舍入分歧

- **不兼容实现对 A：** Model Gateway 的 PricingQuote 使用 Decimal 主单位并支持小数成本；Budget 按 AD-11 使用最小货币单位整数，四舍五入后预留。
- **不兼容实现对 B：** 一个服务把 JPY 视为 0 位小数，另一个统一按两位；protojson 仍可传字符串或数字，契约演进检查不会发现语义差异。
- **为何都字面合规：** AD-11 明确允许“最小货币单位或定点 Decimal”，没有指定共享 Money 类型、舍入模式、精度、币种指数与比较语义。
- **后果：** Quote、最大责任、Reservation 和 Ledger 无法精确相等，造成少预留、对账尾差或幂等摘要变化。
- **可直接应用的收紧建议：** 收紧 AD-5/AD-11：`所有跨服务金额只使用唯一 Money proto：currency_code(ISO 4217) + minor_units(int64) + currency_exponent(int32)，禁止 JSON number、float 和服务私有 Decimal。所有报价计算在进入契约前按版本化 RoundingPolicy 转为 Money；同一 attempt 的 quote/reservation/cost fact 必须币种和 exponent 完全一致。`

### 12. Notification Projection 同时被定义为可重建投影和 read/ack 事实源

- **不兼容实现对 A：** 通知团队把 read/ack 存在投影表，重建时从领域事件恢复任务但丢失用户已读状态。
- **不兼容实现对 B：** 团队发布 `NotificationRead` 作为自身事实事件，因此事实上创建了新的写模型和事实 owner；另一个团队按 AD-1 的七个核心服务列表拒绝依赖它。
- **为何都字面合规：** AD-31 要求持久化 read/ack，又说“该投影可重建”；AD-1 没有为交互回执分配 owner；AD-21 的 pending decisions 与 AD-31 的任务也没有共享 canonical task ID。
- **后果：** 已处理任务重新出现、跨设备已读状态丢失，或 ProjectExperienceView 与通知中心对同一 Gate 给出不同待办。
- **可直接应用的收紧建议：** 收紧 AD-1/AD-21/AD-31：`Notification Projection 仍为派生视图；用户 read/ack 由 Studio 拥有不可变 InteractionReceipt（或明确新增 Notification Context 为事实 owner），并通过事件参与重建。所有待办使用 canonical DecisionTaskRef{task_type, owner_domain, aggregate_id, aggregate_version, decision_id}；ProjectExperienceView 与 Notification Projection 只能投影同一 DecisionTaskRef，不各自产生任务身份。`

### 13. Proto “兼容新增”不足以约束枚举、缺省值与语义兼容

- **不兼容实现对 A：** 发布方新增 enum 值；Go 消费方将未知值落为数值并拒绝，TypeScript 消费方把它当默认状态继续推进。
- **不兼容实现对 B：** 发布方新增一个默认值为零的布尔/枚举字段并赋予业务含义；旧消费者把“字段缺失”和“明确 false/UNSPECIFIED”视为相同。
- **为何都字面合规：** AD-5 允许 v1 兼容新增，但没有规定 `UNSPECIFIED`、unknown enum、field presence、reserved field、语义变更和 consumer-driven compatibility。
- **后果：** 相同事件在 Workflow、投影和领域服务中产生不同状态，且 schema compatibility 测试仍然通过。
- **可直接应用的收紧建议：** 在 AD-5 增补：`所有业务 enum 的 0 值必须为 *_UNSPECIFIED 且消费者 fail-closed；新增 enum 值必须先证明旧消费者安全处理。具有缺失语义的 scalar 使用 optional/oneof；删除字段和枚举号必须 reserved。CI 除 buf breaking 外，必须运行 producer/consumer golden vectors 与 unknown-field/unknown-enum 测试；字段语义、单位或状态含义变化视为破坏性变更并发布 v2。`

## 必须先收紧的最小集合

在不扩展系统范围的前提下，进入并行实现前至少应把以下内容写回 Architecture Spine 或其规范性契约：

1. AttemptIntent → Attempt → SpendAuthorization → provider submit 的唯一 owner 和顺序。
2. Workflow Ingress 的唯一事件入口及持久化去重协议。
3. ManifestRef、Money、ExpectedAdoptionVector、ArtifactRegistrationReceipt 的共享 Proto 形状与 golden vectors。
4. QualityEligibilityAttestation + FinalReleaseConsent + ReleaseAuthorization 的权威链。
5. ProjectExperienceView 的 owner、source watermarks、ExperiencePolicy 与写命令并发版本规则。

完成这五项后，剩余问题可通过契约测试和 feature-level 设计逐步关闭；未完成前让团队并行实现，会把架构歧义固化为跨服务兼容债务。
