---
tags:
  - ai-video
  - architecture
  - reviewer-gate
  - technology-reality
date: 2026-07-14
title: AI 漫剧创作平台架构技术现实性审查
---

# AI 漫剧创作平台架构技术现实性审查

## Verdict

**CONDITIONAL PASS — 技术组合成立，没有发现不存在的核心技术或被官方 memlog 明确判定过时的目标版本；但当前 Stack 仍是“候选基线”，不是可复现构建基线。ag-core 来源与 patch、Temporal Server/SDK、Kafka/agsarama、Nacos/Redis、FFmpeg 镜像及 Kubernetes patch 必须完成 P0 锁定后，才能进入内部生产。**

本 Gate 不允许联网。核验依据仅包括：

- 当前 `ARCHITECTURE-SPINE.md`；
- 2026-07-14 架构 `.memlog.md` 中标记为官方核验的记录；
- 本地 ag-core 技能文档；
- 本地 `/Users/zhangyong/Desktop/ag-core` 源码、tag 与 `go.mod`；
- 本机只读工具版本和项目锁文件检查。

结论标签：

- **已核验**：有 2026-07-14 官方 memlog 或本地源码直接证据；
- **受本地框架约束**：技术存在且可用，但必须服从 ag-core 当前模块、SDK 或生成链边界；
- **必须 P0 锁定**：尚无精确版本、镜像 digest 或端到端兼容性证据，不能直接投产。

## 最高优先级发现

### 1. [P0] ag-core 的系列方向正确，但来源与精确版本存在漂移

**置信度：10/10。** Spine 只写 `ag-core 0.9.x`。本地权威候选 `/Users/zhangyong/Desktop/ag-core` 使用模块 `gitlab.allinfinance.com/aifgo/ag-core`、Go `1.24.8`，存在 `v0.9.51` tag；但 ag-core 技能 Notes 仍写“当前版本 v0.9.23”，迁移示例又使用 `v0.9.25`。同时 `/Users/zhangyong/Downloads/ag-core` 是另一个 `github.com/aif-go/ag-core`、Go `1.25.0`、alpha tag 的实现，不能混用。

这不是文案差异。选错仓库会同时改变 module path、Go 基线和 contribute 模块版本。P0 必须固定：Git remote/module path、tag、commit SHA、Go toolchain、每个 contribute 模块版本，并在干净容器中逐服务脱离 `go.work` 构建。当前最有本地证据的候选是 `gitlab.allinfinance.com/aifgo/ag-core@v0.9.51`，但 Gate 不替代兼容性测试作最终决定。

### 2. [P0] Kafka 4.x 是官方存在的版本线，但 agsarama 适配尚未成立

**置信度：10/10。** 2026-07-14 memlog 核验了 Kafka `4.3.1/4.2.1/4.1.2` 的官方支持状态；本地 ag-core `v0.9.51` 的 `contribute/agsarama` 固定 IBM Sarama `v1.46.3`。但本地实现只提供配置转换、`sarama.Client` 创建和 fx 注入，没有现成 Outbox relay、ConsumerGroup 生命周期、`ag_server.Server` 注册、Inbox/DLQ 或 offset 提交语义。测试配置还以 `2.1.0` 为示例，项目中没有 Kafka 4.x broker 契约测试。

因此 `Kafka 4.x KRaft` 只能保留为目标线，不能宣称已兼容。P0 必须覆盖 producer、consumer group、rebalance、幂等生产、手动提交、DLQ、broker 滚动升级、KRaft 故障和 RF3/minISR2；失败时应锁定经测试的较低受支持 broker minor，而不是绕过 agsarama 自建客户端。

### 3. [P0] Temporal + MySQL 8.4 的架构依据充分，精确运行矩阵仍为空

**置信度：9/10。** memlog 已官方核验 Temporal Go SDK 具备 Workflow、Activity、Worker、Signal/Timer、异步完成、版本与可观测性，并记录自托管 Advanced Visibility 支持 MySQL `8.0.17+`。这支撑了“Temporal 唯一推进器”和 MySQL 8.4 候选，不存在技术虚构。

缺口是本地项目没有 Temporal Server、Go SDK、MySQL 客户端或 compose 清单，也没有 Server/SDK 兼容矩阵、schema migration、Continue-As-New、历史增长、Worker 升级和 MySQL HA 故障测试。P0 必须同时锁 Temporal Server patch、Go SDK patch、MySQL 8.4 patch/镜像 digest，并将 Temporal persistence/visibility 与七个业务服务数据库做账号和 schema 隔离。

### 4. [P1] OpenTelemetry 可行，但不是当前 ag-core 已提供的能力

**置信度：10/10。** memlog 官方核验了 OTel Go traces/metrics 稳定、logs beta；Spine 选择 traces/metrics + Collector 是合理的。可是本地 ag-core `go.mod` 与 contribute 模块没有 OTel 依赖，`ag/ag_log/ag-log-design.md` 仍把 OpenTelemetry 标为 TODO。AgLog 可输出 JSON，不等于自动具备 Hertz、Kitex、Kafka、MySQL、Temporal 的 trace 传播与指标。

