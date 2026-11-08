# 公共项目与 custom 私有仓库的契约

项目根目录是 Git 工作树。`.chezmoiroot` 将公共配置源限定在 `chezmoi/`，
根目录 `custom/` 是可选的独立 Git 仓库，由根 `.gitignore` 排除，既不是 submodule
也不是公共 source state 的一部分。公共提交只包含接口和合成测试，不包含私有文件。

| 名称                                         | 含义                                                                 |
| -------------------------------------------- | -------------------------------------------------------------------- |
| `RAVY_HOME` / `.chezmoi.workingTree`         | 公共项目根目录，含 bin/、安装器、文档与检查                          |
| `.chezmoi.sourceDir` / `chezmoi source-path` | 实际公共 source state，即项目根目录下 chezmoi/                       |
| `RAVY_PRIVATE_HOME`                          | 私有仓库/源；显式值优先，默认 `$RAVY_HOME/custom`                    |
| 私有配置/状态                                | `~/.config/chezmoi/ravy-private.toml` 和 `ravy-private-state.boltdb` |

没有显式私有路径时，继续识别旧位置 `~/.local/share/ravy-private` 与 `~/.ravy-private`。
mise 私有 include 的显式覆盖是权威选择：指定位置不存在时输出为空，不回退读取另一份私有配置。
`RAVY_PRIVATE_REPO` 仅在用户选择安装私有源时用于 clone/update；没有私有仓库也能使用公共项目。

安装顺序保持公共源 → Homebrew → 私有源 → 可选私有 install.sh → 刷新私有 mise include → mise install。
私有源读取前收紧根目录为 0700；bootstrap age 密钥与解密仍属于私有安装流程。
`custom/mise/config.toml` 是唯一被公共 mise include 模板直接组合的私有工具接口。
其他覆盖通过私有 chezmoi apply、`~/.config/ravy/` 配置与 shell/Neovim 加载点完成。

日常 `chez apply/diff/status` 先公共再私有；`chez private ...` / `chezp` 明确选择私有源。
`ravy` 跳到项目根目录；`ravyprivate` / `ravyc` 跳到私有仓库。公共失败时不继续私有操作。
私有源有单独 config/state，不能复用公共状态或移入公共 `chezmoi/`。

本次布局迁移使用 [chezmoi 原生 .chezmoiroot](https://www.chezmoi.io/reference/special-files/chezmoiroot/)。
已有 checkout 不需要重克隆，也不需要改本机 `sourceDir`：保持它指向项目根目录，chezmoi 自动进入
source state 子目录。`chezmoi init/update/add/edit` 继续由同一 Git 工作树管理。
shell 重新渲染时记录 workingTree；原来记录的项目根目录仍有效。`custom/` 内容与 Git 历史无需迁移。

验证使用合成私有夹具；构建先复制公共 Git 输入到隔离 checkout，再渲染，不能读取真实 custom。
迁移后用 `chezmoi source-path ~/.gitconfig` 确认指向 `chezmoi/dot_gitconfig`，
用 `make check` 验证路径、私有优先级、安装分支与终端流程。
