#!/usr/bin/env bash
# 生成远程配对链接（OpenTunnel，端到端加密，链接一次性、5 分钟过期）
# 用法: ./scripts/pair.sh [容器名]   # 默认 opencode，也可用环境变量 OPENCODE_CONTAINER 指定
set -euo pipefail
cd "$(dirname "$0")/.."
container="${1:-${OPENCODE_CONTAINER:-opencode}}"
docker exec "${container}" opencode pair --remote --yes
