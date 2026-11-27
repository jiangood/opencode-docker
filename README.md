# opencode-docker

OpenCode 2 的 Docker 封装，默认以 **共享服务模式**（前台 `opencode serve --service`）运行：这个前台进程本身就是 OpenCode 的共享后台服务，容器内的 TUI / `opencode pair` / `opencode api` 会自动复用它；宿主通过 `-p` 映射 `4096` 端口访问；需要外网时再进入容器手动开启 OpenTunnel 配对（端到端加密）。镜像由 GitHub Actions 构建并推送，本机只需拉取运行。

## 内置能力

| 分类 | 内容 |
| --- | --- |
| 运行时 | OpenCode 2、Node 22、Java 21 (Temurin)、Python 3、git、gh |
| 构建工具 | Maven 3.9、`build-essential`/`cmake`/`pkg-config`/`libssl-dev`、`python3-pip`/`python3-venv` |
| 常用工具 | ripgrep、jq、curl、wget、ssh、unzip/zip/xz、file、vim/nano、tmux、lsof/strace |
| 其他 | Noto CJK/Emoji 中文字体、[ui-ux-pro-max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) 技能 |

## 快速开始

容器以 root 运行，`/data` 为唯一挂载点（代码、配置、凭据、会话数据均在其中），服务以 `opencode serve --service` 前台监听容器内 `0.0.0.0:4096`，并把自己注册为 OpenCode 的共享服务（注册信息在 `/data/.local/state/opencode/service.json`）。

```bash
docker run -d --name opencode --restart unless-stopped \
  -v /home/opencode-docker-data:/data \
  -p 127.0.0.1:4096:4096 \
  ghcr.io/jiangood/opencode-docker:latest
```

`-p 127.0.0.1:4096:4096` 只允许本机访问服务；需要局域网其他机器直连时改成 `-p 4096:4096`（注意防火墙与密码）。

国内镜像

```bash
docker run -d --name opencode --restart unless-stopped \
  -v /home/opencode-docker-data:/data \
  -p 127.0.0.1:4096:4096 \
  registry.cn-hangzhou.aliyuncs.com/jiangood/opencode-docker:latest
```

查看启动日志与服务密码

```bash
docker logs -f opencode
```

日志里会打印 `server listening on http://0.0.0.0:4096` 和 `服务密码: <密码>（来源: ...）`。

密码规则（按优先级）：

1. **环境变量**：`docker run` 时加 `-e OPENCODE_PASSWORD="一个足够长的密码"`，CLI 客户端也读同一个变量。
2. **持久化文件**：未设置环境变量时，首次启动生成随机密码并保存到挂载目录的 `.config/opencode/server-password`（权限 `600`），之后重建、更新容器都会复用，不再变化。可在宿主执行 `cat /home/opencode-docker-data/.config/opencode/server-password` 查看。
3. **重置密码**：删除该文件后重启容器会重新生成；或直接设置 `OPENCODE_PASSWORD` 覆盖（此时不再使用文件）。

> 共享服务模式下，服务进程的密码/地址取自 `.config/opencode/service.json`（权限 `600`），该文件由 entrypoint 在每次启动时用上面的密码改写（`hostname=0.0.0.0`、`port=4096`），请不要手动改它来换密码，以上面的环境变量或 `server-password` 文件为准。

连接服务

- 浏览器打开 `http://127.0.0.1:4096`，HTTP Basic 认证，用户名固定 `opencode`，密码为启动日志或 `server-password` 文件里的值。
- CLI 客户端：`OPENCODE_PASSWORD="<密码>" opencode --server http://127.0.0.1:4096`。

容器首次启动会自动在挂载目录下建好 `workspace`，无需手动创建；宿主目录不存在时 Docker 也会自动创建。

挂载目录结构（缺失的默认配置/技能与 `workspace` 首次启动自动补齐，不覆盖已有文件）：

