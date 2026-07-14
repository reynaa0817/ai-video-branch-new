---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-ai-video-2026-07-13/AI漫剧创作平台-完整PRD.md
  - _bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/系统架构说明.md
  - _bmad-output/planning-artifacts/architecture/architecture-ai-video-2026-07-13/技术基线锁定.md
  - _bmad-output/planning-artifacts/ux-designs/ux-ai-video-2026-07-13/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-ai-video-2026-07-13/EXPERIENCE.md
---

# ai-video - Epic Breakdown

## Overview

本文将 ai-video 的 PRD、UX 设计契约和架构决策分解为可实施的 Epic 与 Story。

## Requirements Inventory

### Functional Requirements

- FR1：创作者可创建作品项目、以自然语言提交 idea、设置硬预算上限，并可指定或交由系统推断题材、受众、风格、集数和单集时长。
- FR2：系统生成可修改、可锁定、可追溯的创意锚点与创意简报，并区分用户原始设定和 AI 扩写。
- FR3：系统在正式生产前以受控预算生成概念样片，允许用户保留、修改或丢弃方向，只有确认内容才能进入后续锁定设定。
- FR4：创作者可用自然语言对文字、角色、画面、镜头、声音或成片反馈，系统生成可预览、可确认、可撤销的修改候选。
- FR5：系统规划多集短剧结构，支持用户调整集数与时长，并重新评估故事完整性、悬念兑现和预算影响。
- FR6：系统生成故事大纲、角色设定、剧本、分镜和镜头清单，保证故事弧完整且台词和关键信息可映射到产物。
- FR7：系统在故事与角色、分镜与样片等关键闸门请求确认，未确认不得启动依赖它的高成本生成，并允许随时暂停。
- FR8：系统维护创作宪法与连续性账本，在生成前注入约束、生成后定位冲突，锁定设定不得被静默修改。
- FR9：系统建立可版本化、可复用、可追溯引用的角色、服装、场景、道具、声音、动作和风格剧组资产。
- FR10：系统在故事包、剧组资产、动态镜头和内部验证版本阶段执行创意匹配与连续性检查，并保留问题处理证据。
- FR11：系统在概念样片和正式生产前展示计划、成本区间及预算余量，以最大计费责任预留预算，在 70%/90% 提醒、100% 停止新增付费任务，未经授权不得越界。
- FR12：管理员可按工作流节点配置版本化的模型提供方、版本、参数、凭证、配额、质量档位及合规的主备策略。
- FR13：系统持久化并恢复长流程状态与产物，保证重复请求不产生不可识别的重复任务或重复扣费，并展示进度、成本和阻塞原因。
- FR14：系统并行执行互不依赖任务，根据依赖关系计算最小重做范围，复用输入、配置和质量状态未变化的结果。
- FR15：系统以剧组资产和连续性约束生成完整动态正式镜头，持续提供预览并记录输入、模型配置、成本与质量状态。
- FR16：系统识别供应商失败、超时、不可用输出和连续性不合格，以有限且受预算与质量约束的策略恢复，失败后保留成功产物并说明选项。
- FR17：系统生成或接入配音、配乐、音效和字幕，保持与镜头关联，并允许独立替换问题音轨或字幕。
- FR18：系统自动组装覆盖完整故事弧的粗剪，支持定位到集、镜头、台词或时间点的局部修改，并经创作者确认后进入最终质量检查。
- FR19：系统在内部验证版本确认前执行 QG-1 至 QG-6，阻断项不可覆盖，并记录确认人、时间、证据和实际总成本。
- FR20：授权内部创作者可按统一规格受控导出内部验证版本；导出前必须完成权利声明、保留 AI 标识并记录审计信息，MVP 不直接公开发布。
- FR21：系统维护原著、角色、肖像、声音、音乐、字体等项目授权台账，并把授权状态关联到资产、镜头和发布版本。
- FR22：系统在适用阶段附加并保留显式 AI 标识和隐式元数据，导出前验证标识完整性。
- FR23：系统保留阶段产物、模型配置、用户确认、预算变更、质量、授权与异常处置审计记录，普通创作者不可覆盖。
- FR24：外部商业化准备阶段支持内容审核、投诉、申诉、违规处置和紧急下架，并具备责任人、时限和审计状态。
- FR25：外部商业化准备阶段支持按渠道和规则版本维护标识、内容、规格与备案要求，并阻止不合规发布。

### NonFunctional Requirements

- NFR1：作品、阶段任务和产物状态必须持久化，进程、页面或会话中断后可恢复。
- NFR2：同一已接受付费请求不得因重复提交产生重复任务或重复扣费。
- NFR3：供应商 API 成功不等于业务成功，只有通过对应质量检查才进入下游。
- NFR4：内部阶段工作流控制面月可用性目标为 99.5%，不包含外部模型供应商不可用时间。
- NFR5：除生成任务外，Web 主要交互 p95 响应时间不超过 2 秒。
- NFR6：长任务期间用户可离开或继续使用 Web，界面持续展示进度、影响、成本和可操作状态。
- NFR7：Web 按 WCAG 2.1 AA 核心要求设计并在外部发布前经 UX 验证。
- NFR8：模型凭证和供应商密钥不得暴露给普通创作者。
- NFR9：真实人物肖像、可识别声音和授权材料按敏感数据限制访问并记录使用。
- NFR10：项目数据、模型输入输出和审计记录的保留、删除与训练使用策略必须可配置。
- NFR11：敏感素材只能发给数据条款获批、承诺禁训练且具备保留和删除传播能力的供应商。
- NFR12：内部项目删除后，平台控制范围内的敏感原始素材应在 30 天内删除，并跟踪供应商删除请求及结果。
- NFR13：普通创作者不得修改管理员模型配置或生产审计记录。
- NFR14：每个任务记录供应商、模型与配置版本、耗时、尝试次数、成本、失败原因和质量结果。
- NFR15：运营人员可按作品、阶段、模型和失败类型查看质量、效率与成本指标。
- NFR16：供应商异常必须在有限尝试后进入可解释暂停或人工接管，禁止无限重试或持续扣费。

### Additional Requirements

