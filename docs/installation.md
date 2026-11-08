# 安装与路径迁移

[README](../README.md#installation) 提供 Public-only 与 Public + private 两条安装命令。
需要 macOS/Linux、Git、curl，以及下载工具和仓库的网络访问；Homebrew 安装或切换登录 shell
可能需要 sudo。私有仓库须能通过普通 Git 认证访问，SSH agent forwarding 可直接复用。

## 安装位置

新机器默认克隆到 `~/.ravy`。位置选择依次为显式 `RAVY_HOME`、chezmoi 当前指向的已有
Git checkout、`~/.ravy`；不会自动移动已有 `~/.local/share/chezmoi` 安装。
`RAVY_HOME` 必须是绝对路径。配置模板把工作树路径保存为 `sourceDir`，所以后续直接运行
`chezmoi` 仍指向同一仓库。`.chezmoiroot` 再选择其中的 `chezmoi/` 配置子目录。

| 环境变量               | 用途                                                                   |
| ---------------------- | ---------------------------------------------------------------------- |
| `RAVY_HOME`            | 公共仓库绝对路径                                                       |
| `RAVY_REPO`            | 公共仓库 URL，默认 `mushanyoung/ravy`                                  |
| `RAVY_PRIVATE_REPO`    | 可选私有仓库 URL；设置后 clone 或 `pull --ff-only`                     |
| `RAVY_PRIVATE_HOME`    | 私有仓库绝对路径，默认 `$RAVY_HOME/custom`；仍识别旧私有目录           |
| `RAVY_SKIP_CHSH=1`     | 不修改登录 shell 或 `/etc/shells`                                      |
| `RAVY_CHEZMOI_FORCE=1` | 公共和私有 apply 都覆盖托管文件的本地改动；默认保留 chezmoi 的冲突提示 |

重复安装会重新应用当前公共 checkout，不自动拉取公共提交；需要更新时，
在公共仓库内执行 `git pull --ff-only` 后重新运行安装器。已有私有 checkout 在不设置
`RAVY_PRIVATE_REPO` 时仍会应用；显式私有路径不会回退执行其他目录的 `install.sh`。

## 移动已有 checkout 到 ~/.ravy

先更新到包含新安装器与配置模板的版本，并确认 `~/.ravy` 尚不存在。对于默认旧路径，
从仓库外执行以下命令，保留工作树、Git 历史及其中的 `custom/`：

```sh
cd "$HOME"
test ! -e "$HOME/.ravy" && test ! -L "$HOME/.ravy" && \
  mv "$HOME/.local/share/chezmoi" "$HOME/.ravy" && \
  env -u RAVY_PRIVATE_HOME RAVY_HOME="$HOME/.ravy" bash "$HOME/.ravy/install.sh"
```

`env -u` 清除旧 shell 继承的 `RAVY_PRIVATE_HOME`，让内嵌 `custom/` 跟随新位置。
若私有仓库在另一个自定义目录，改为显式传入它的绝对路径。确认移动成功后再运行安装器；
它会重新生成公共/私有配置和 shell 内记录的路径。最后开启新终端，并用
`chezmoi source-path` 确认结果为 `~/.ravy/chezmoi`。密钥和独立状态仍留在原配置目录。

## 安装过程

安装器从 HOME 调用 mise，避免继承仓库开发工具配置。依次应用公共配置、准备可选私有
checkout 和 age 密钥、安装 Homebrew bundle、应用私有配置并运行其安装脚本、刷新
私有 mise include、加载托管 secrets 并安装 mise 工具，最后切换登录 shell。
npm 工具存在时先安装 Node。Brewfile 固定为 `~/.config/homebrew/Brewfile`。

私有目录读取前设为 0700。若 `~/.config/chezmoi/key.txt` 不存在且仓库带有
`bootstrap/key.txt.age`，会提示口令并以 0600 权限保存解密后的密钥；失败不会留下
半写入密钥，可重新运行。私有配置与状态隔离规则见 [私有覆盖契约](private-overlay.md)。

Shell 在 apply 时记录源码目录和 Homebrew 元数据，安装位置移动后应重新渲染。
非交互 Fish 使用 mise shims，不安装交互钩子。Bash/Zsh/Fish 都用 `umask go-w`
移除新文件的组/其他用户写权限；例如 0002 变为 0022，0027/0077 保持不变。
