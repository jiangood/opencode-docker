#!/usr/bin/env bash
# OpenCode 容器入口：共享后台服务 + OpenTunnel 远程配对（唯一模式）
# 服务只监听容器内 127.0.0.1，不发布端口，远程访问全部走端到端加密隧道
set -euo pipefail

echo "启动 OpenCode 共享后台服务 (仅容器内 127.0.0.1:4096，密码自动生成)"
opencode service set hostname 127.0.0.1
opencode service set port 4096
opencode service start

echo ""
echo "生成远程配对链接 (OpenTunnel, 端到端加密, 链接一次性、5 分钟内有效):"
opencode pair --remote --yes

echo ""
echo "重新生成配对链接: docker exec opencode-remote opencode pair --remote --yes"
# 后台服务是 detached 进程，用日志 tail 作为前台保活进程
exec tail -n 50 -F /home/opencode/.local/share/opencode/log/opencode.log