- 实施采用七个领域事实服务、Web BFF、体验投影、Provider/Media Worker 的独立 Go Module 边界；禁止共享业务表、跨服务 SQL 和跨服务内部包引用。
- Temporal 是唯一流程推进器；Kafka 仅传递已持久化事实，Signal 必须经持久化 WorkflowInbox 和统一 bridge 去重进入工作流。
- 跨服务一致性采用 orchestration-first Saga 与事务 Outbox/Inbox；所有消费者按至少一次传输设计。
- 同步 API 和事件 Proto-first、兼容演进，业务 enum 以 `UNSPECIFIED` 为零值并 fail-closed，CI 必须执行 breaking 与 golden vector 检查。
- 作品阶段、生命周期、内容修订、资产采用、模型尝试、预算预留、质量运行和发布版本分别建模，不使用一个组合状态机承载全部事实。
- 生成候选、质量证据、确认和发布版本不可变追加；“生成完成”不得自动替换当前采用版本。
- 所有模型和 AI 评价调用只能经 Model Gateway，Attempt 必须锁定 ModelConfigSnapshot、PricingQuote 和 CostPolicySnapshot。
- 供应商提交结果必须区分 `NOT_ACCEPTED`、`ACCEPTED` 和 `UNKNOWN`；`UNKNOWN` 进入对账且不得盲目重放。
- 外部结果只有转存到 canonical object、完成 checksum/媒体探测并取得资产登记回执后，才能标记平台任务完成。
- 金额统一使用 ISO 4217 Money Proto 的整数 minor units；付费 Attempt 必须先预留最大责任、消费单次授权，再提交和按 ProviderCostFact 结算。
- 质量运行必须绑定完整输入 Manifest digest、规则集和证据版本；任一输入变化使旧证据失效，AI 语义结论需指定人工角色复核后才能成为阻断。
- Asset 服务独占媒体规范化、canonical key、不可变版本和血缘；字幕、混音、转码和封装都产生新版本。
- Release 与 Export 分离且不可变；创建 ReleaseVersion 前必须校验 Studio、Asset、Quality 针对同一 Manifest 的有效证明。
- 浏览器只持 Secure HttpOnly SameSite Session Cookie；OIDC token 留在 BFF，领域服务从可信身份推导 workspace 并做资源级授权。
- 敏感数据删除通过 Studio、Asset、Model Gateway 的可验证 Saga 完成，并遵守法定保留与已发布版本引用约束。
- 指标只从领域事实构建只读投影，成功、放弃、预算终止、治理阻断和系统失败全部进入分母。
- Budget、并发控制、质量闸门或对象持久化不可用时必须 fail-closed，停止新增付费推进。
- 高成本自然语言动作必须先形成不可变 ChangeProposal/ImpactPlan，用户对仍有效的范围、版本、报价和最大责任显式确认后才能扣费。
- Web 只消费 `experience-projection` 的统一 `ProjectExperienceView`；SSE 只传投影游标，写命令仍携带事实 owner 的 expected version。
- 依赖图和版本化 DependencyManifest 决定失效传播、最小重做和结果复用；相关资产采用通过 Manifest 原子切换。
- 五类常规 Gate 固定为创意简报、故事与角色、分镜与样片、粗剪、内部版本；Gate 与项目状态变更在 Studio 同一事务持久化。
- MVP 内部交付 Profile 固定为 9:16、1080×1920、30fps、MP4/H.264、AAC 48kHz、字幕烧录和独立字幕、可见标识与可验证元数据。
- 模型回退必须满足版本化 CapabilityContract，证明输入输出、完整动态、连续性和合规兼容，否则暂停而非静默降级。
- 暂停只停止新调度；已 `ACCEPTED`/`UNKNOWN` 的 Attempt 继续对账、转存和结算，但不自动采用或推进。
- 数据库、Proto、事件、Temporal Workflow、镜像和配置采用 expand-migrate-contract 双版本兼容窗口。
- 在实施脚手架前必须关闭 P0 技术基线：发布可远端恢复的 GitHub ag-core immutable ref，重建无 GitLab 依赖的生成工具链，并锁定 Temporal、Kafka、Nacos/Redis、FFmpeg、Web 与 Kubernetes 的精确兼容证据。
- 首个技术闭环必须打通 Quote → Reservation → Submit → Reconcile → Asset → Quality → Adoption，然后再扩展故事、声音、后期与 Release。

### UX Design Requirements

- UX-DR1：实现桌面优先的深色电影感工作台，使用 DESIGN.md 的颜色、字体、圆角与 4px 间距 token；MVP 不以简单反色实现浅色主题。
- UX-DR2：作品中心直接提供 idea 输入和预算上限，作品卡展示实际预览、创意锚点、当前阶段、下一成果、状态、预算和更新时间，并按待决定优先排序。
- UX-DR3：实现顶部作品状态栏，持续展示保存状态、已消耗/已预留/剩余预算、暂停/继续、最新预览和待决策事项。
- UX-DR4：实现六阶段轨道，区分当前、完成、可预览、待确认、阻断和未开始状态；允许历史只读回看，修改前先做影响分析。
- UX-DR5：当前产出画布按创意、故事、视觉、制作、后期和成片阶段切换成果形态，并对每个产物展示来源、版本、锁定状态和修改入口。
- UX-DR6：实现固定结构的页面内确认闸门卡，展示成果、AI 行为、用户判断、下一阶段成本和时间，以及具体的确认、修改、暂停动作；禁止小模态框承载复杂闸门。
- UX-DR7：AI 共创面板必须绑定当前产物，展示作用范围、锁定设定与影响摘要；含糊反馈一次只追问一个问题，高成本动作必须二次确认。
- UX-DR8：实现默认折叠的生产任务抽屉，摘要展示生成数量、下一预览和已预留金额，展开显示任务、尝试、成本和失败原因。
- UX-DR9：实现预算条的已消耗、已预留、剩余三段视觉及 70%/90% 标记；100% 后显示新增付费任务已暂停，并同时提供金额、占比与原因。
- UX-DR10：视频预览保持 9:16，提供高对比控制、字幕、键盘播放和持续可见的 AI 生成内容标识，质量问题说明不得遮挡问题画面。
- UX-DR11：实现分镜/时间线的当前镜头、候选版本和质量状态，以及原版与候选同步播放、单帧对齐的 A/B 对比。
- UX-DR12：状态不能只靠颜色表达，必须同时提供图标、标题和文本；阻断卡必须展示原因、安全成果、最小影响、预算、已尝试策略和具体选项。
- UX-DR13：按钮文案必须描述结果和成本，例如“确认故事并继续”“只重做镜头 08（预计 ¥X）”，每个确认区域最多一个主要动作。
- UX-DR14：新成果预览、版本采用与完成动效遵循 160–600ms 的克制规范；`prefers-reduced-motion` 时禁用非必要光扫、位移和自动过渡。
- UX-DR15：响应式实现覆盖 ≥1280px 完整三栏、1024–1279px 可折叠共创、768–1023px 审阅与轻修改、<768px 查看/播放/简单确认，不承诺手机完整编辑。
- UX-DR16：键盘支持全局导航、产物打开、`Space` 播放/暂停、方向键时间细调、`Esc` 关闭顶层浮层、`Cmd/Ctrl+Enter` 提交反馈。
- UX-DR17：实现 WCAG 2.1 AA 核心门禁，包含可见焦点、合理焦点顺序、非颜色单一编码、44×44 触控目标、字幕与文本关联、节制的 `aria-live`。
- UX-DR18：生成候选和采用候选必须是两个动作，原版持续可看，采用后可撤销；上游变化时明确标记下游 stale 及原因。
- UX-DR19：作品级辅助区域必须提供创作设定、剧组资产、版本记录和制作详情，普通创作者看到业务解释，管理员可深入技术明细。
- UX-DR20：质量门卡按 QG-1 至 QG-6 分项展示证据、提醒、阻断和覆盖权限，并在创作者提交创意匹配评分与权利声明后计算最终资格。
- UX-DR21：可视化文案使用共同创作者语气，说明作品成果、后果和下一步，不直接暴露供应商错误码或以抽象“工作流成功/失败”替代用户含义。

