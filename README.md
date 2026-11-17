# opencode-docker

OpenCode 的 Docker 封装，**只做一件事：OpenTunnel 远程配对**（端到端加密），手机 App / 桌面 App 扫码或粘贴链接即用。

镜像由 **GitHub Actions** 构建推送到 GHCR，本机只负责 `pull` 和运行。

## 内置能力

| 分类 | 内容 |
|---|---|
| 运行时 | Node 22、Java 21 (Temurin)、Python 3、git、gh（GitHub CLI） |
| 远程 | OpenTunnel 端到端加密配对，容器不发布任何端口 |
| 浏览器 | Playwright MCP + Chromium（headless，`--no-sandbox`），可截图/自动化 |
| 中文字体 | Noto Sans CJK SC + Noto Color Emoji，构建时用 `fc-match` 断言生效，截图不会出现方块/乱码 |
| 技能 | [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)（Dockerfile 从上游 CLI 安装） |
| 命令 | `/commit` `/review` `/security` `/test` `/explain` `/fix` `/refactor` `/doc` |

## 使用

```bash
# 1. 修改 docker-compose.yml 里的镜像地址（把 OWNER 换成你的 GitHub 用户名/组织）
#    image: ghcr.io/OWNER/opencode-docker:latest

# 2. 修改工作区挂载指向你的代码目录
#    - /path/to/code:/workspace

# 3. 拉取并启动
docker compose up -d
docker compose logs -f      # 启动日志里有配对链接
```

链接过期后重新生成：

```bash
./scripts/pair.sh           # 容器内 opencode pair --remote --yes
```

- 浏览器打开链接即完成配对（一次性、5 分钟有效）
- OpenCode App 扫码或把链接粘贴到服务器地址栏
- 配对成功后 App 保存服务器配置，长期有效（不受浏览器 30 天 cookie 限制）

## 构建（GitHub Actions）

推送到 GitHub 后，`.github/workflows/docker.yml` 自动构建 `linux/amd64` + `linux/arm64` 多架构镜像并推送到 `ghcr.io/<owner>/<repo>`：

- `main` 分支推送 → `latest`、分支名、sha 标签
- 打 `v*` 标签 → 语义化版本标签
- PR → 只构建不推送（验证 Dockerfile）
- 手动触发：Actions → docker → Run workflow

镜像私有可见时，运行前先登录：

```bash
docker login ghcr.io -u <用户名>
```

## 目录结构

```
opencode-docker/
├── Dockerfile              # 全部依赖从上游构建（含 Playwright 浏览器、中文字体、ui-ux-pro-max）
├── docker-compose.yml      # 拉取 GHCR 镜像运行，无端口发布
├── entrypoint.sh           # 启动共享服务 → 自动远程配对 → 日志保活
├── config/
│   ├── opencode.json       # Playwright MCP 配置
│   └── commands/*.md       # 8 个常用自定义命令
├── scripts/pair.sh         # 重新生成配对链接
├── .github/workflows/docker.yml
└── workspace/              # 默认工作区（compose 挂载点）
```

## 常用操作

```bash
docker compose exec opencode bash                     # 进容器
docker compose exec opencode opencode auth login      # 登录模型提供商
docker compose exec opencode opencode service status  # 服务状态
docker compose exec opencode playwright-mcp --help | head -5  # 验证 Playwright MCP
docker compose exec opencode ls /opt/ms-playwright            # 验证浏览器已下载
docker compose exec opencode fc-match sans-serif:lang=zh-cn  # 验证中文字体
docker compose down                                   # 停止（数据卷保留）
```

## 安全注意

- 远程配对会把服务器暴露到公网：流量端到端加密，密码由 opencode 自动生成
- 配对链接一次性、5 分钟内有效，不要分享给不信任的人
- 容器内 opencode 拥有 `/workspace` 的完整读写和 shell 执行权限，只挂载需要处理的代码目录
- Playwright MCP 以 `--no-sandbox` 运行（容器内 Chromium 沙箱不可用），仅用于访问可信站点
