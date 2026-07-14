# Go 离线模块缓存

本目录承载 Story 1.3 Go 服务镜像禁网构建所需的 module cache。真实 payload 不提交 Git，必须由 `deps/manifest.sha256` 锁定摘要后随离线部署批次交付。

缺少缓存或摘要不匹配时，Go Docker build 必须在 `GOPROXY=off` 下失败关闭。