### FR Coverage Map

FR1：Epic 1 - 创建带硬预算的作品项目。
FR2：Epic 1 - 形成可锁定、可追溯的创意简报。
FR3：Epic 1 - 生成并确认受控预算概念样片。
FR4：Epic 1 - 用自然语言形成可撤销修改候选。
FR5：Epic 2 - 规划完整的多集故事结构。
FR6：Epic 2 - 生成可生产的故事包。
FR7：Epic 2 - 在故事与视觉方向闸门显式确认。
FR8：Epic 2 - 维护创作宪法和连续性账本。
FR9：Epic 2 - 建立并复用版本化剧组资产。
FR10：Epic 2 - 检查连续性与创意匹配。
FR11：Epic 3 - 在预算护栏内计划和估价生产。
FR12：Epic 3 - 管理员配置可替换且有质量边界的模型节点。
FR13：Epic 3 - 持久化、恢复并解释长流程任务。
FR14：Epic 3 - 并行生产、最小重做与安全复用。
FR15：Epic 3 - 生成可持续预览的完整动态正式镜头。
FR16：Epic 3 - 在供应商故障时有限恢复且不损失成功产物。
FR17：Epic 4 - 生成和局部替换声音与字幕。
FR18：Epic 4 - 自动组装并确认故事完整的粗剪。
FR19：Epic 5 - 以 QG-1 至 QG-6 验证内部版本。
FR20：Epic 5 - 按统一规格受控导出内部版本。
FR21：Epic 5 - 维护内部版本需要的项目授权台账。
FR22：Epic 5 - 保留并验证 AI 生成内容标识。
FR23：Epic 5 - 保存可追溯且不可篡改的生产审计。
FR24：Epic 6 - 在商业化阶段处理投诉、申诉、违规处置和紧急下架。
FR25：Epic 6 - 在商业化阶段维护并执行渠道规则。

## Epic List

### Epic 1：让创意第一次“活起来”

创作者可以从一句 idea 创建受预算保护的作品，确认 AI 扩写边界，并看到、评价和局部修改第一支概念样片。此 Epic 同时物化可独立构建的最小技术基线和单次付费生成闭环，为后续能力提供可运行底座。

**FRs covered:** FR1、FR2、FR3、FR4

### Epic 2：把方向变成完整且一致的可生产故事

创作者可以确认多集故事弧、角色和分镜，锁定不可擅自改变的设定，并建立可复用的剧组资产；故事包在进入批量生产前已具备完整性、创意匹配和连续性证据。

**FRs covered:** FR5、FR6、FR7、FR8、FR9、FR10

### Epic 3：在预算与质量护栏内持续生成整部动态作品

创作者可以批准一份可解释的生产计划，让镜头在后台并行生成、持续预览和中断恢复；供应商失败、重复请求或预算临界不会导致重复扣费、静默降级或丢失成功成果。

**FRs covered:** FR11、FR12、FR13、FR14、FR15、FR16

### Epic 4：形成可局部修正的完整粗剪

创作者可以观看包含配音、配乐、音效和字幕的完整故事粗剪，并把问题精确定位到镜头、音轨、字幕或时间点，只重做和采用受影响部分。

**FRs covered:** FR17、FR18

### Epic 5：确认并受控导出可信内部版本

创作者和内部审核人员可以针对同一不可变版本审阅 QG-1 至 QG-6、授权、标识、成本与生产证据；只有所有阻断关闭后才能确认并按统一规格受控导出。

**FRs covered:** FR19、FR20、FR21、FR22、FR23

### Epic 6：为外部商业化建立可执行治理闭环

运营、法务与治理人员可以维护渠道规则，处理投诉、申诉、违规账号和紧急下架，使外部版本在明确责任、时限和审计证据下发布与处置。本 Epic 建立在内部版本闭环之上，但其治理功能可独立验收，且不反向阻塞 MVP 内部试产。

**FRs covered:** FR24、FR25

## Epic 1：让创意第一次“活起来”

创作者可以从一句 idea 创建受预算保护的作品，确认 AI 扩写边界，并看到、评价和局部修改第一支概念样片。此 Epic 同时物化可独立构建的最小技术基线和单次付费生成闭环，为后续能力提供可运行底座。

### Story 1.1：锁定可恢复的 ag-core 与生成工具基线（架构 P0）

As a 平台研发人员,
I want 从远端不可变 GitHub ref 可重复构建 ag-core 和全部生成工具,
So that 后续服务脚手架和 CI 不依赖本机快照或旧 GitLab 工具链。

**Acceptance Criteria:**

**Given** 规范 GitHub remote 与候选选择规则已确认
**When** 从远端可达 immutable version 选择 root dependency，并对现有远端候选或受审 PR merge SHA 完成 clean-build preflight
**Then** 将最终 tool source 与 root dependency 的 ref/version+SHA 写入签署 manifest，且所有二进制 `go version -m` 仅引用 `github.com/aif-go/ag-core`
**And** 任一候选在冻结前必须已从规范远端可恢复；本机 checkout SHA 只作调查证据，不得成为发布基线。

**Given** 任一工具仍包含 `gitlab.allinfinance.com/aifgo/ag-core` 或 ref 不可远端获取
**When** 执行基线门禁
**Then** CI 明确失败且禁止生成服务脚手架
**And** 不得用本地 replace 或 go.work 掩盖失败。

### Story 1.2：锁定全栈 P0 技术基线（架构 P0）

As a 平台研发与架构负责人,
I want 为运行平台所需的基础设施和工具建立可恢复、可回滚、可验证的精确基线,
So that 平台骨架、CI 和 internal-prod 不依赖猜测版本或仅在单机成立的组合。

**Acceptance Criteria:**

**Given** Story 1.1 的远端工具链基线已通过
**When** 锁定 Temporal Server/SDK/schema、Kafka/agsarama、Nacos/Redis、对象存储、FFmpeg、Node/Web lockfile 与 Kubernetes 发行版
**Then** 每项记录精确版本或镜像 digest、许可证、兼容矩阵、配置来源和 owner
**And** 未锁定项保持 P0 阻塞，不得以 latest、浮动 tag 或本地缓存放行。

**Given** 候选技术组合已部署到干净 integration 环境
**When** 执行启动、契约、故障注入、升级、回滚和恢复验收
**Then** 保存可重复命令、金样、日志/trace、RPO/RTO 与失败证据
**And** Budget、对象持久化、质量门或编排不可用时验证 fail-closed。

