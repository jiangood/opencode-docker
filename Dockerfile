# OpenCode 远程配对容器 —— 由 GitHub Actions 构建并推送到 GHCR
# 文档: https://opencode.ai/docs/cli/web/
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
    PATH=/opt/java/bin:/home/opencode/.opencode/bin:/usr/local/bin:$PATH

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
RUN mkdir -p /etc/fonts/conf.d \
    && cat > /etc/fonts/conf.d/99-zh-cn-noto.conf <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="lang" compare="contains"><string>zh</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Sans CJK SC</string></edit>
  </match>
</fontconfig>
EOF
RUN fc-cache -f >/dev/null 2>&1 \
    && fc-match sans-serif:lang=zh-cn | grep -qi "Noto Sans CJK SC"

# Java 21 (Eclipse Temurin)，按目标架构下载
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) jarch=x64 ;; \
        arm64) jarch=aarch64 ;; \
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

# 非 root 用户，UID/GID 与宿主机对齐
RUN groupadd -g "${GID}" opencode \
    && useradd -m -u "${UID}" -g "${GID}" -s /bin/bash opencode \
    && mkdir -p /workspace \
    && chown opencode:opencode /workspace

USER opencode
WORKDIR /home/opencode

# 安装 opencode（官方安装脚本）
RUN curl -fsSL https://opencode.ai/install | bash

# ui-ux-pro-max 技能：从上游 CLI 构建安装（不依赖本机文件）
RUN set -eux; \
    npx -y "ui-ux-pro-max-cli@${UIPRO_VERSION}" init --ai opencode; \
    src="$(find /home/opencode -maxdepth 5 -type d -name ui-ux-pro-max | head -n1)"; \
    test -n "${src}"; \
    dst=/home/opencode/.config/opencode/skills/ui-ux-pro-max; \
    mkdir -p /home/opencode/.config/opencode/skills; \
    if [ "${src}" != "${dst}" ]; then cp -a "${src}" "${dst}"; fi; \
    rm -rf /home/opencode/.opencode /home/opencode/.agents; \
    test -f "${dst}/SKILL.md"

# 配置：opencode.json（含 Playwright MCP）+ 自定义命令
COPY --chown=opencode:opencode config/ /home/opencode/.config/opencode/

RUN mkdir -p /home/opencode/.local/share/opencode

WORKDIR /workspace

COPY --chown=opencode:opencode entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# 健康检查走 CLI 自动发现与认证，无需知道自动生成的密码
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD opencode api get /api/info || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
