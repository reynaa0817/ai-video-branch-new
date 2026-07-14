#!/usr/bin/env bash
# 功能：验证 Story 1.3 Web shell 的设计 token、响应式和无障碍基线。
# 参数：无
# 返回值：0-验证通过，1-验证失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node "$ROOT_DIR/web/scripts/verify-web-shell.mjs"