```text
/home/opencode-docker-data/
├── workspace/                 # 代码工作区（默认工作目录，镜像自动创建）
├── .config/opencode/          # OpenCode 配置、技能与服务密码（server-password）
├── .local/share/opencode/     # 会话、数据库、日志
├── .config/gh/hosts.yml       # 可选：gh 凭据
├── .gitconfig                 # 可选：git 身份
└── .git-credentials           # 可选：git 凭据
```

> 阿里云拉取：`registry.cn-hangzhou.aliyuncs.com/jiangood/opencode-docker:latest`（私有仓库需先 `docker login`）。

### 远程配对（可选，手动开启）

默认不配对、不暴露公网。需要从外网连接时，进入容器手动开启：

```bash
docker exec -it opencode bash
opencode pair --remote --yes
```

也可在宿主直接执行 `./scripts/pair.sh`（等价于 `docker exec opencode opencode pair --remote --yes`）。链接一次性、5 分钟内有效，手机 App 扫码或粘贴后会在本地保存配置，可长期使用。

> `opencode pair` 连接的就是容器内正在运行的**共享服务**（同一个进程，即 `serve --service` 监听的 4096），不会再额外拉起第二个实例，也不会出现端口冲突；配对后直连端口和隧道指向同一份会话数据。可用 `docker exec opencode opencode service status` 确认服务地址。
>
> 不带 `--remote` 的本地配对链接会列出容器内可用的地址（如 `127.0.0.1:4096`、容器 IP）；从宿主或其他机器访问时可加 `--url http://<宿主地址>:4096` 指定链接中的服务地址。

旧镜像或手工改过 `.config/opencode/service.json` 时，配对可能报 `Managed service port 4096 ... already in use by another process`：说明旧配置把共享服务端口定成了 4096，与前台服务冲突。新版 entrypoint 启动时会把 `hostname/port/password` 重新同步为 `0.0.0.0/4096/当前密码`；临时处理可删除该文件后重启容器。

### 凭据

- **gh/git 凭据（可选）**：按需复制 `~/.config/gh/hosts.yml`、`~/.gitconfig`、`~/.git-credentials` 到挂载目录；或运行时传入 `-e GH_TOKEN="$(gh auth token)"`。

## 常用命令

```bash
docker exec -it opencode bash
docker exec opencode opencode --version
docker exec opencode curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:4096/api/info   # 401 表示服务在跑（需密码）
docker exec opencode mvn -v | head -2
docker exec opencode fc-match sans-serif:lang=zh-cn
docker stop opencode
```

> 共享服务就是容器的主进程：不要在运行中的容器里执行 `opencode service stop/restart/set ...`，这些命令会停掉服务并导致容器退出。需要换地址或密码时，改 `OPENCODE_PASSWORD`（或 `server-password` 文件）后重启容器，由 entrypoint 重新同步配置。

## 构建与仓库结构

- 推送 `main` 由 `.github/workflows/docker.yml` 构建 `linux/amd64` 并推送 `latest` 到 GHCR（及配置 `ALIYUN_PASSWORD` 时同步阿里云）；PR 仅构建验证。
- 主要文件：`Dockerfile`、`entrypoint.sh`、`config/opencode.json`、`scripts/pair.sh`。

## 安全提示

- 默认端口映射建议只绑 `127.0.0.1`；用 `-p 4096:4096` 会暴露到所有网卡，请配合防火墙，必要时改用 SSH 隧道或 TLS 反向代理。
- 服务本身已有密码保护：优先 `OPENCODE_PASSWORD`，否则使用挂载目录里持久化的随机密码。但 HTTP Basic 在明文 HTTP 下可被嗅探，公网暴露不要只依赖密码。
- 远程配对流量端到端加密，但服务会暴露到公网；配对链接勿泄露。
- 仅挂载必要目录，勿挂载宿主敏感路径；`gh`/git 凭据建议使用最小权限 token。
