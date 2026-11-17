# 容器环境说明（opencode-docker）

本容器是 OpenCode 2 的 Docker 运行环境，通过 OpenTunnel 远程配对使用（不发布端口，服务仅监听容器内 `127.0.0.1:4096`）。

## 目录与挂载

- **主目录 / 挂载点**：`/data`（`$HOME`、`WORKDIR`）。宿主机目录应挂载到此路径；该目录内容由宿主机持久化。
- **工作区**：`/data/workspace`（默认工作目录，容器启动后 `cd` 到此处）。请将需要处理的代码放在这里。
- **OpenCode 配置**：`/data/.config/opencode/`（`opencode.json`、技能等）。镜像内置默认配置仅在缺失时自动补齐，不覆盖已有文件。
- **数据与日志**：`/data/.local/share/opencode/`（会话、数据库、日志等，自动生成）。
- **凭据（可选，放在挂载点内）**：`~/.config/gh/hosts.yml`（`gh`）、`~/.gitconfig`、`~/.git-credentials` 等。

## 运行方式

- 以 **root** 身份运行（`HOME=/data`），因此主目录下的配置/凭据路径位于 `/data` 而非 `/root`。
- 二进制与内置默认资源位于主目录之外，不会被挂载覆盖：`opencode` 在 `/usr/local/bin/opencode`，内置默认配置与技能在 `/opt/opencode/`（启动时按需合并进主目录）。

## 内置工具链（镜像提供）

- 运行时：Node.js 22、Java 21 (Temurin)、Python 3、`git`、`gh`
- 构建与语言工具：Maven、`build-essential`/`cmake`/`pkg-config`/`libssl-dev`、`python3-pip`/`python3-venv`
- 常用工具：`ripgrep`、`jq`、`curl`、`wget`、`ssh`、`unzip`/`zip`/`xz-utils`、`file`、`vim`/`nano`、`tmux`、`lsof`/`strace` 等
- 中文字体：Noto Sans CJK SC / Noto Color Emoji

## 使用提示

- 需要持久保存的文件应放在 `/data`（挂载点）下，尤其是 `workspace/` 与 `.config/`、`.local/`。
- 仅将必要的代码与凭据目录挂入容器，避免挂载宿主机敏感目录。
- 重新生成配对链接：`opencode pair --remote --yes`。
