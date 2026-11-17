#!/usr/bin/env bash
# OpenCode 容器入口：共享后台服务 + OpenTunnel 远程配对（唯一模式）
# 服务只监听容器内 127.0.0.1，不发布端口，远程访问全部走端到端加密隧道
# /home/opencode 是唯一挂载点（可被宿主目录整体覆盖），因此二进制(/usr/local/bin/opencode)
# 与内置默认内容(/opt/opencode)都在主目录之外，启动时合并进主目录：只补缺失，不覆盖用户文件
set -euo pipefail

home=/home/opencode

# 合并镜像内置默认内容（配置 + 技能），用户目录里已有的文件一律不动
install -d -m 700 "${home}/.config/opencode"
if [ ! -f "${home}/.config/opencode/opencode.json" ]; then
    install -m 644 /opt/opencode/defaults/opencode.json "${home}/.config/opencode/opencode.json"
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
echo "重新生成配对链接: docker exec opencode-remote opencode pair --remote --yes"
# 后台服务是 detached 进程，用日志 tail 作为前台保活进程
exec tail -n 50 -F "${home}/.local/share/opencode/log/opencode.log"
