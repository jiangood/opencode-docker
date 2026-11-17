# opencode-docker

OpenCode 2 的 Docker 封装，**只做一件事：OpenTunnel 远程配对**（端到端加密），手机 App / 桌面 App 扫码或粘贴链接即用。

镜像由 **GitHub Actions** 构建推送到 GHCR，本机只负责 `pull` 和运行。

## 内置能力

| 分类 | 内容 |
|---|---|
| 运行时 | OpenCode 2（官方 v2 安装脚本）、Node 22、Java 21 (Temurin)、Python 3、git、gh（GitHub CLI） |
| 远程 | OpenTunnel 端到端加密配对，容器不发布任何端口 |
| 浏览器 | Playwright MCP + Chromium（headless，`--no-sandbox`），可截图/自动化 |
| 中文字体 | Noto Sans CJK SC + Noto Color Emoji，构建时用 `fc-match` 断言生效，截图不会出现方块/乱码 |
| 技能 | [ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)（Dockerfile 从上游 CLI 安装） |

## 使用

容器以 **root** 运行（容器是 opencode 的专用环境，不是通用宿主机），宿主数据目录无需属主对齐。容器主目录 `/home/opencode` 是**唯一挂载点**：代码工作区、OpenCode 配置、gh/git 凭据、会话数据全在它下面。宿主机准备一个目录挂上即可，只挂这一个目录：

```bash
# 1) 宿主机准备数据目录（要处理的代码放进 workspace/ 里）
mkdir -p ~/opencode-remote/workspace

# 2) 启动容器（把 OWNER 换成你的 GitHub 用户名/组织）
docker run -d \
    --name opencode-remote \
    --restart unless-stopped \
    -v ~/opencode-remote:/home/opencode \
    ghcr.io/OWNER/opencode-docker:latest

docker logs -f opencode-remote   # 启动日志里有配对链接
```

挂载目录里的内容：

```
~/opencode-remote/           ← 挂到 /home/opencode（容器主目录）
├── workspace/               # 代码工作区（默认工作目录，把代码放这里）
├── .config/opencode/        # OpenCode 配置 + 技能（内置默认值首次启动自动补齐，已有文件不覆盖）
├── .local/share/opencode/   # 会话、数据库、日志（自动生成）
├── .config/gh/hosts.yml     # 可选：gh CLI 凭据
├── .gitconfig               # 可选：git 身份
└── .git-credentials         # 可选：git 凭据（credential.helper=store 时需要）
```

### 复用宿主机 gh/git 凭据（可选）

容器内需要用 `gh`（GitHub CLI）或 agent 推代码时，把凭据**复制**进挂载目录（复制后改动容器不感知，改完需重启容器）：

```bash
mkdir -p ~/opencode-remote/.config/gh
cp ~/.config/gh/hosts.yml ~/opencode-remote/.config/gh/
cp ~/.gitconfig ~/opencode-remote/
[ -f ~/.git-credentials ] && cp ~/.git-credentials ~/opencode-remote/
```

不想把凭据文件放进容器时，改用环境变量传 token：`docker run` 加 `-e GH_TOKEN="$(gh auth token)"`（git 推代码需在 `.gitconfig` 里配 credential helper 指向该 token，或直接给仓库 URL 带 token）。

### 国内网络拉取（阿里云杭州）

```bash
docker pull registry.cn-hangzhou.aliyuncs.com/jiangood/opencode-docker:latest
# 阿里云仓库私有，需先登录：
docker login registry.cn-hangzhou.aliyuncs.com -u <阿里云账号>
```

### 链接过期后重新生成

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
├── entrypoint.sh           # 合并内置默认 → 启动共享服务 → 自动远程配对 → 日志保活
├── config/
│   └── opencode.json       # Playwright MCP 配置（构建期存 /opt/opencode/defaults）
├── scripts/pair.sh         # 重新生成配对链接
└── .github/workflows/docker.yml
```

## 常用操作

```bash
docker exec -it opencode-remote bash                     # 进容器
docker exec opencode-remote opencode auth login      # 登录模型提供商
docker exec opencode-remote opencode service status  # 服务状态
docker exec opencode-remote playwright-mcp --help | head -5  # 验证 Playwright MCP
docker exec opencode-remote ls /opt/ms-playwright            # 验证浏览器已下载
docker exec opencode-remote fc-match sans-serif:lang=zh-cn  # 验证中文字体
docker stop opencode-remote                               # 停止（挂载目录保留）
```

## 安全注意

- 远程配对会把服务器暴露到公网：流量端到端加密，密码由 opencode 自动生成
- 容器以 root 运行：挂载目录是唯一入口，不要把宿主敏感目录（如 `/`、`~/.ssh`）挂进去
- 配对链接一次性、5 分钟内有效，不要分享给不信任的人
- 挂载目录里的所有文件容器内 agent 都可读写（含 shell 执行权限），只放需要处理的代码和凭据
- gh/git 凭据文件（hosts.yml / git-credentials）相当于交出钥匙，建议用最小权限 token
- Playwright MCP 以 `--no-sandbox` 运行（容器内 Chromium 沙箱不可用），仅用于访问可信站点