**Given** Web 与媒体工具链准备放行
**When** 执行独立构建和金样验证
**Then** Node 镜像和 lockfile 可重复安装，FFmpeg 输出满足内部 DeliveryProfile、字幕、字体和 AI 标识要求
**And** Story 1.3 只有在本 Story 全部 Gate 通过后才能执行完整脚手架与 internal-prod 放行。

### Story 1.3：建立可独立构建的最小平台骨架（架构 AD-1～AD-5、AD-19）

As a 平台研发人员,
I want 建立 Web、BFF、核心服务、体验投影和 Worker 的独立构建边界及最小契约,
So that 团队可以在统一事实所有权与兼容演进规则下并行开发。

**Acceptance Criteria:**

**Given** Story 1.1 与 Story 1.2 的 P0 技术基线均已通过
**When** 初始化 monorepo 结构和首版 Proto/事件 Envelope
**Then** 每个服务是独立 Go Module、镜像和部署单元，Web 有锁定依赖，CI 脱离根 go.work 可分别构建
**And** 不存在跨服务 SQL、共享业务表、跨服务 internal import 或手改生成代码。

**Given** Proto 或事件契约发生变更
**When** 执行 CI
**Then** breaking、unknown enum/field 和 golden vector 测试运行
**And** 破坏性变更必须以新版本并行发布。

**Given** local 集成环境启动
**When** 执行健康检查与最小事件往返
**Then** BFF、领域服务、Temporal、Kafka、MySQL、对象存储和体验投影可观测
**And** 日志与 trace 不包含密钥、token、媒体 URL 或敏感提示词原文。

**Given** Web 工作台骨架启动
**When** 在桌面、平板和手机验收全局导航与基础组件
**Then** 使用 DESIGN.md 的深色 token、六阶段布局骨架和明确焦点样式，并按 UX 响应式边界重排
**And** 自动检查对比度、键盘导航、非颜色单一编码、触控目标和 reduced-motion 基线。

**实施拆分要求：** 创建实施 Story 文件时必须按序拆为三个原子任务，并为每项保存独立输入、验收命令、失败恢复和完成证据：

1. 仓库、Proto、事件契约与独立构建；
2. local 基础设施、可观测性与最小事件往返；
3. Web shell、设计 token、响应式与 WCAG 门禁。

### Story 1.4：创建受硬预算保护的作品项目（FR1）

As a 内部创作者,
I want 用一句 idea 和预算上限创建作品项目,
So that 我无需影视专业配置即可开始且任何付费生成都有明确上限。

**Acceptance Criteria:**

**Given** 已认证且有 workspace 权限的创作者位于作品中心
**When** 输入 idea、预算上限并选择填写或交由 AI 推断其他字段
**Then** 系统保存原始 idea、预算上限、用户指定约束和项目身份，返回可恢复的作品工作台
**And** 在预算未持久化前不得启动任何付费任务。

**Given** 用户省略集数、时长、题材或风格
**When** 创建项目
**Then** 项目仍可创建且省略字段标记为待推断
**And** 用户指定值优先于后续推断。

**Given** 重复提交相同创建请求或 expected version 冲突
**When** 服务处理请求
**Then** 返回同一项目或明确并发冲突，不创建重复项目
**And** 作品中心通过统一体验投影显示当前状态、下一成果和三段预算。

### Story 1.5：生成并锁定创意简报（FR2）

As a 内部创作者,
I want 查看和确认原始设定与 AI 扩写分离的创意简报,
So that AI 可以大胆发展故事但不能静默改变我的核心意图。

**Acceptance Criteria:**

**Given** 已创建的项目包含原始 idea
**When** 系统生成创意锚点、受众、题材、风格和核心冲突
**Then** 画布区分“用户原始设定”和“AI 新增内容”，原始 idea 始终可追溯
**And** 生成结果作为不可变候选，不自动成为锁定设定。

**Given** 用户修改并确认创意简报
**When** 通过 `CREATIVE_BRIEF` Gate
**Then** Studio 在同一事务保存精确 Manifest、确认人、时间、expected version 和锁定项
**And** 之后的生成必须引用该版本的创意锚点与创作约束。

**Given** 用户尝试修改已锁定内容
**When** 系统计算影响
**Then** 先展示受影响范围和候选变更，不直接覆盖当前版本
**And** 用户可取消并保留原版本。

### Story 1.6：以预算二次授权生成概念样片（FR3）

As a 内部创作者,
I want 在看见用途、最大成本和预算占比后生成概念样片,
So that 我能尽早判断创意是否值得继续而不承担失控费用。

**Acceptance Criteria:**

**Given** 创意简报已确认且模型配置可用
**When** 用户请求生成样片
**Then** 系统先创建含锁定输入、影响范围、预计时长、最大计费责任、Quote 到期时间和 expected versions 的 ChangeProposal/ImpactPlan
**And** 自然语言请求本身不会预留预算或提交供应商。

**Given** 用户在报价和版本仍有效时显式确认
**When** 工作流执行 Quote → Reservation → Authorization consumption → Submit → Reconcile → Asset registration → Quality
**Then** 每一步按 attempt_id 幂等，金额使用整数 minor units，供应商结果转存并验证后才成为可预览候选
**And** 已消耗与活动最大责任之和不超过预算上限。

**Given** 报价过期、输入版本变化、预算不足或供应商提交为 `UNKNOWN`
**When** 工作流处理
**Then** 不盲目提交或重放；报价/版本变化要求重新确认，预算不足保持暂停，`UNKNOWN` 保持预留并进入对账
**And** 界面解释已消耗、已预留、剩余与下一可用动作。

**Given** 样片候选通过基础媒体和质量检查
**When** 创作者查看结果
**Then** 可选择保留、修改或丢弃，未确认内容不得升格为锁定设定
**And** 预览保持 9:16、可键盘播放、有字幕能力和持续 AI 标识。

### Story 1.7：用自然语言生成可撤销修改候选（FR4）

As a 内部创作者,
I want 对当前文字、角色、画面或声音直接描述感受并比较修改候选,
So that 我不用模型参数或影视术语也能控制创意方向。

**Acceptance Criteria:**

**Given** 用户选择了具体产物并输入自然语言反馈
**When** 系统解析反馈
**Then** AI 共创面板显示作用范围、引用的锁定设定、修改意图和影响摘要
**And** 含糊反馈一次只提出一个与当前上下文最相关的问题。

**Given** 修改会产生付费任务
**When** 用户审阅修改方案
**Then** 必须展示最大成本、预计等待和不受影响内容，并再次显式确认后才执行
**And** 原版在候选生成、检查和比较期间继续作为当前采用版本。

**Given** 候选生成完成
**When** 用户比较结果
**Then** 可以确认采用、撤销、丢弃或再次修改
**And** 所有采用与撤销都追加记录，不覆盖历史版本。

## Epic 2：把方向变成完整且一致的可生产故事

