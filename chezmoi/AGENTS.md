# 公共配置源规则

每次先读仓库根目录 AGENTS.md；此目录是 `.chezmoiroot` 指定的 source state。
改模板、部署路径或私有覆盖时读 docs/architecture.md 与 docs/private-overlay.md。

`.chezmoi.sourceDir` 指本目录；`.chezmoi.workingTree` 和 `RAVY_HOME` 指项目根目录。
项目命令仍在根目录 bin/，默认私有仓库仍在根目录 custom/。
不要以 sourceDir 推导项目根目录或私有仓库，不把开发依赖、文档、测试放入部署源。
目录内新增 AGENTS.md 必须被此处 `.chezmoiignore` 排除。
