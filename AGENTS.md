# Breeze 开发约定

- 按工作区约定复用现有模拟器与应用数据。界面和交互任务使用工作区中的 Breeze UI 规范原件。
- 从实际用户入口写验收条件，注明平台、宿主与验证方式。改共用能力时检查相关调用点，验证成功、失败和恢复路径。
- 账号与下载改动复用 `bash script/test/mobile_regressions.sh account` 或 `download`。集成前运行 `bash script/test/mobile_regressions.sh`，与现有 PR 检查使用同一入口。
- 交付结论以实际测试日志、模拟器或真机记录为依据。任务验收格式、发布核对命令和证据要求见 [开发验收与发布核对](docs/development-verification.md)。
