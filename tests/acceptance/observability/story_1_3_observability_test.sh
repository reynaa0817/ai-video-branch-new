#!/usr/bin/env bash
# 功能：Story 1.3 local 可观测性与事件往返验收入口。
# 参数：无
# 返回值：0-通过，1-失败

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
bash "$ROOT_DIR/scripts/verify-local-platform.sh"