实施计划必须明确由应用层新增 OTel bootstrap 与各协议 instrumentation，并定义 W3C trace context 到 Kafka envelope/Temporal context 的传播测试。不能把这项工作记为“框架自带”。OTel Go、Collector 与各 instrumentation 精确版本进入模块锁和 P0 冒烟测试。

### 5. [P1] FFmpeg、Kubernetes 与前端版本是官方有效目标，但尚未在项目中物化

**置信度：9/10。** memlog 已官方核验 React `19.2`、Vite `8.1.4`、FFmpeg `8.1.2`，以及 Kubernetes 当前维护 `1.36/1.35/1.34`，所以 K8s `1.35` 作为当时的 n-1 minor 成立。问题在本地可复现性：项目没有应用 `package.json`/lockfile、Go module、Dockerfile 或 compose；本机 Node 为 `24.15.0`、TypeScript 为 `5.0.2`，但没有安装项目 Vite；本机 FFmpeg 仍是 `5.1.2`；kubectl 为 `1.34.1` 且没有本地集群；Docker CLI 存在但 daemon 未运行。

P0 应产出前端 lockfile、Node 运行时镜像、FFmpeg 8.1.2 自有镜像 digest及 H.264/AAC/libass/font 能力测试、Kubernetes 1.35 精确 patch/发行版与 API dry-run。Spine 中“FFmpeg 8.1.2 镜像锁定”描述的是目标，不代表已有可用官方镜像。

## 技术与版本核验矩阵

| 技术承诺 | 审查状态 | 证据与现实边界 | Gate 结论 |
|---|---|---|---|
| Go `1.24.x` | 已核验；受框架约束 | 本地 ag-core `v0.9.51` 根模块及 contribute 模块均写 `go 1.24.8`；本机实际 `go1.25.5` | 方向成立；P0 固定 `1.24.8` 或经框架验证的新 patch，并用容器复现 |
| ag-core `0.9.x` | 受本地框架约束；必须 P0 锁定 | GitLab 本地仓有 `v0.9.51`；技能的 `v0.9.23/v0.9.25` 已与本地 tag 漂移；另有不可混用的 GitHub alpha 仓 | 不得只写系列号进入构建，必须固定 repo/tag/SHA/module path |
| aggo + fx | 已核验；受框架约束 | 技能与本地源码均证明 Proto-first 生成和 fx 装配存在；本地 core 固定 fx `v1.24.0` | 可采用；必须禁止手改生成区，并对实际 scaffold 做编译验证 |
| Hertz BFF | 已核验；受框架约束 | 本地 `contribute/aghertz` 使用 Hertz `v0.10.2` | 技术存在；精确 ag-core patch 锁定后随框架继承 |
| Kitex 内部调用 | 已核验；受框架约束 | 本地 core/agkitex 使用 Kitex `v0.15.2`、registry-nacos `v0.1.3` | 技术存在；gRPC 传输、Nacos 注册与身份 middleware 需契约测试 |
| MySQL `8.4 LTS` | 已核验为合理候选；必须 P0 锁定 | memlog 记录业务库提案及 Temporal 对 MySQL `8.0.17+` 的官方支持；本地 agdb 使用 GORM MySQL `v1.6.0` 和 go-sql-driver `v1.8.1` | 无不存在问题；业务 DAO、Temporal schema、PITR/HA 必须分开验证 |
| Temporal Server / Go SDK | 已核验功能；必须 P0 锁定 | 2026-07-14 官方 memlog 支持核心能力；本地无 binary、SDK module 或部署清单 | 架构选择成立；没有精确版本和升级证据前不得投产 |
| Kafka `4.x` KRaft | 官方版本已核验；受框架约束；必须 P0 锁定 | memlog 核验 4.x；本地仅证明 agsarama + Sarama `v1.46.3` 存在，未证明 Kafka 4 兼容 | 保留目标线，P0 完整链路后锁 minor/patch |
| Nacos | 受本地框架约束；必须 P0 锁定 | 本地 core 使用 nacos-sdk-go `v1.1.5`，agnacos/Kitex/Hertz 路径多为 `v1.1.6`；技能概览所称 `/v2` 与源码不一致 | 必须按源码实际 v1 SDK 选择并测试 Nacos Server，禁止依据技能概览猜版本 |
| Redis / agredis | 受本地框架约束；必须 P0 锁定 | 本地 agredis 使用 go-redis/v9 `v9.17.2`；没有 Redis Server 版本或 fail-closed 实测 | 仅作派生缓存/限流可行；锁 server patch、拓扑和故障行为 |
| React `19.2` | 官方 memlog 已核验 | 项目无前端 package/lockfile，本机没有项目级 React 安装 | 版本有效；创建项目时锁确切 package 解析结果 |
| TypeScript `5.x` | 系列约束，未精确核验 | 本机全局 `5.0.2`，项目无锁文件；全局版本不能作为构建依据 | P0 由前端 lockfile 与 CI 镜像锁 patch |
| Vite `8.1.4` | 官方 memlog 已核验 | 项目无 package/lockfile，本机无 Vite CLI | 版本有效；需与 Node、React 插件和测试栈一起锁定 |
| FFmpeg `8.1.2` | 官方 memlog 已核验；必须 P0 锁定 | 本机仅 `5.1.2`，项目无镜像；编码器、字体、libass 与许可证能力未知 | 目标版本成立；必须构建并锁镜像 digest，跑媒体规格金样测试 |
| Kubernetes `1.35` | 官方 memlog 已核验；必须 P0 锁定 | 1.35 是 2026-07-14 支持的 n-1 minor；本机 kubectl `1.34.1`，无集群证据 | minor 选择成立；锁发行版/patch/CNI/Ingress/存储并做恢复演练 |
| OpenTelemetry Go | 官方 API 状态已核验；本地框架未集成 | traces/metrics 稳定、logs beta；ag-core 仍将 OTel 列为 TODO | 由应用层实现，不得宣称 ag-core 内建；SDK/Collector/instrumentation P0 锁定 |
| Docker Compose | 工具存在但未验证运行 | Docker CLI `29.2.1` 存在，当前 daemon 不可连接，项目无 compose 文件 | 只可视为开发环境目标，不能作为已验证本地基线 |
| S3 兼容托管对象存储 | 接口方向已确认；供应商刻意延期 | memlog 排除已归档的 MinIO 社区版作为生产默认；Spine 延后供应商选择 | 不存在技术硬伤；P0 锁 provider、签名 URL、版本、删除证明与跨域冗余 |
| Prometheus / Tempo / Loki / Grafana | 技术组合成立，未精确锁定 | memlog 仅确认 OTel Collector 推荐职责与选型提案；项目无部署清单 | 保留架构方向；在观测栈部署前锁 chart/image digest 与保留策略 |

