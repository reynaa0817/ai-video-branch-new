# 功能：构建 Story 1.3 Go 服务/Worker 骨架镜像。
# 参数：SERVICE_PATH 指向仓库内独立 Go Module，例如 services/studio。
# 返回值：构建成功生成 /app/server；构建失败时 Docker build 非零退出。

# 使用本地预加载 Go 镜像，禁止从公共 registry 拉取。
FROM local.ai-video/go:1.25.1-arm64 AS builder

# SERVICE_PATH 指定要构建的独立模块。
ARG SERVICE_PATH

# 工作目录用于复制仓库内容；实际构建在独立 Go Module 内执行。
WORKDIR /src

# 复制仓库源码。离线构建必须确保依赖已在 deps 或本地 module cache 中准备好。
COPY . .

# 离线 module cache 必须由 deps/manifest.sha256 锁定；禁止 Go 工具链回退联网。
ENV GOMODCACHE=/src/deps/go-mod-cache \
    GOPROXY=off \
    GOSUMDB=off

# 使用 GOWORK=off 验证模块不依赖根 go.work。先编译全部包，避免隐藏在
# cmd/server 之外的 handler、repository 或生成代码损坏后镜像仍假绿。
RUN cd "${SERVICE_PATH}" \
    && if [ -d vendor ]; then export GOFLAGS=-mod=vendor; else test -d "${GOMODCACHE}"; fi \
    && GOWORK=off go build ./... \
    && GOWORK=off go build -o /out/server ./cmd/server

# 运行时镜像同样来自本地预加载仓库。
FROM local.ai-video/runtime-debian:12-arm64

ARG VCS_REF
LABEL org.opencontainers.image.revision="${VCS_REF}"

# 服务统一运行目录。
WORKDIR /app

# 复制编译产物。
COPY --from=builder /out/server /app/server

# 默认启动健康/边界命令；业务协议适配由 aggo 生成后再接入。
ENTRYPOINT ["/app/server"]

# 最小骨架不手写 HTTP 路由；容器健康由同一二进制的 health 命令判定。
HEALTHCHECK --interval=10s --timeout=3s --retries=6 CMD ["/app/server", "health"]
