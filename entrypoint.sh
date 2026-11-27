#!/usr/bin/env bash
# OpenCode 容器入口：前台独立端口服务（opencode serve，默认模式）
# 服务监听容器内 0.0.0.0:4096，由宿主用 -p 映射访问；密码优先取 OPENCODE_PASSWORD，
# 否则在挂载目录持久化随机密码（/data/.config/opencode/server-password），重建容器不变
# 需要 OpenTunnel 远程配对时属可选操作：进入容器手动执行 opencode pair --remote --yes
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

# 服务密码：OPENCODE_PASSWORD 优先；未设置时在挂载目录生成并复用，保证重建/更新容器后密码不变。
# opencode serve 只接受环境变量形式的密码，因此密码文件仅用于持久化，启动时再导出给服务。
password_file="${home}/.config/opencode/server-password"
if [ -n "${OPENCODE_PASSWORD:-}" ]; then
    password_source="环境变量 OPENCODE_PASSWORD"
elif [ -n "${OPENCODE_SERVER_PASSWORD:-}" ]; then
    OPENCODE_PASSWORD="${OPENCODE_SERVER_PASSWORD}"
    export OPENCODE_PASSWORD
    password_source="环境变量 OPENCODE_SERVER_PASSWORD"
elif [ -s "${password_file}" ]; then
    OPENCODE_PASSWORD="$(tr -d '\r\n' < "${password_file}")"
    export OPENCODE_PASSWORD
    password_source="持久化文件 ${password_file}"
else
    OPENCODE_PASSWORD="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    (umask 077; printf '%s' "${OPENCODE_PASSWORD}" > "${password_file}")
    export OPENCODE_PASSWORD
    password_source="已生成并保存到 ${password_file}"
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

# 升级提示：旧配置里若还声明了 Playwright MCP，本镜像已不再提供 playwright-mcp 可执行文件
if grep -qs 'playwright' "${home}/.config/opencode/opencode.json"; then
    echo "提示: 现有 opencode.json 仍引用 playwright MCP，但镜像已移除 Playwright/Chromium，可删除该 mcp 配置项" >&2
fi

# 工作区在主目录内自建；WORKDIR 就是挂载点本身
install -d "${home}/workspace"
cd "${home}/workspace"

echo "启动 OpenCode 独立端口服务 (foreground, 监听 0.0.0.0:4096)"
echo "宿主机访问需用 -p 映射端口（建议 -p 127.0.0.1:4096:4096），HTTP Basic 用户名固定 opencode"
echo "服务密码: ${OPENCODE_PASSWORD}（来源: ${password_source}）"
echo "需要远程配对时进入容器手动执行: opencode pair --remote --yes"
echo ""
# 前台独立端口服务：由容器生命周期托管，不再依赖共享后台服务，也不再自动配对
exec opencode serve --hostname 0.0.0.0 --port 4096
