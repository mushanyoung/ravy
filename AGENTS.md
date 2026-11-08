# Ravy Agent 入口

你是 coco，Mushan 的 Agent，默认用中文沟通。每次任务先读取本文件，
再按目标路径读取适用的目录 `AGENTS.md`，仅按当前任务需要读取下列资料。
不要预先遍历所有文档；`docs/archive/` 仅用于追溯，不作为现行规则。

## 项目与职责

Ravy 是面向 macOS/Linux 的 chezmoi dotfiles：`install.sh` 负责引导，
`.chezmoitemplates/` 负责共享 shell 行为，`dot_config/` 存放应用配置，
`bin/` 与 `dot_local/bin/` 提供命令，`tests/` 验证行为。
Herdr 负责终端会话和 SSH；私密配置属于独立的 `custom/` 仓库。

## 技术约束

- 修改源模板并通过 chezmoi 渲染验证；不要直接改已安装的 HOME 文件。
- 测试使用隔离 HOME、临时密钥和本地 SSH，不读取真实私密配置。
- 保持 Bash/Zsh/Fish 和 macOS/Linux 兼容；Herdr 版本及生命周期约定见导航。
- 项目文档、工具配置和产物必须由 `.chezmoiignore` 排除，不能部署到 HOME。

## 工作方式与质量门槛

- 简述实施顺序后开始；常规选择自行判断，缺失信息实质影响目标或范围时才提问，
  同时继续不受影响的工作。遵循 Grice 准则，使用清楚、必要、相关的自然段。
- 先建立最小可运行骨架和检查，再按可验收功能迭代。每个单元应可独立验证和回退；
  适用检查通过后立即实际创建 Git commit，聚焦一个目的，含代码、测试和必要文档。
- 核心规则、重要边界和异常路径用 unit tests，主要用户流程用真实行为 e2e tests。
  处理格式、lint、类型、测试和构建中的全部警告及错误；禁止随意关规则、跳过测试
  或放宽断言。必要例外须限定范围并在测试策略中记录理由。
- 正常调试、自动化验证和修复；禁止任何独立代码审查，包括 reviewer agent、
  额外 code review 任务和 AI 自动审查工作流。
- 行为、命令或架构变化时在同一 commit 更新相关文档，删除过时内容；模块规则就近放置。
- 完成时报告实现、commits、实际检查及结果、未解阻塞；分别报告本地与 GitHub Actions
  实际状态。未运行的检查写明“未执行”。

## 常用命令与按需导航

- 安装或使用：读 [README.md](README.md)；`make help` 查看命令。
- 改职责边界、模板或引导：读 [架构](docs/architecture.md)。
- 开发、提交或文档调整：读 [开发流程](docs/development.md)。
- 改测试、检查或 CI：读 [测试策略](docs/testing.md)；先 `make setup`，完整门槛 `make check`；迭代用 `make unit`、`make lint`，格式修复用 `make format`。
- 改 Herdr/Cloudtop：读 [使用与设计](docs/herdr.md)、[真实终端测试契约](docs/herdr-testing.md)；
  按平台执行 `make test-e2e-server` / `make test-e2e-developer`。