创作者可以确认多集故事弧、角色和分镜，锁定不可擅自改变的设定，并建立可复用的剧组资产；故事包在进入批量生产前已具备完整性、创意匹配和连续性证据。

### Story 2.1：规划可兑现的多集故事弧（FR5）

As a 内部创作者,
I want 让系统建议集数、时长和每集目标并解释完整故事弧,
So that 我不懂剧作结构也能确认故事会讲完而不是连续挖坑。

**Acceptance Criteria:**

**Given** 概念方向已确认
**When** 系统生成多集规划
**Then** 故事画布展示总故事弧、每集目标、主要冲突、结尾方式和承诺兑现状态
**And** 默认规则满足每 10 集最多 3 集高潮切断、连续强悬念不超过 1 集、每 3 集至少兑现一次阶段性承诺且故事弧结局完整。

**Given** 用户修改集数或单集时长
**When** 系统重新规划
**Then** 先展示故事完整性、预算和已存在下游候选的影响
**And** 原规划保留至用户采用新候选。

### Story 2.2：生成可追溯的故事包（FR6）

As a 内部创作者,
I want 获得故事大纲、角色设定、剧本、分镜和镜头清单,
So that 确认后的故事可以直接驱动后续资产与镜头生产。

**Acceptance Criteria:**

**Given** 多集结构已采用
**When** 系统生成故事包
**Then** 每个关键情节、台词和声音需求可映射到具体集、场景、镜头或音频产物
**And** 故事弧具备开端、冲突、推进和兑现，不以未兑现悬念代替结局。

**Given** 用户定位修改某集、角色或伏笔
**When** 系统生成候选修订
**Then** DependencyManifest 标识直接和传递影响范围，未受影响内容保持可复用
**And** 候选未采用前不改变当前故事包。

### Story 2.3：确认故事、角色与分镜方向（FR7）

As a 内部创作者,
I want 在完整页面中浏览成果、影响、成本后确认故事与视觉方向,
So that 高返工批量生产不会越过我的关键决定。

**Acceptance Criteria:**

**Given** 故事大纲与角色候选已完成预检
**When** 用户进入 `STORY_AND_CHARACTER` Gate
**Then** 页面展示成果、AI 做了什么、用户需要判断什么、下一阶段成本与时间，以及“确认并继续/告诉 AI 怎么改/暂时停下”
**And** Gate 不是模态弹窗，确认绑定精确 Manifest、质量证据、actor 和 expected project version。

**Given** 分镜、镜头清单和样片候选已完成
**When** 用户进入 `STORYBOARD_AND_SAMPLE` Gate
**Then** 可浏览、播放、比较并确认采用版本
**And** Gate 未通过时不得启动依赖它的高成本批量镜头生产。

### Story 2.4：维护创作宪法与连续性账本（FR8）

As a 内部创作者,
I want 锁定角色、关系和世界规则并查看跨阶段连续性,
So that 后续生成不会无提示改变我确认过的设定。

**Acceptance Criteria:**

**Given** 用户确认故事与角色
**When** 系统形成创作宪法和连续性账本
**Then** 原始设定、AI 扩写、锁定项、当前剧情事实和关联版本可查询
**And** 每次生成前引用相关约束，生成后记录冲突与关联产物。

**Given** 新指令与锁定设定冲突
**When** 用户提交修改
**Then** 系统明确冲突并让用户选择只改当前内容或正式修改设定
**And** 正式修改设定前展示受影响剧集、资产、镜头、成本和需重检范围。

**Given** 检测到影响理解的连续性冲突
**When** 工作流尝试推进
**Then** 受影响产物标记 stale 并阻断自动进入下一阶段
**And** 只有修复或经明确修改宪法后重新检查才能解除。

### Story 2.5：建立版本化剧组资产与显式采用（FR9）

As a 内部创作者,
I want 建立并复用角色、服装、场景、道具、声音、动作和风格资产,
So that 多集多镜头保持一致且历史产物可追溯。

**Acceptance Criteria:**

**Given** 故事包已确认
**When** 系统生成剧组资产候选
**Then** 每项资产以不可变 ArtifactVersion 保存来源、配置、checksum、媒体元数据和父子血缘
**And** 同一角色跨镜头默认引用已确认的同一 AssetSlot 采用版本。

**Given** 用户采用一个或多个候选资产
**When** Asset 服务处理 AdoptionCommand/Manifest
**Then** 校验所有 expected slot version 和当前采用版本后在单个本地事务全验全改
**And** 任一冲突时全部拒绝，不产生半新半旧状态。

**Given** 历史资产已被故事包、镜头或 Release 引用
**When** 用户请求删除或覆盖
**Then** 系统禁止直接破坏历史版本并说明引用关系
**And** 新修改创建新版本，旧版本继续可追溯。

### Story 2.6：执行故事、资产与分镜质量门（FR10）

As a 内部审核人员,
I want 对精确版本的故事、创意匹配和连续性运行分项质量门,
So that 批量生产只使用已通过且证据未失效的输入。

**Acceptance Criteria:**

**Given** 故事包或资产 Manifest 已形成
**When** 运行 QG-1、QG-2、QG-3 及适用的 QG-4 预检
**Then** QualityRun 锁定完整输入 digest、规则集、评估器与证据版本，并分别输出提醒和阻断
**And** 自动确定性检查可阻断，AI 语义判断必须经指定人工角色复核后才能成为阻断。

**Given** 任一被引用输入、规则或评估器版本变化
**When** 系统校验旧 QualityRun
**Then** 旧证据标记失效且不得用于新 Gate
**And** 必须创建新的运行而不是改写旧结果。

**Given** 用户尝试接受质量提醒
**When** Quality 服务处理 WarningAcceptance
**Then** 按 QG-1 至 QG-4 的角色和覆盖策略验证权限并保存 actor、scope、reason、time 与 evidence
**And** 阻断项永远不能通过提醒接受接口绕过。

## Epic 3：在预算与质量护栏内持续生成整部动态作品

创作者可以批准一份可解释的生产计划，让镜头在后台并行生成、持续预览和中断恢复；供应商失败、重复请求或预算临界不会导致重复扣费、静默降级或丢失成功成果。

### Story 3.1：配置具备能力与合规边界的模型策略（FR12）

As a 模型管理员,
I want 版本化配置节点模型、配额、价格、凭证和主备能力,
So that 普通创作者无需技术配置且回退不会破坏质量、预算或数据政策。

**Acceptance Criteria:**

**Given** 管理员有相应资源权限
**When** 发布 ModelProfile、ConfigSnapshot、CapabilityContract、QuotaPolicy 和 FallbackPolicy
**Then** 配置版本不可变、凭证只在 Secret Manager，普通创作者不可见且不可修改
**And** 已运行 Attempt 继续使用锁定快照，不受后来配置变更影响。

**Given** 任务包含敏感素材
**When** Model Gateway 选择供应商
**Then** 必须校验 DataPolicySnapshot 的禁训练、保留、删除传播、区域和供应商资格
**And** 任一条件不满足时 fail-closed，不能把素材发送出去。

