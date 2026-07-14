# 离线依赖目录

本目录只提交说明文件和占位清单。真实离线依赖包、字体、RPM、源码快照和二进制工具按部署批次单独交付，不直接提交到 Git。

## 子目录

- `bin/`：预下载二进制工具，例如 kind。
- `fonts/`：预下载字体文件，例如 Noto CJK 字体。
- `rpm/mysql/`：MySQL PITR 验证所需 RPM。
- `source/`：需要保留 `.git` 元数据的源码快照。
- `go-mod-cache/`：Go 服务镜像禁网构建所需的锁定 module cache。
- `pnpm-store/`：Web 镜像 `pnpm --offline` 构建所需的锁定 store。

## 规则

- 禁止在 Dockerfile、Compose 或验证脚本中运行联网下载命令补依赖。
- 缺少必需离线物料时，验证脚本必须失败关闭。
- 大体积依赖包不进 Git；交付时应附带 checksum、来源、许可证和 owner 审批记录。
- Story 1.3 的实际制品必须记录在 `deps/manifest.sha256`，条目使用仓库根相对路径，并同时覆盖 `deps/go-mod-cache/`、`deps/pnpm-store/` 与 `images/`。