## 适配成立与不成立的边界

### 已成立

- `Go 1.24.x + GitLab ag-core 0.9.x + fx + Hertz + Kitex + MySQL DAO` 有本地源码直接依据。
- `Temporal` 支撑持久化长流程、人工 Signal、Timer、重试和版本治理，有 2026-07-14 官方 memlog 依据。
- `React 19.2 + TypeScript + Vite 8 SPA`、`FFmpeg 8.1.2`、`Kubernetes 1.35` 在核验时点均为存在且有效的技术/版本线。
- `MySQL 8.4`、Kafka KRaft、S3 兼容存储、OTel Collector 与 Grafana 栈没有发现技术不存在问题。

### 尚未成立，必须按 P0 处理

- `ag-core 0.9.x` 不是可复现依赖声明，必须落到唯一仓库、tag、SHA 和 contribute module 版本。
- `agsarama 可以承载 Kafka 4.x 全链路` 尚未被本地源码或测试证明。
- `Temporal Server/SDK + MySQL 8.4` 的精确兼容、迁移与故障恢复尚未被项目验证。
- `AgLog + OpenTelemetry` 不能解释为框架原生集成，OTel 需要应用层建设。
- `FFmpeg 8.1.2 镜像`、K8s 1.35 集群、React/Vite lockfile 在当前项目中都不存在。

## P0 锁定清单

1. 生成 `technology-lock.md` 或机器可读等价物，记录每项 repo、module、版本、commit、镜像 digest、许可证与升级策略。
2. 以 `gitlab.allinfinance.com/aifgo/ag-core` 候选 tag 建最小 web-bff、领域服务、agsarama producer/consumer、agnacos 注册发现、agredis、agdb 冒烟工程，CI 脱离 `go.work` 构建。
3. 建 Kafka 4.x KRaft 三节点契约环境；若 Sarama/agsarama 任一关键路径失败，回退到经测试的受支持 broker minor，并保留相同领域语义。
4. 建 Temporal + MySQL 8.4 环境，覆盖 schema 初始化/升级、Signal、长 Timer、Activity 超时、Worker 滚动升级、Continue-As-New、PITR 和 failover。
5. 建 FFmpeg 8.1.2 镜像并锁 digest，验证 H.264、AAC 48kHz、9:16 1080×1920、30fps、字幕烧录/独立字幕、字体与 AI 标识。
6. 创建前端 lockfile并在固定 Node 镜像中验证 React 19.2、Vite 8.1.4、TypeScript、测试与构建；不使用本机全局 TypeScript 作为依据。
7. 锁 Kubernetes 1.35 的发行版与 patch，验证所有 manifest API、Ingress、CNI、CSI、Secret、PDB、滚动升级和跨故障域恢复。
8. 明确 OTel 为应用层能力，补 Hertz、Kitex、Kafka、MySQL、Temporal 的 context propagation 和 Collector 敏感字段过滤测试。

完成以上 P0 后，本 Gate 可从 `CONDITIONAL PASS` 升级为 `PASS`。在此之前，Spine 可以指导 Epic 拆分，但不能作为生产环境版本清单直接执行。
