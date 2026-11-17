# AGENTS.md

本仓库是 OpenCode 2 的 Docker 封装，**只做一件事：OpenTunnel 远程配对**（端到端加密）。镜像由 GitHub Actions 构建推送到 GHCR，本机只负责 `pull` 和运行。

## 项目结构

```
├── Dockerfile              # 全部依赖从上游构建（含 Playwright 浏览器、中文字体、ui-ux-pro-max、开发工具链）
├── entrypoint.sh           # 合并内置默认 → 启动共享服务 → 自动远程配对 → 日志保活
├── config/
│   └── opencode.json       # 默认配置 + Playwright MCP（构建期存 /opt/opencode/defaults，启动时合并进主目录）
└── scripts/pair.sh         # 重新生成配对链接
```

## 关键不变量（改 Dockerfile 时必须遵守）

1. **镜像构建不依赖本机文件**：Dockerfile 里所有依赖都从上游安装（apt 官方源、npm 官方包、官方安装脚本、上游 CLI），不要 `COPY` 本机产物（`config/` 目录除外，它是镜像内置默认值）。
2. **仅支持 amd64**：`TARGETARCH` 为 `amd64`。任何按架构选择下载物的逻辑（如 JDK 用 `x64`）遇到非 amd64 架构要显式报错退出。
3. **OpenCode 2 必须走 `/v2/install` 安装**：默认安装脚本只装 OpenCode 1 且显式拒绝 2.x；远程配对（`opencode pair`/`service`/`api`）是 v2 命令。v2 安装脚本在 `set -u` 下无条件读 `$SHELL`，构建时必须显式传 `SHELL=/bin/bash`。装完把二进制移到 `/usr/local/bin/opencode`（主目录之外），不要依赖 `~/.opencode/bin`。
4. **单一挂载点 `/data`**：容器主目录可被宿主目录**整体覆盖**，因此二进制（`/usr/local/bin/opencode`）与内置默认内容（`/opt/opencode/defaults/`、`/opt/opencode/skills/`）都必须在主目录之外，由 entrypoint 启动时合并进主目录——**只补缺失，不覆盖用户文件**。
5. **WORKDIR 是挂载点本身（`/data`）**：宿主目录运行时整体覆盖主目录，WORKDIR 若落在深层路径（如 `.../workspace`）会被宿主目录挂载隐藏。工作区 `workspace/` 由 entrypoint 在主目录内自建。
6. **以 root 运行**：容器是 opencode 的专用环境（不是通用宿主机），直接 root 运行，宿主挂载目录无需属主对齐；`ENV HOME=/data` 让 root 的主目录指向挂载点，配置/会话/日志全部落在挂载目录里。
7. **中文字体必须真正生效**：`/etc/fonts/conf.d/99-zh-cn-noto.conf` 为 zh 显式优先 Noto Sans CJK SC，且构建时用 `fc-match sans-serif:lang=zh-cn` 断言匹配结果。改字体相关配置后保留/更新该断言。
8. **不发布任何端口**：远程访问只走 OpenTunnel 端到端加密隧道，服务只监听容器内 `127.0.0.1:4096`，密码由 opencode 自动生成。
9. **Playwright MCP 以 `--no-sandbox` 运行**：容器内 Chromium 沙箱不可用，这是预期行为，不要"修复"它。

## 工作流

- **修改 → 推送 → CI 构建**：改动推到 GitHub 后，`.github/workflows/docker.yml` 自动构建 `linux/amd64` 并推 `ghcr.io/<owner>/<repo>:latest`（只保留 `latest` 标签）。PR 只构建不推送。
- **阿里云镜像同步**：配置 secret `ALIYUN_PASSWORD` 后同时推 `registry.cn-hangzhou.aliyuncs.com/jiangood/opencode-docker:latest`（账号 `hustme`，参考 docker-admin）；未配置时跳过阿里云，不能因此让 CI 失败。
- **GHCR 推送凭据**：优先用仓库 secret `GHCR_PAT`（`write:packages`），未配置时回退 `GITHUB_TOKEN`（需 `packages: write`）。本仓库的 GHCR package 已由 CI 首次推送创建并关联本仓库，`GITHUB_TOKEN` 可直接推送。改登录逻辑时保留该回退。
- **镜像构建只走 GitHub Actions，禁止本地 `docker build`**：改动推送后由 CI 构建推送，本地只做**运行验证**（从阿里云拉取镜像后 `docker run` + 下面的检查项）。
- **运行验证**（容器起来后）：
  ```bash
  docker logs -f opencode-remote                                  # 启动日志里有配对链接
  docker exec opencode-remote opencode --version                  # OpenCode 版本
  docker exec opencode-remote mvn -v | head -2                    # Maven
  docker exec opencode-remote playwright-mcp --help | head -5    # Playwright MCP
  docker exec opencode-remote ls /opt/ms-playwright              # 浏览器已下载
  docker exec opencode-remote fc-match sans-serif:lang=zh-cn     # 中文字体
  ./scripts/pair.sh                                               # 重新生成配对链接（一次性、5 分钟有效）
  ```

## 约定

- 文档、注释、commit 说明都用**中文**；commit 用 Conventional Commits（type 英文，主题中文，≤50 字）。
- 镜像地址里的 `OWNER` 是占位符，README 引导用户自行替换，不要写死具体用户名。
- 健康检查走 `opencode api GET /api/info`（v2 CLI 自动发现认证），不要改成依赖已知密码的方式。
