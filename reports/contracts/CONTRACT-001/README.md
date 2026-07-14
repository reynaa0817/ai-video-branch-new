# CONTRACT-001 契约边界证据

本目录保存 Story 1.3 可执行契约门禁结果。

执行：

```bash
bash scripts/verify-contracts.sh
```

门禁覆盖：

- `buf lint/build/breaking` 与锁定的 v1 baseline 比对。
- valid/unknown enum/unknown field golden vectors 的 Proto decoder + 语义防火墙。
- `contracts/services.yaml` 与 11 个 Go Module 的完整性、唯一事实 owner 和运行时身份一致性。
- 每个模块 `GOWORK=off go build ./...` 以及跨服务私有 import/共享 SQL 表检查。

输出：`result.tsv`。终端或 CI artifact 保留详细构建日志。
