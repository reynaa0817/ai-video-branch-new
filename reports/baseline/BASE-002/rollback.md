# BASE-002 回滚目标

- integration 候选失败时删除独立的 `ai-video-base002` 容器、网络、kind 集群和测试卷。
- 回滚目标为已验证的 BASE-001 工具链加“不运行任何 BASE-002 服务”，不移动或覆盖候选 digest。
- internal-prod 未获批，禁止将 integration 的 MinIO、hostpath CSI 或本地项目镜像提升为生产基线。
