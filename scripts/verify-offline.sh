#!/usr/bin/env bash
# 功能：验证当前 Story 1.3 骨架没有引入外部镜像、浮动 tag 或不可写持久化目录。
# 参数：无
# 返回值：0-验证通过，1-验证失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== 离线部署骨架验证 ==="

if rg -n '(:latest|docker\.io|ghcr\.io|quay\.io)' "$ROOT_DIR/docker-compose.yml" "$ROOT_DIR/deploy" >/tmp/story13-offline-images.txt; then
  cat /tmp/story13-offline-images.txt >&2
  echo "ERROR: compose references external or floating images" >&2
  exit 1
fi
echo "[1/3] 镜像引用检查通过"

mkdir -p "$ROOT_DIR/data/logs/app" "$ROOT_DIR/data/logs/error"
test -w "$ROOT_DIR/data/logs/app"
test -w "$ROOT_DIR/data/logs/error"
echo "[2/3] 日志目录权限检查通过"

if find "$ROOT_DIR/deps" -maxdepth 1 -type d | grep -q .; then
  echo "[3/3] deps 目录存在"
else
  echo "ERROR: deps directory missing" >&2
  exit 1
fi

echo "=== 验证完成，Story 1.3 骨架未引入外网部署依赖 ==="
