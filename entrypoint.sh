#!/usr/bin/env bash
# OpenCode 容器入口：共享后台服务 + OpenTunnel 远程配对（唯一模式）
# 服务只监听容器内 127.0.0.1，不发布端口，远程访问全部走端到端加密隧道
# /data 是唯一挂载点（可被宿主目录整体覆盖），因此二进制(/usr/local/bin/opencode)
# 与内置默认内容(/opt/opencode)都在主目录之外，启动时合并进主目录：只补缺失，不覆盖用户文件
set -euo pipefail

# 启动自检：opencode 必须在 /usr/local/bin（主目录之外，不会被 /data 挂载覆盖）。
# 缺失说明镜像本身有问题（例如拉到了旧镜像），直接给出明确错误而不是反复重启刷 command not found。
if ! command -v opencode >/dev/null 2>&1; then
    echo "错误: 镜像内缺少 opencode 二进制（预期 /usr/local/bin/opencode）。" >&2
    echo "      请拉取最新镜像后重建容器：docker pull <镜像> && docker rm -f <容器>" >&2
    exit 1
fi

home=/data

# 合并镜像内置默认内容（配置 + 技能 + 容器说明），用户目录里已有的文件一律不动
install -d -m 700 "${home}/.config/opencode"
if [ ! -f "${home}/.config/opencode/opencode.json" ]; then
    install -m 644 /opt/opencode/defaults/opencode.json "${home}/.config/opencode/opencode.json"
fi
if [ -f /opt/opencode/defaults/AGENTS.md ] && [ ! -f "${home}/.config/opencode/AGENTS.md" ]; then
    install -m 644 /opt/opencode/defaults/AGENTS.md "${home}/.config/opencode/AGENTS.md"
fi
if [ -f /opt/opencode/defaults/AGENTS.md ] && [ ! -f "${home}/AGENTS.md" ]; then
    install -m 644 /opt/opencode/defaults/AGENTS.md "${home}/AGENTS.md"
fi
if [ ! -e "${home}/.config/opencode/skills/ui-ux-pro-max" ]; then
    install -d -m 755 "${home}/.config/opencode/skills"
    cp -a /opt/opencode/skills/ui-ux-pro-max "${home}/.config/opencode/skills/"
fi

# 工作区在主目录内自建；WORKDIR 就是挂载点本身
install -d "${home}/workspace"
cd "${home}/workspace"

echo "启动 OpenCode 共享后台服务 (仅容器内 127.0.0.1:4096，密码自动生成)"
opencode service set hostname 127.0.0.1
opencode service set port 4096
opencode service start

echo ""
echo "生成远程配对链接 (OpenTunnel, 端到端加密, 链接一次性、5 分钟内有效):"
opencode pair --remote --yes

echo ""
echo "重新生成配对链接: ./scripts/pair.sh（或 docker exec opencode opencode pair --remote --yes）"
# 后台服务是 detached 进程，用日志 tail 作为前台保活进程
exec tail -n 50 -F "${home}/.local/share/opencode/log/opencode.log"
