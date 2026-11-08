# 架构与边界

Ravy 的生产输出是 chezmoi 渲染后的用户配置与脚本。仓库自身不是 Web 应用，
没有前端 bundle 或服务端发布包。生产验证必须覆盖实际渲染和目标文件语法。

`install.sh` 依次准备 mise/chezmoi/age、应用公共源、安装 Homebrew 软件、
应用可选私有源并安装 mise 工具。安装测试通过命令替身验证分支，不能运行真实引导来做测试。

`chezmoi/.chezmoitemplates/` 汇集 shell 的环境、别名与交互行为，chezmoi/ 下的 shell 和 Fish 入口模板组合它们。
非交互启动不能意外安装交互钩子；保留继承的 SSH_AUTH_SOCK 和更严格的 umask。
渲染路径由 chezmoi 决定，修改模板后要覆盖含空格路径和移动 checkout 的情形。

`chezmoi/dot_config/nvim/` 为 Lua 配置；测试通过 `RAVY_NVIM_SKIP_PLUGINS=1` 禁止下载插件。
插件安装属于用户操作，不应在基础测试或构建中访问插件仓库。

Herdr 原生管理会话、SSH、重连与布局持久化，Cloudtop 只处理参数。
标题与第十标签适配器的边界及已接受的 agent 生命周期例外见 [Herdr](herdr.md)
和 [测试契约](herdr-testing.md)。不要引入另一个 SSH 控制层。

`.chezmoiroot` 选择 `chezmoi/` 作为公共 source state，项目根目录继续作为 Git 工作树。
`RAVY_HOME` 来自 `.chezmoi.workingTree`，用于根目录 bin/ 与 custom/；
`.chezmoi.sourceDir` 专指配置子目录，不能用于推导项目根目录。
原生 `.chezmoiroot` 使 clone/update 和已有本机 sourceDir 保持兼容，避免维护大批仓库文件排除项。

`custom/` 是根目录下的独立私有源；位置、覆盖顺序与兼容接口见 [私有覆盖契约](private-overlay.md)。
公共测试用合成夹具，构建复制公共 Git 输入到临时 checkout 后渲染，不能读取真实 custom/。
`docs/`、`tests/`、工具和产物天然在部署源外；源内的 AGENTS.md 仍须由 `.chezmoiignore` 排除。
