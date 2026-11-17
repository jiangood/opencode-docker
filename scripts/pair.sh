#!/usr/bin/env bash
# 生成远程配对链接（OpenTunnel，端到端加密，链接一次性、5 分钟过期）
# 用法: ./scripts/pair.sh
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec opencode opencode pair --remote --yes
