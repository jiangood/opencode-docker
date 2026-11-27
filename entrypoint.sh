#!/usr/bin/env bash
# OpenCode 容器入口：共享服务模式（前台 opencode serve --service，默认模式）
# 进程本身就是 OpenCode 的共享后台服务：容器内的 TUI / pair / api 会自动复用它，
# 不会再另起一个默认监听 127.0.0.1:49374 的后台实例（避免两个实例共用同一数据库）
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
# 共享服务模式下密码要写进 service.json 才生效，server-password 文件只负责跨容器持久化。
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

# 干净启动：清掉上次容器被强制删除（docker rm -f / 升级重建）时遗留的服务注册。
# 注册文件里记录的 pid 通常是旧容器的 1，而在新容器里 1 恰好就是本 entrypoint 自己，
# 会让下面的 opencode service set 误判“服务仍在运行”并报错退出（Server process 1 is still running）。
# 该文件只是运行时注册信息，服务启动后会重新写入，删除是安全的。
rm -f "${home}/.local/state/opencode/service.json"

# 共享服务配置：服务进程的 hostname/port/password 取自 service.json（不读 OPENCODE_PASSWORD），
# 因此启动前必须显式同步；写入持久化配置后，用户手动 opencode service restart 也不会退回默认的
# 127.0.0.1:49374，端口映射继续有效。service.json 权限为 600，密码与上面的来源保持一致。
opencode service set hostname 0.0.0.0 >/dev/null
opencode service set port 4096 >/dev/null
opencode service set password "${OPENCODE_PASSWORD}" >/dev/null

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

echo "启动 OpenCode 共享服务 (foreground: serve --service, 监听 0.0.0.0:4096)"
echo "宿主机访问需用 -p 映射端口（建议 -p 127.0.0.1:4096:4096），HTTP Basic 用户名固定 opencode"
echo "服务密码: ${OPENCODE_PASSWORD}（来源: ${password_source}）"
echo "容器内 TUI / pair / api 会自动复用该服务（不再另起 49374 端口的后台实例）"
echo "需要远程配对时进入容器手动执行: opencode pair --remote --yes"
echo ""
# 共享服务模式：该前台进程同时注册为 OpenCode 的共享后台服务，由容器生命周期托管；
# 远程配对仍不自动开启，需要外网访问时手动执行 opencode pair --remote --yes
exec opencode serve --service --hostname 0.0.0.0 --port 4096
