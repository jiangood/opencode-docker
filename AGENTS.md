# AGENTS.md

本仓库是 OpenCode 的 Docker 封装，**只做一件事：OpenTunnel 远程配对**（端到端加密）。镜像由 GitHub Actions 构建推送到 GHCR，本机只负责 `pull` 和运行。

## 项目结构

```
├── Dockerfile              # 全部依赖从上游构建（含 Playwright 浏览器、中文字体、ui-ux-pro-max）
├── docker-compose.yml      # 拉取 GHCR 镜像运行，无端口发布
├── entrypoint.sh           # 启动共享服务 → 自动远程配对 → 日志保活
├── config/
│   ├── opencode.json       # Playwright MCP 配置
│   └── commands/*.md       # 8 个自定义命令（commit/review/security/test/explain/fix/refactor/doc）
├── scripts/pair.sh         # 重新生成配对链接
├── .github/workflows/docker.yml   # 多架构构建 → GHCR
└── workspace/              # 默认工作区（compose 挂载点）
```

## 关键不变量（改 Dockerfile 时必须遵守）

1. **镜像构建不依赖本机文件**：Dockerfile 里所有依赖都从上游安装（apt 官方源、npm 官方包、官方安装脚本、上游 CLI），不要 `COPY` 本机产物。
2. **多架构支持**：`TARGETARCH` 为 `amd64`/`arm64`。任何按架构选择下载物的逻辑（如 JDK 用 `x64`/`aarch64`）都要两种架构都覆盖，未知架构要显式报错退出。
3. **非 root 运行**：用户 `opencode`（UID/GID 默认 1000），`/workspace` 属主为该用户。新增 `COPY`/`mkdir` 记得 `--chown=opencode:opencode`。
4. **中文字体必须真正生效**：`/etc/fonts/conf.d/99-zh-cn-noto.conf` 为 zh 显式优先 Noto Sans CJK SC，且构建时用 `fc-match sans-serif:lang=zh-cn` 断言匹配结果。改字体相关配置后保留/更新该断言。
5. **不发布任何端口**：远程访问只走 OpenTunnel 端到端加密隧道，服务只监听容器内 `127.0.0.1:4096`，密码由 opencode 自动生成。
6. **Playwright MCP 以 `--no-sandbox` 运行**：容器内 Chromium 沙箱不可用，这是预期行为，不要"修复"它。

## 工作流

- **修改 → 推送 → CI 构建**：改动推到 GitHub 后，`.github/workflows/docker.yml` 自动构建 `linux/amd64` + `linux/arm64` 并推 `ghcr.io/<owner>/<repo>`。`main` 推送 → `latest`/分支名/sha；`v*` 标签 → 语义化版本；PR 只构建不推送。
- **本地验证**：可以 `docker build .` 本地构建测试（注意多架构用 `--platform`），但正式分发只走 CI。
- **运行验证**（容器起来后）：
  ```bash
  docker compose logs -f                                          # 启动日志里有配对链接
  docker compose exec opencode playwright-mcp --help | head -5    # Playwright MCP
  docker compose exec opencode ls /opt/ms-playwright              # 浏览器已下载
  docker compose exec opencode fc-match sans-serif:lang=zh-cn     # 中文字体
  ./scripts/pair.sh                                               # 重新生成配对链接（一次性、5 分钟有效）
  ```

## 约定

- 文档、注释、commit 说明、自定义命令内容都用**中文**；commit 用 Conventional Commits（type 英文，主题中文，≤50 字）。
- 自定义命令（`config/commands/*.md`）带 frontmatter `description`，可用 `` !`cmd` `` 注入命令输出、`$ARGUMENTS` 接收参数；命令里明确"不执行 git push"。
- `docker-compose.yml` 里镜像地址的 `OWNER` 是占位符，README 引导用户自行替换，不要写死具体用户名。
- 健康检查走 `opencode api get /api/info`（CLI 自动发现认证），不要改成依赖已知密码的方式。
