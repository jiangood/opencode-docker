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

## 使用

```bash
# 拉取并启动（把 OWNER 换成你的 GitHub 用户名/组织，/path/to/code 换成实际代码目录）
docker run -d \
    --name opencode-remote \
    --restart unless-stopped \
    -v /path/to/code:/workspace \
    -v opencode-data:/home/opencode/.local/share/opencode \
    --workdir /workspace \
    ghcr.io/OWNER/opencode-docker:latest

docker logs -f opencode-remote   # 启动日志里有配对链接
```

可选：容器内需要 `gh`（GitHub CLI）时，再挂宿主机凭据：

```bash
# 加一行 -v ~/.config/gh:/home/opencode/.config/gh 即可
# 注意：容器内 opencode 用户是 UID 1000，宿主机用户 UID 不是 1000 时 hosts.yml 可能读不到，
# 那种情况改用 -e GH_TOKEN="$(gh auth token)" 传 token 最省事
```

国内网络也可以从阿里云（杭州）拉取：

```bash
docker pull registry.cn-hangzhou.aliyuncs.com/jiangood/opencode-docker:latest
# 阿里云仓库默认私有，需先登录：
docker login registry.cn-hangzhou.aliyuncs.com -u <阿里云账号>
```

链接过期后重新生成：

```bash
./scripts/pair.sh           # 容器内 opencode pair --remote --yes
```

- 浏览器打开链接即完成配对（一次性、5 分钟有效）
- OpenCode App 扫码或把链接粘贴到服务器地址栏
- 配对成功后 App 保存服务器配置，长期有效（不受浏览器 30 天 cookie 限制）

## 构建（GitHub Actions）

推送到 GitHub 后，`.github/workflows/docker.yml` 自动构建 `linux/amd64` 镜像并推送到 `ghcr.io/<owner>/<repo>:latest`（只保留 `latest` 标签）：

- `main` 分支推送 → `latest` 标签
- PR → 只构建不推送（验证 Dockerfile）
- 手动触发：Actions → docker → Run workflow
- 镜像同时推送到 GitHub GHCR 和阿里云杭州个人版仓库 `registry.cn-hangzhou.aliyuncs.com/jiangood/opencode-docker:latest`（需配置仓库 secret `ALIYUN_PASSWORD`，未配置时只推 GHCR）
- GHCR 推送凭据：优先用仓库 secret `GHCR_PAT`（带 `write:packages` 的 token），未配置时回退 `GITHUB_TOKEN`（需 `packages: write`）。本仓库的 GHCR package 由 CI 首次推送创建并已关联本仓库，因此 `GITHUB_TOKEN` 即可推送

镜像私有可见时，运行前先登录：

```bash
docker login ghcr.io -u <用户名>
```

## 目录结构

```
opencode-docker/
├── Dockerfile              # 全部依赖从上游构建（含 Playwright 浏览器、中文字体、ui-ux-pro-max）
├── entrypoint.sh           # 启动共享服务 → 自动远程配对 → 日志保活
├── config/
│   └── opencode.json       # Playwright MCP 配置
├── scripts/pair.sh         # 重新生成配对链接
├── .github/workflows/docker.yml
└── workspace/              # 默认工作区（挂载点）
```

## 常用操作

```bash
docker exec -it opencode-remote bash                     # 进容器
docker exec opencode-remote opencode auth login      # 登录模型提供商
docker exec opencode-remote opencode service status  # 服务状态
docker exec opencode-remote playwright-mcp --help | head -5  # 验证 Playwright MCP
docker exec opencode-remote ls /opt/ms-playwright            # 验证浏览器已下载
docker exec opencode-remote fc-match sans-serif:lang=zh-cn  # 验证中文字体
docker stop opencode-remote                               # 停止（数据卷保留）
```

## 安全注意

- 远程配对会把服务器暴露到公网：流量端到端加密，密码由 opencode 自动生成
- 配对链接一次性、5 分钟内有效，不要分享给不信任的人
- 容器内 opencode 拥有 `/workspace` 的完整读写和 shell 执行权限，只挂载需要处理的代码目录
- 挂载的 gh 凭据（hosts.yml）容器内 agent 可读，相当于交出钥匙，建议用最小权限 token
- Playwright MCP 以 `--no-sandbox` 运行（容器内 Chromium 沙箱不可用），仅用于访问可信站点
