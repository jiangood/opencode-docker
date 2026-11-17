# OpenCode 远程配对容器 —— 由 GitHub Actions 构建并推送到 GHCR
# 文档: https://opencode.ai/docs/cli/web/ (OpenCode 2)
FROM node:22-bookworm-slim

ARG UID=1000
ARG GID=1000
ARG TARGETARCH=amd64
ARG PLAYWRIGHT_MCP_VERSION=latest
ARG UIPRO_VERSION=latest

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_HOME=/opt/java \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    PATH=/opt/java/bin:/usr/local/bin:$PATH

# 基础工具链 + Python(技能脚本) + 中文字体(fontconfig 体系)
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
        gnupg \
        ripgrep \
        openssh-client \
        procps \
        less \
        jq \
        python3 \
        fontconfig \
        fonts-noto-cjk \
        fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI：官方 apt 源（保证版本正确、与架构无关）
RUN set -eux; \
    install -d -m 755 /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh; \
    rm -rf /var/lib/apt/lists/*; \
    gh --version

# 中文字体必须真正生效：给简体中文显式优先 Noto Sans CJK SC，并断言匹配结果
# （echo 逐行写文件：Dockerfile 经典 parser 不支持 RUN 内的 shell heredoc，CI 的 buildx 支持，统一用兼容写法）
RUN set -eux; \
    mkdir -p /etc/fonts/conf.d; \
    { \
        echo '<?xml version="1.0"?>'; \
        echo '<!DOCTYPE fontconfig SYSTEM "fonts.dtd">'; \
        echo '<fontconfig>'; \
        echo '  <match target="pattern">'; \
        echo '    <test name="lang" compare="contains"><string>zh</string></test>'; \
        echo '    <edit name="family" mode="prepend" binding="strong"><string>Noto Sans CJK SC</string></edit>'; \
        echo '  </match>'; \
        echo '</fontconfig>'; \
    } > /etc/fonts/conf.d/99-zh-cn-noto.conf; \
    fc-cache -f >/dev/null 2>&1; \
    fc-match sans-serif:lang=zh-cn | grep -qi "Noto Sans CJK SC"

# Java 21 (Eclipse Temurin)，仅支持 amd64
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) jarch=x64 ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/java; \
    curl -fsSL "https://api.adoptium.net/v3/binary/latest/21/ga/linux/${jarch}/jdk/hotspot/normal/eclipse" -o /tmp/jdk.tar.gz; \
    tar -xzf /tmp/jdk.tar.gz -C /opt/java --strip-components=1; \
    rm -f /tmp/jdk.tar.gz; \
    java -version

# Playwright MCP + 浏览器：用 MCP 自带的 playwright 版本下载匹配的 Chromium
RUN set -eux; \
    npm install -g "@playwright/mcp@${PLAYWRIGHT_MCP_VERSION}"; \
    cd /usr/local/lib/node_modules/@playwright/mcp; \
    npx playwright install --with-deps chromium; \
    chmod -R 755 /opt/ms-playwright; \
    test -x /usr/local/bin/playwright-mcp

# 非 root 用户，UID/GID 与宿主机对齐：基础镜像的 node 用户已占 UID/GID 1000
# /home/opencode 是容器唯一挂载点（可被宿主目录整体覆盖），
# 因此 opencode 二进制与内置默认内容都放在主目录之外（/usr/local/bin、/opt/opencode）
RUN set -eux; \
    if [ "${UID}" = "1000" ] && [ "${GID}" = "1000" ]; then \
        usermod -l opencode node; \
        groupmod -n opencode node; \
        usermod -d /home/opencode -s /bin/bash opencode; \
    else \
        groupadd -g "${GID}" opencode; \
        useradd -m -u "${UID}" -g "${GID}" -s /bin/bash opencode; \
    fi; \
    mkdir -p /home/opencode/workspace /opt/opencode; \
    chown -R opencode:opencode /home/opencode /opt/opencode; \
    rm -rf /home/node; \
    id opencode

# 安装 OpenCode 2（官方 v2 安装脚本）。注意：默认安装脚本只装 OpenCode 1，
# 远程配对（opencode pair/service）是 OpenCode 2 的命令，必须走 /v2/install。
# 二进制移到 /usr/local/bin（主目录之外，不会被挂载隐藏）
RUN set -eux; \
    curl -fsSL https://opencode.ai/v2/install -o /tmp/v2-install.sh; \
    env HOME=/home/opencode SHELL=/bin/bash bash /tmp/v2-install.sh --no-modify-path; \
    install -m 755 /home/opencode/.opencode/bin/opencode /usr/local/bin/opencode; \
    rm -rf /home/opencode/.opencode /tmp/v2-install.sh; \
    opencode --version

# ui-ux-pro-max 技能：从上游 CLI 构建安装（不依赖本机文件），
# 存 /opt/opencode/skills（主目录之外），由 entrypoint 启动时合并进主目录
RUN set -eux; \
    cd /home/opencode; \
    env HOME=/home/opencode NPM_CONFIG_CACHE=/tmp/npmcache \
        npx -y "ui-ux-pro-max-cli@${UIPRO_VERSION}" init --ai opencode; \
    src="$(find /home/opencode -maxdepth 5 -type d -name ui-ux-pro-max | head -n1)"; \
    test -n "${src}"; \
    install -d -m 755 /opt/opencode/skills; \
    cp -a "${src}" /opt/opencode/skills/ui-ux-pro-max; \
    # 只清理 init 写进主目录的产物，不动其他内容
    rm -rf /home/opencode/.opencode /home/opencode/.agents /home/opencode/.npm /tmp/npmcache; \
    test -f /opt/opencode/skills/ui-ux-pro-max/SKILL.md

# 默认配置（Playwright MCP）：存 /opt/opencode/defaults，由 entrypoint 缺时才合并进主目录
COPY --chown=opencode:opencode config/ /opt/opencode/defaults/

USER opencode
# WORKDIR 必须是挂载点本身：docker 会用 root 自动创建缺失的 WORKDIR，
# 深层路径（如 .../workspace）被宿主空目录挂载隐藏后会变成 root:755，非 root 用户写不进去
WORKDIR /home/opencode

COPY --chown=opencode:opencode entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# 健康检查走 CLI 自动发现与认证，无需知道自动生成的密码
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD opencode api GET /api/info || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
