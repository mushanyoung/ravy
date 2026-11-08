# 测试策略与质量门槛

`make setup` 按 `mise.lock`、`uv.lock` 安装工具与依赖；
需要 mise 2026.11.4、Git、Make，以及系统 Fish、Zsh、Ruby、Docker CLI 和 OpenSSH。
Linux 还需 sshd、en_US.UTF-8 locale 与 Node 26 所需的 libatomic1。开发工具通过 `scripts/mise/config.toml`
隔离个人 mise 配置；部署给用户的工具版本仍由 `chezmoi/dot_config/mise/config.toml` 管理。
锁文件覆盖 Linux/macOS 的 arm64/x64，升级时更新锁文件并运行完整检查。
[mise 锁文件规则](https://mise.jdx.dev/dev-tools/mise-lock.html)说明了安装时的校验行为。

开发基线为 Python 3.15 和 Node 26 的最新补丁版本，其余 mise 工具选择最新稳定版。
`mise.lock` 保存实际解析版本、平台和校验和；`make setup/check` 使用锁定模式，不在每次检查时漂移。
更新时运行 `MISE_CONFIG_DIR="$PWD/scripts/mise" mise lock --bump`，再更新 Python 依赖与 `uv.lock`，
执行 `make setup format check` 并一起提交配置、锁文件及必要的兼容修复。
Ruff、mypy 和 json5 也使用当前稳定版。Node 保留为项目开发工具；格式化链路不依赖 Node/npm。
Herdr 当前最新仍是 0.9.5，版本变更后必须同步更新 E2E 契约与诊断。
独立 bin/ 与托管命令由 env python3 启动，远端终端可能选择系统 Python（本机 macOS 27 仍为 3.9）。
它们的 Ruff 语法目标保留 py39；项目开发和测试仍使用锁定的 Python 3.15。

`make check` 顺序执行以下六个阶段，即使某阶段失败仍继续收集其他阶段的结果，最终返回非零：

| 阶段      | 单独运行            | 覆盖                                                                          |
| --------- | ------------------- | ----------------------------------------------------------------------------- |
| 格式      | `make format-check` | Ruff、shfmt、fish_indent、StyLua、Taplo、dprint                               |
| Lint      | `make lint`         | Ruff、ShellCheck 全级别、Fish/Zsh/Ruby 语法、jactionlint、文档链接、diff 空白 |
| 类型      | `make typecheck`    | 全部 Python 脚本与测试，包括无扩展名命令，mypy 检查未标注函数体               |
| 单元/配置 | `make unit`         | shell 启动、安装分支、Neovim 保存、CLI 参数、Herdr 规则、检查失败传播         |
| E2E       | `make e2e`          | macOS developer；Linux server + developer；真实 PTY/SSH                       |
| 生产构建  | `make build`        | 隔离 HOME 渲染公共配置、语法/解析、无插件 Neovim 启动、打包及文件清单         |

dprint 由 mise 安装；Markdown、JSON/JSONC 和 YAML 插件使用 `dprint.json` 中
固定版本与 SHA-256 的 WASM 文件，不需要 npm 或 package.json。

`make format` 应用统一格式，`make lint-herdr` 是完整 lint 门槛的兼容别名。
Python 窄目标使用项目 .venv，避免回落到系统 Python；先运行 make setup。迭代可以运行 `make test-herdr` 等窄目标；直接运行
`make test` 时须使用已准备的工具链与隔离 HOME，推荐使用自动隔离的 `make unit`。
主检查日志与退出码写入 `artifacts/check/`，生产渲染产物写入 `dist/`。
渲染包包含本次验证路径，是供检查的生产配置快照；实际安装仍通过 chezmoi 在目标机渲染。

核心规则、重要边界与异常使用 unit tests。引导脚本用命令替身覆盖安装分支，
shell 与 Neovim 用真实解释器验证行为。主要终端流程用真实 PTY、Herdr 与回环 SSH；
完整覆盖、隔离及恢复操作见 [Herdr 测试契约](herdr-testing.md)。
缺少依赖必须失败，原有可选 prompt 集成现在也要求实际运行。

测试只可操作夹具 HOME、进程、socket 和临时 SSH 密钥。父测试进程也必须隔离 HOME，
避免 Fish 启动加载账号配置。Neovim 保存夹具用独立 EditorConfig 截断仓库规则。
报告保留阶段日志、失败断言和结果，不归档 HOME、私有配置、环境全量输出或密钥。
GUI IME、剪贴板、真实 WAN、睡眠恢复需目标终端/主机人工验收。

## 有限例外与理由

不得随意关规则、跳过测试、弱化断言或使用 continue-on-error。以下是明确边界：

- Go 模板不能直接交给 shell 格式化器；生产构建检查真实渲染后的 Bash/Zsh/Fish，
  现有配置测试覆盖分支。Zsh 脚本使用 Zsh 语法检查，shfmt/ShellCheck 不支持 Zsh。
- `bin/chrome-bookmarks` 的 Bash 前缀单独格式化与 ShellCheck，Ruby 正文由 `ruby -cx` 检查。
  Lua 由 StyLua 解析并由真实 Neovim 测试；静态类型检查适用于 Python。
- `bin/ydiff` 唯一 `attr-defined` 豁免对应上游使用的 `difflib._mdiff`：CPython 提供它，typeshed 不声明。
- ShellCheck 行内豁免仅用于 jq/子 shell 的有意延迟展开（SC2016）、chezmoi 从源读而向目标写
  （SC2094）、EXIT 回调（SC2329）、ANSI 正则清理（SC2001）；理由写在对应行旁。
- `docs/archive/` 保留原始历史记录，不格式化或作为当前链接门槛；其他文档自动检查导航。
- CI 的 `push` 行仅豁免 jactionlint `duplicate-triggers`：契约要求没有 PR 的分支提交也检查，
  且分支提交与 PR 合并结果都需验证。按事件与 ref 隔离并发组，仅取消同组被新提交替代的运行。
- Herdr 0.9.5 热替换诊断属于已接受契约外的显式诊断，仍严格失败；版本或生命周期变更时重跑。
  Linux server 场景由 Linux 执行，macOS 执行适用的 developer 场景，不声称跨系统或 GUI 覆盖。

## CI 与 Linux 本地复现

GitHub Actions 的 `quality` 在 push、pull_request 上对 ubuntu-26.04、macos-26
执行同一个 `make check`。Actions 固定 commit SHA，mise 固定 2026.11.4；工具与 Python
依赖按锁文件安装。平台包由固定 OS 的 apt/Homebrew 提供，平台镜像会收到系统更新，
不声称按位重现整个托管 runner。任意阶段失败使 job 失败；独立矩阵继续收集结果。

无论成功或失败，上传 `artifacts/` 和 `dist/`，保留七天。E2E 提供 JSON 结果，失败时保存
夹具 PTY、Herdr 与 sshd 日志，绝不归档临时密钥或 HOME。此 workflow 不运行 AI 审查。
workflow lint 使用支持 Ubuntu 26.04 标签的 [jactionlint](https://github.com/jdx/jactionlint)，
替代标签表尚未更新的 actionlint 1.7.12；警告也使 lint 失败，唯一触发器策略例外见上文。
只有显式 workflow_dispatch 的 agent_rotation 输入才运行已知失败的严格诊断。

本地 `make check` 验证当前主机；受支持的验证基线为 Ubuntu 26.04 与 macOS 26 或更新版本，
不再维护旧版 OS 的测试矩阵。Linux 可在 Ubuntu 26.04 隔离容器复现；
镜像摘要固定，构建上下文仅包含 Dockerfile。
容器仅需要公共源码，不挂载 custom/、账号 HOME 或 Docker socket：

```sh
docker build -t ravy-quality:local -f tests/ci.Dockerfile .
docker run -d --name ravy-quality-run ravy-quality:local sleep infinity
git archive HEAD | docker exec -i ravy-quality-run tar -x -C /workspace
docker exec ravy-quality-run sh -c 'git init -q && git add . && make setup && make check'
docker cp ravy-quality-run:/workspace/artifacts ./artifacts/linux
docker rm -f ravy-quality-run
```

上述流程检查已提交的 HEAD；未提交改动应先完成逻辑单元并提交。容器里的 Git 索引用于
枚举公共源码，和实际项目一样覆盖所有已跟踪文件。GitHub Actions 是否运行、是否通过，
必须单独查询实际状态；本地容器通过不能代替 CI 状态。
