# BASE-001 可追溯性

| 验收项 | 证据 |
| --- | --- |
| AC1 远端可恢复 | `baseline-manifest.yaml`、`ref-protection.txt`、真实 gate refs 检查 |
| AC2 七工具隔离重建 | `build.log`、`environment/build-contract.env` |
| AC3 provenance | `metadata/*.txt`、`module-downloads.log` |
| AC4 失败关闭 | `negative-results.log`、13 个确定性 ATDD 场景 |
| AC5 审计与回滚 | `owner-and-time.txt`、`manifest-signature.txt`、`rollback.md` |

最终 tool source 为内容寻址 commit `3ad9bb9cf7106560400391b62a7f373f682cf591`；root dependency 为受保护版本 `v0.0.1-alpha.3@1624c77ab90b12b77191c38005b64d59f8a0029e`。
