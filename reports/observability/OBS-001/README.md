# OBS-001 本地可观测性证据

本目录只接受真实 Compose 运行时、依赖健康状态、持久化/outbox/Kafka/projection 往返和故障注入证据。静态 fixture 不得记为 GREEN。

完整运行时验收：

```bash
AI_VIDEO_ENV_FILE=/受保护路径/ai-video.env bash scripts/verify-local-platform.sh
```

仅检查 Compose 结构（输出会明确标记 `NOT_RUN`）：

```bash
bash scripts/verify-local-platform.sh --config-only
```

证据要求：

- `result.tsv` 必须显式区分 `PASS` / `FAIL` / `NOT_RUN`。
- `minimal-event-roundtrip.json` 只能由 `scripts/run-event-roundtrip.sh` 在真实 Compose runtime 中生成，并通过 DomainEventEnvelope 校验。
- 运行时日志、trace 与 JSON 证据必须通过大小写不敏感的 redaction 扫描。
- `scripts/verify-fail-closed.sh` 必须对 Budget、对象存储、Quality 和 Temporal 故障注入产证，证明 command rejected 且 state 未推进。
- 运行时必须显式提供不含示例弱凭据的 `AI_VIDEO_ENV_FILE`；所有宿主端口只绑定回环地址。

当前 PR 已提供 runtime driver，但本机缺少 Docker Compose 插件且未加载离线镜像包，因此 OBS-001 在本机仍保持 `NOT_RUN`，不得把 config-only 结果冒充为已验证状态。
