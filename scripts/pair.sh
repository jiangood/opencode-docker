#!/usr/bin/env bash
# 手动生成远程配对链接（OpenTunnel，端到端加密，链接一次性、5 分钟过期）
# 默认模式是前台 opencode serve --service（共享服务），不自动配对；
# 配对直接复用容器内这个正在运行的服务实例，不会另起进程；需要外网访问时在宿主执行本脚本
# 用法: ./scripts/pair.sh [容器名]   # 默认 opencode，也可用环境变量 OPENCODE_CONTAINER 指定
set -euo pipefail
cd "$(dirname "$0")/.."
container="${1:-${OPENCODE_CONTAINER:-opencode}}"
docker exec "${container}" opencode pair --remote --yes