**Given** 主模型不可接受请求
**When** 策略考虑备用模型
**Then** 仅在提交结果为 `NOT_ACCEPTED` 且输入输出、完整动态、连续性、元数据和合规能力均兼容时新建 Attempt
**And** 不兼容时暂停并向用户解释，不得静默降级。

**实施拆分要求：** 创建实施 Story 文件时必须按序拆为三个原子任务，并为每项保存独立验收证据：

1. 模型配置、PricingQuote、QuotaPolicy 与 CostPolicy 快照；该切片是 Story 3.2 的前置 Gate；
2. CapabilityContract 与 FallbackPolicy；
3. DataPolicySnapshot 与 ProviderEligibilityPolicy。

### Story 3.2：批准可解释且不会越界的生产计划（FR11）

As a 内部创作者,
I want 在正式生产前看到阶段、生成量、成本区间和最大预算责任,
So that 我能在明确投入和质量底线后批准生产。

**Acceptance Criteria:**

**Given** 故事、分镜与剧组资产已确认，且 Story 3.1 已发布仍有效的模型、价格、配额、成本与供应商资格快照
**When** 系统计算生产计划
**Then** 展示镜头/声音/后期数量、预览与正式生成、预计重试、阶段时长、已消耗/已预留/剩余和最大总责任
**And** 估价来源于版本化 PricingQuote、CostPolicy 与舍入策略。

**Given** 多个任务将并行入队
**When** Budget 原子预留责任
**Then** 以 `settled + active max liability` 统一判断预算，不允许分别通过后共同越界
**And** 无法证明最大计费责任的任务在硬预算项目中不得自动启动。

**Given** 预算跨过 70%、90% 或达到 100%
**When** 账本状态变化
**Then** 70%/90% 各发布一次单调提醒，100% 停止新增付费任务
**And** 界面同时展示金额、比例、原因和不破坏故事/设定/完整动态底线的可选调整。

### Story 3.3：持久化编排并恢复长流程（FR13）

As a 内部创作者,
I want 关闭页面、会话过期或服务重启后生产仍能安全继续,
So that 长时间生成不会丢失成果、重复任务或重复扣费。

**Acceptance Criteria:**

**Given** 生产计划已批准
**When** Workflow 启动并跨服务推进
**Then** Temporal 只保存流程游标、等待、引用与补偿状态，业务事实仍由各领域服务拥有
**And** 所有领域事件先持久化再发布，Workflow Signal 经 WorkflowInbox 和 dedupe key 唯一进入。

**Given** 页面关闭、Worker 重启、事件重复或服务短暂不可用
**When** 系统恢复
**Then** 从最近持久化事实继续，相同 idempotency key 返回同一业务结果
**And** 不产生不可识别的重复任务、重复采用或重复扣费。

**Given** 用户返回工作台
**When** 体验投影加载快照并续接 SSE
**Then** 展示已完成成果、正在执行、下一预览、阻塞原因和三段预算，而不是无法解释的单一百分比
**And** 投影陈旧时显示 staleness reason，不自行推进工作流。

**实施拆分要求：** 创建实施 Story 文件时必须按序拆为两个原子任务：

1. 领域事实到 Outbox/Inbox、WorkflowInbox/Signal Bridge 和 Temporal 的可恢复推进与故障注入；
2. ProjectExperienceView、SSE 游标、断线恢复与 staleness reason。

前者通过后才能接入后者；两项分别保存恢复、重复事件和断线场景证据。

### Story 3.4：并行生产、暂停与最小重做（FR14）

As a 内部创作者,
I want 独立镜头并行生成且修改只重做必要范围,
So that 我能持续看到作品形成并避免无效成本。

**Acceptance Criteria:**

**Given** 依赖图中存在互不依赖的镜头或声音任务
**When** Workflow 调度
**Then** 在配额、并发和预算预留允许范围内并行执行，并持续登记已完成候选
**And** 任务抽屉展示数量、下一预览、尝试、成本与失败原因。

**Given** 输入、配置、规则、工具和锁定结果均未变化
**When** 同一结果再次被请求
**Then** 复用已有可用 ArtifactVersion 并记录来源，不重新调用供应商
**And** 无效重生成成本可被 SM-12 指标识别。

**Given** 用户暂停、预算暂停、质量阻断或工作流停滞
**When** 系统处理暂停
**Then** 只停止新调度；`ACCEPTED`/`UNKNOWN` Attempt 继续对账、转存与结算但不自动采用
**And** 恢复时使用持久化游标和最新领域 expected versions。

**Given** 上游候选被采用
**When** 计算最小重做范围
**Then** 仅标记受影响的下游版本 stale，已锁定且依赖未变化的结果保持可用
**And** 执行前展示范围、新增成本与预计等待。

### Story 3.5：生成并持续预览完整动态镜头（FR15）

As a 内部创作者,
I want 看到整部作品的正式镜头逐步成为可播放的完整动态视频,
So that 我能持续确认作品进展且最终不会被静态替代品降级。

**Acceptance Criteria:**

**Given** 正式镜头任务具备已确认分镜、资产和连续性约束
**When** Worker 调用已授权模型并取得结果
**Then** 结果转存为 canonical object，完成 checksum、媒体探测和 ArtifactRegistrationReceipt 后才标记任务完成
**And** 每个镜头记录输入、配置、供应商结果、成本、血缘和质量状态。

**Given** 正式镜头进入资产库
**When** 运行 QG-2 和 QG-4
**Then** 静态推拉、动态漫画、主体崩坏、不可播放或缺失被阻断
**And** 轻微偏差只能按指定双角色接受策略处理。

**Given** 部分镜头已完成而其他镜头仍运行或失败
**When** 用户查看制作画布
**Then** 已完成镜头可独立预览且不因其他失败失效
**And** 页面优先展示可播放成果、下一可见成果和局部缺口。

### Story 3.6：有限恢复供应商失败与未知提交（FR16）

As a 内部创作者,
I want 供应商超时、失败或输出不合格时系统安全恢复并解释结果,
So that 我不会因无限重试、重复提交或静默降级失去预算和成果。

**Acceptance Criteria:**

**Given** 供应商提交调用返回明确拒绝、明确受理或结果未知
**When** Model Gateway 持久化提交结果
**Then** 状态严格为 `NOT_ACCEPTED`、`ACCEPTED` 或 `UNKNOWN`
**And** `UNKNOWN` 禁止自动重放并保持预算进入对账，`NOT_ACCEPTED` 才可按策略新建备用 Attempt。

**Given** 供应商已受理但回调丢失、临时 URL 过期或转存失败
**When** 恢复任务运行
**Then** 通过供应商任务身份对账并重试获取/转存，不重新生成
**And** 转存失败保持 `TRANSFERRING`，成功后重复登记返回同一 Receipt。

