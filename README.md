# opencode-docker

OpenCode 2 的 Docker 封装，仅做 **OpenTunnel 远程配对**（端到端加密，不发布端口）。镜像由 GitHub Actions 构建并推送，本机只需拉取运行。

## 内置能力

| 分类 | 内容 |
| --- | --- |
| 运行时 | OpenCode 2、Node 22、Java 21 (Temurin)、Python 3、git、gh |
| 构建工具 | Maven 3.9、`build-essential`/`cmake`/`pkg-config`/`libssl-dev`、`python3-pip`/`python3-venv` |
| 常用工具 | ripgrep、jq、curl、wget、ssh、unzip/zip/xz、file、vim/nano、tmux、lsof/strace |
| 浏览器 | Playwright MCP + Chromium（headless，`--no-sandbox`） |
| 其他 | Noto CJK/Emoji 中文字体、[ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) 技能 |

## 快速开始

容器以 root 运行，`/data` 为唯一挂载点（代码、配置、凭据、会话数据均在其中）。

```bash
docker run -d --name opencode --restart unless-stopped \
  -v ~/opencode-docker-data:/data \
  ghcr.io/jiangood/opencode-docker:latest   # OWNER 替换为你的 GitHub 用户名/组织

docker logs -f opencode           # 查看配对链接
```

挂载目录结构（缺失的默认配置/技能首次启动自动补齐，不覆盖已有文件）：

```text
~/opencode-docker-data/
├── workspace/                 # 代码工作区（默认工作目录）
├── .config/opencode/          # OpenCode 配置与技能
├── .local/share/opencode/     # 会话、数据库、日志
├── .config/gh/hosts.yml       # 可选：gh 凭据
├── .gitconfig                 # 可选：git 身份
└── .git-credentials           # 可选：git 凭据
```

> 阿里云拉取：`registry.cn-hangzhou.aliyuncs.com/jiangood/opencode-docker:latest`（私有仓库需先 `docker login`）。

### 凭据与配对

- **gh/git 凭据（可选）**：按需复制 `~/.config/gh/hosts.yml`、`~/.gitconfig`、`~/.git-credentials` 到挂载目录；或运行时传入 `-e GH_TOKEN="$(gh auth token)"`。
- **重新配对**：`./scripts/pair.sh`（或 `docker exec opencode-docker-data opencode pair --remote --yes`），链接一次性、5 分钟有效；配对成功后 App 保存配置可长期使用。

## 常用命令

```bash
docker exec -it opencode bash
docker exec opencode opencode service status
docker exec opencode opencode --version
docker exec opencode mvn -v | head -2
docker exec opencode playwright-mcp --help | head -5
docker exec opencode fc-match sans-serif:lang=zh-cn
docker stop opencode
```

## 构建与仓库结构

- 推送 `main` 由 `.github/workflows/docker.yml` 构建 `linux/amd64` 并推送 `latest` 到 GHCR（及配置 `ALIYUN_PASSWORD` 时同步阿里云）；PR 仅构建验证。
- 主要文件：`Dockerfile`、`entrypoint.sh`、`config/opencode.json`、`scripts/pair.sh`。

## 安全提示

- 配对流量端到端加密，但服务会暴露到公网；配对链接勿泄露。
- 仅挂载必要目录，勿挂载宿主敏感路径；`gh`/git 凭据建议使用最小权限 token。
- Playwright 以 `--no-sandbox` 运行，仅访问可信站点。
