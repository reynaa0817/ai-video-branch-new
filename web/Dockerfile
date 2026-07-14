# 功能：构建 Story 1.3 Web 工作台骨架镜像。
# 参数：无
# 返回值：构建成功生成静态资源并由本地 nginx runtime 提供。

# 由构建器传入目标架构，默认与当前锁定的 arm64 离线包一致。
ARG TARGETARCH=arm64

# 使用 Story 1.2 锁定的本地 Node 镜像，禁止联网拉取。
FROM local.ai-video/node:24.18.0-pnpm11.4.0-${TARGETARCH} AS builder

# 工作目录。
WORKDIR /src/web

# 复制 Web lockfile 和源码。
COPY web/package.json web/pnpm-lock.yaml ./
COPY web/ ./

# 离线 store 必须来自受 manifest.sha256 保护的 deps 包。
COPY deps/pnpm-store /pnpm/store

# frozen install 必须使用预置离线 store；不得在构建时访问外网。
RUN pnpm config set store-dir /pnpm/store \
    && pnpm install --frozen-lockfile --offline \
    && pnpm build

# 使用本地 nginx runtime 镜像提供静态资源。
FROM local.ai-video/nginx:1.29.4-${TARGETARCH}

ARG VCS_REF
LABEL org.opencontainers.image.revision="${VCS_REF}"

# 静态资源目录。
COPY --from=builder /src/web/dist /usr/share/nginx/html