**Given** 自动恢复达到版本化有限尝试边界
**When** 仍无法获得合格产物
**Then** 进入可解释暂停或人工接管，展示原因、受影响镜头、已消耗/已预留/剩余、已尝试策略和具体选项
**And** 其他成功镜头继续可用，禁止无限尝试、持续扣费或降低完整动态/连续性底线。

**Given** 供应商最终结算超过已验证最大责任
**When** ProviderCostFact 入账
**Then** 用户作品成本不突破其预算上限，异常差额单独记录为平台责任
**And** 未消耗预留在取消、失败或结算后释放且可追溯。

## Epic 4：形成可局部修正的完整粗剪

创作者可以观看包含配音、配乐、音效和字幕的完整故事粗剪，并把问题精确定位到镜头、音轨、字幕或时间点，只重做和采用受影响部分。

### Story 4.1：生成并关联配音、音乐、音效与字幕（FR17）

As a 内部创作者,
I want 每个镜头获得可独立管理的配音、音乐、音效和字幕,
So that 音频或字幕问题可以单独修正而不重做画面。

**Acceptance Criteria:**

**Given** 动态镜头和故事包台词映射可用
**When** 系统生成或接入声音与字幕
**Then** 每条台词、音轨、字幕 cue 与镜头/时间范围建立版本化关联
**And** 视频模型原始音频不合格时可替换音轨而不要求重做画面。

**Given** 音频、字幕、混音或封装发生变更
**When** Asset 处理结果
**Then** 创建引用父版本和 recipe/tool snapshot 的新 ArtifactVersion
**And** 原始媒体和历史采用关系不被覆盖。

### Story 4.2：自动组装故事完整的可播放粗剪（FR18）

As a 内部创作者,
I want 系统自动把镜头、声音和字幕组装成完整粗剪,
So that 我可以按作品而不是零散任务判断故事和节奏。

**Acceptance Criteria:**

**Given** 所需镜头、音轨和字幕已达到可组装状态
**When** Media Worker 按故事包和版本化 recipe 组装粗剪
**Then** 输出不可变粗剪候选及完整血缘，覆盖故事弧且不存在无法解释的剧情缺口
**And** 播放器支持字幕、键盘控制、9:16 安全区和持续 AI 标识。

**Given** 某依赖缺失或被标记 stale
**When** 尝试组装或采用粗剪
**Then** 明确阻断并定位到具体集、镜头、台词或资产
**And** 不用占位黑场或静态替代品伪装完整粗剪。

### Story 4.3：定位问题并生成局部后期候选（FR14、FR17、FR18）

As a 内部创作者,
I want 在播放位置选择镜头、台词、声音或字幕并用一句话修改,
So that 我只支付和等待受影响部分的重做。

**Acceptance Criteria:**

**Given** 用户在播放器、分镜条或字幕行选择反馈锚点
**When** 提交自然语言修改
**Then** 系统复述意图并列出直接与传递影响、继续使用的锁定设定、最大成本和预计时间
**And** 未选择作用范围时先确认范围，不直接执行。

**Given** 用户显式批准付费局部修改
**When** 工作流执行
**Then** 只新建受影响画面、配音、字幕或混音任务，其他已确认内容不重新生成
**And** 原粗剪在候选完成前保持当前采用版本。

### Story 4.4：A/B 对比、采用并确认粗剪（FR14、FR18）

As a 内部创作者,
I want 同步比较原版与候选并原子采用满意修改,
So that 时间线不会出现半新半旧且我可以撤销决定。

**Acceptance Criteria:**

**Given** 局部候选及关联质量结果已生成
**When** 用户进入 A/B 对比
**Then** 支持同步播放、单帧对齐、台词差异、成本和质量结果并列
**And** 候选通过检查也不会自动采用。

**Given** 用户采用候选
**When** Asset 处理 AdoptionManifest
**Then** 画面、音轨和字幕对 expected current manifest 原子切换，任一版本冲突时全部拒绝
**And** 撤销通过追加采用记录恢复先前组合。

**Given** 用户进入 `ROUGH_CUT` Gate
**When** 审阅 QG-1、QG-3、QG-5 和下一阶段影响后确认
**Then** Studio 保存精确粗剪 Manifest、证据、确认人和时间
**And** 未确认或存在阻断时不得进入内部验证版本检查。

## Epic 5：确认并受控导出可信内部版本

创作者和内部审核人员可以针对同一不可变版本审阅 QG-1 至 QG-6、授权、标识、成本与生产证据；只有所有阻断关闭后才能确认并按统一规格受控导出。

### Story 5.1：维护项目授权台账与敏感素材状态（FR21）

As a 内部内容负责人,
I want 记录原著、角色、肖像、声音、音乐、字体和素材授权,
So that 内部版本的每项受保护内容都有可验证来源和处理状态。

**Acceptance Criteria:**

**Given** 项目使用受保护或敏感素材
**When** 负责人登记授权
**Then** 保存权利来源、适用范围、状态、有效期、证据引用和审批人，并关联引用它的资产、镜头和候选版本
**And** 真实人物肖像、可识别声音或第三方素材未获内部批准时阻止用于导出。

**Given** 授权撤回、过期或项目请求删除
**When** 系统处理状态变化
**Then** 标记所有关联产物并阻止新 Release/Export，启动可验证删除 Saga
**And** 法定保留、调查保全或已有 Release 引用优先于物理删除且状态对授权人员可见。

**Given** 平台控制范围内敏感原始素材符合删除条件
**When** 项目删除满 30 天内
**Then** 完成 tombstone/物理删除并跟踪供应商删除请求和回执
**And** 仅保留不含敏感内容的审计证明。

### Story 5.2：对同一候选运行最终 QG-1 至 QG-6（FR19）

As a 内部审核人员,
I want 对精确的成片候选分项审阅故事、创意、连续性、动态、音画字幕和技术权利,
So that 总分不能掩盖任何不可覆盖的发布阻断。

**Acceptance Criteria:**

**Given** 粗剪已确认且 ReleaseCandidateManifest 已形成
**When** 运行最终质量检查
**Then** QG-1 至 QG-6 各自保存规则、输入 digest、证据、Finding、人工复核和状态
**And** 任一输入或规则变化使相关运行失效并触发重检。

**Given** 创作者提交 1–5 分创意匹配评分
**When** Quality 计算 QG-3
**Then** 低于 3 分或锁定锚点缺失为不可覆盖阻断，3 分仅创作者本人可接受提醒
**And** 评分、文字反馈和接受记录进入版本证据。

**Given** 用户尝试覆盖提醒或阻断
**When** 系统检查 QG 策略
**Then** 仅允许规定角色接受规定提醒，QG-6 和所有 Blocker 不可覆盖
**And** UI 同时展示证据、影响、角色要求和修复动作，状态不只靠颜色表达。

### Story 5.3：确认不可变内部 ReleaseVersion（FR19、FR23）

As a 内部创作者,
I want 在质量、授权、成本和版本都一致时确认内部验证版本,
So that 最终作品不会在确认后被后台变化悄悄替换。

