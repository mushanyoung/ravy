# 测试目录规则

先读根目录 AGENTS.md；改夹具或测试契约时再读 docs/testing.md，Herdr 任务再读
docs/herdr-testing.md。使用真实解释器/PTY/SSH 验证主要用户行为。

保留 prefix guard、临时 HOME、账号启动文件隔离和精确进程清理。禁止访问 custom/、
使用用户密钥、调用模型、全局 pkill 或因依赖缺失跳过测试。
新增边界/异常测试应验证外部可见结果，不复制实现。断言失败与清理失败都必须可见。
