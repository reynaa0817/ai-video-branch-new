# pnpm 离线依赖仓库

本目录承载 Story 1.3 Web 镜像 `pnpm install --frozen-lockfile --offline` 所需 store。真实 payload 不提交 Git，必须由 `deps/manifest.sha256` 锁定摘要后随离线部署批次交付。

缺少 store 或摘要不匹配时，Web Docker build 必须失败关闭。