**Acceptance Criteria:**

**Given** QG-1 至 QG-6 无阻断且最小权利声明已完成
**When** 用户进入 `INTERNAL_RELEASE` Gate
**Then** 页面优先提供整片/分集播放，并展示质量摘要、实际总成本、阶段成本、重试成本和可用视频秒成本
**And** 确认保存 actor、time、Manifest、quality runs、warning acceptances、rights state、expected versions 和 FinalReleaseConsent。

**Given** Workflow 编排 PrepareRelease Saga
**When** Asset、Quality、Studio 签发短期证明
**Then** Delivery 只在所有证明的 manifest id/digest 一致、未过期且版本仍匹配时创建不可变 ReleaseVersion
**And** 任一不一致或过期都拒绝创建并指明需刷新内容。

### Story 5.4：按统一规格和 AI 标识受控导出（FR20、FR22）

As a 已授权内部创作者,
I want 独立导出已确认的内部验证版本,
So that 我获得规格一致、带标识且可审计的内部文件而不会改变 Release。

**Acceptance Criteria:**

**Given** 不可变 ReleaseVersion 已存在且账号具备导出权限
**When** 请求导出
**Then** 依据同一版本化 DeliveryProfile 校验或转码为 9:16、1080×1920、30fps、MP4/H.264、AAC 48kHz
**And** 字幕同时烧录并提供独立文件，持续可见 AI 标识和可验证元数据均通过完整性检查。

**Given** 文件不可播放、规格不符、标识缺失、权利声明不完整或账号无权
**When** 执行 QG-6/Export
**Then** 拒绝导出且不可覆盖，说明精确阻断
**And** 转码产生新资产版本，不改变已确认 Release 的内容 Manifest。

**Given** 导出成功
**When** Delivery 完成任务
**Then** 新建独立 ExportRecord，记录导出人、时间、Release、Profile、checksum 和结果
**And** 页面明确标注“内部验证版本，尚未公开发布”。

### Story 5.5：提供不可篡改审计与全样本运营指标（FR23）

As a 内部运营人员,
I want 追溯每个项目的生产、成本、质量和最终结果并查看分层指标,
So that 团队可以用完整样本判断质量、效率和单位经济性。

**Acceptance Criteria:**

**Given** 项目、任务、Attempt、质量、确认、授权、Release 或 Export 状态变化
**When** 领域服务保存事实
**Then** 审计记录关联 workspace、project、workflow、logical task、attempt、release 和 trace，普通创作者不可覆盖
**And** 内部审计记录至少保留 180 天，敏感原文遵循最小化与保留策略。

**Given** 运营人员查看数据看板
**When** 选择作品、阶段、模型、失败类型或复杂度层
**Then** 展示质量、p50/p95 时长、阶段/重试/单位成本、完成率和三角联合通过率
**And** 成功、用户放弃、预算终止、治理阻断和系统失败全部进入分母。

**Given** 前 20 部连续样本达到校准条件
**When** 冻结内部目标
**Then** 按预先固定的复杂度 Snapshot 计算各层 p75，第 21 部前保存不可变 MetricPolicySnapshot
**And** 单层少于 5 部不得宣称完成校准，阈值调整必须作为新版本变更审计。

**实施拆分要求：** 创建实施 Story 文件时必须按序拆为三个原子任务：

1. 不可篡改生产审计与关联 ID；
2. 只读运营投影与全样本分母；
3. Cohort、Complexity 与 MetricPolicy 快照及第 21 部前冻结。

## Epic 6：为外部商业化建立可执行治理闭环

运营、法务与治理人员可以维护渠道规则，处理投诉、申诉、违规账号和紧急下架，使外部版本在明确责任、时限和审计证据下发布与处置。本 Epic 建立在内部版本闭环之上，但其治理功能可独立验收，且不反向阻塞 MVP 内部试产。

### Story 6.1：版本化维护外部渠道与标识规则（FR25）

As a 内容治理运营人员,
I want 按地区和渠道维护标识、内容、规格、备案与许可规则,
So that 每个外部发布候选都使用明确且可追溯的规则版本。

**Acceptance Criteria:**

**Given** 法务和渠道负责人提供已确认规则
**When** 运营人员发布渠道规则版本
**Then** 保存适用地区、渠道、标识、内容、规格、备案/许可、阻断条件、生效时间和审批证据
**And** 已发布规则不可改写，修订创建新版本。

**Given** 外部候选选择目标渠道
**When** 执行渠道资格检查
**Then** 记录所用规则版本并逐项输出通过、提醒或阻断
**And** 未满足当前阻断规则的候选不得发布。

**Given** 规则更新影响既有发布内容
**When** 系统重新评估
**Then** 不改写历史发布记录，只创建需复核或下架任务
**And** 任务具有责任人、截止时间和审计状态。

**Given** 阶段 C 需要验收既有外部发布内容的规则复核、冻结或下架
**When** 授权运营人员通过受控后台登记或导入 PublishedContentRecord
**Then** 系统保存不可变的外部内容、ReleaseVersion、渠道、外部标识/链接、首次发布时间、当前状态和来源证据
**And** 重复导入幂等、普通创作者无权写入，且该接口不触发自动公开发布。

### Story 6.2：处理投诉、申诉与违规处置（FR24）

As a 内容治理人员,
I want 接收、分派、调查和裁决投诉与申诉,
So that 外部内容和账号问题在明确责任与时限内得到一致处理。

**Acceptance Criteria:**

**Given** 用户或外部方提交投诉
**When** 系统受理
**Then** 创建含内容/账号引用、类型、证据、严重度、SLA、责任人和状态的不可变案件
**And** 敏感证据按最小权限访问并记录每次查看和操作。

**Given** 治理人员裁决处置或用户申诉
**When** 状态推进
**Then** 每个决定保存依据、actor、time、适用规则版本和通知结果
**And** 重复请求幂等，越权用户不能修改案件或审计记录。

### Story 6.3：执行紧急下架与防重复传播（FR24、FR25）

As a 值班治理人员,
I want 对严重违规内容执行可审计的紧急冻结和下架,
So that 既有链接、导出入口和重复发布不能继续传播风险内容。

**Acceptance Criteria:**

**Given** 案件达到紧急下架条件且操作人具备权限
**When** 执行冻结/下架命令
**Then** 原子标记相关发布版本、账号和渠道状态，禁止新访问、导出和重复发布
**And** 记录命令、规则、证据、actor、time、执行结果和待完成外部渠道动作。

**Given** 外部渠道下架回执延迟或失败
**When** 系统跟踪处置
**Then** 以有限重试和人工升级保持可见责任，不将内部成功误报为端到端完成
**And** 所有尝试、失败原因、升级和最终回执可审计。

**Given** 申诉裁决允许恢复
**When** 授权人员解除处置
**Then** 创建新的恢复决定并重新执行现行渠道规则检查
**And** 不删除或改写原始下架历史。
