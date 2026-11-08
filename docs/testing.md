# 测试策略与质量门槛

`make setup` 按 `mise.lock`、`uv.lock`、`package-lock.json` 安装工具与依赖；
需要 mise 2026.11.4、Git、Make，以及系统 Fish、Zsh、Ruby、Docker CLI 和 OpenSSH。
Linux 还需 sshd 与 en_US.UTF-8 locale。开发工具通过 `scripts/mise/config.toml`
隔离个人 mise 配置；部署给用户的工具版本仍由 `dot_config/mise/config.toml` 管理。
锁文件覆盖 Linux/macOS 的 arm64/x64，升级时更新锁文件并运行完整检查。
[mise 锁文件规则](https://mise.jdx.dev/dev-tools/mise-lock.html)说明了安装时的校验行为。

`make check` 顺序执行以下六个阶段，即使某阶段失败仍继续收集其他阶段的结果，最终返回非零：

| 阶段      | 单独运行            | 覆盖                                                                         |
| --------- | ------------------- | ---------------------------------------------------------------------------- |
| 格式      | `make format-check` | Ruff、shfmt、fish_indent、StyLua、Taplo、Prettier                            |
| Lint      | `make lint`         | Ruff、ShellCheck 全级别、Fish/Zsh/Ruby 语法、actionlint、文档链接、diff 空白 |
| 类型      | `make typecheck`    | 全部 Python 脚本与测试，包括无扩展名命令，mypy 检查未标注函数体              |
| 单元/配置 | `make unit`         | shell 启动、安装分支、Neovim 保存、CLI 参数、Herdr 规则、检查失败传播        |
| E2E       | `make e2e`          | macOS developer；Linux server + developer；真实 PTY/SSH                      |
| 生产构建  | `make build`        | 隔离 HOME 渲染公共配置、语法/解析、无插件 Neovim 启动、打包及文件清单        |

`make format` 应用统一格式。迭代可以运行 `make test-herdr` 等窄目标；直接运行
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
- Herdr 0.9.5 热替换诊断属于已接受契约外的显式诊断，仍严格失败；版本或生命周期变更时重跑。
  Linux server 场景由 Linux 执行，macOS 执行适用的 developer 场景，不声称跨系统或 GUI 覆盖。
