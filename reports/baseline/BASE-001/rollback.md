# BASE-001 回滚与弃用规则

- 在 Story 1.1 首次基线通过前没有可回滚的上一条 verified baseline；任何候选失败都必须保持 G0-1 阻塞。
- 失败候选的 tag 不得 force-move、删除或重建；以递增的 `ag-core-tools-v0.1.0-baseline.N` 创建新候选。
- 首次 verified baseline 发布后，回滚是让 ai-video manifest/构建流程恢复引用上一条已验证 ref，而不是改写已发布 ref。
- 弃用记录必须保留：candidate ref/SHA、失败原因、替代 ref、批准人、发生时间和对应 CI artifact ID。
