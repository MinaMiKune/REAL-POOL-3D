# REAL-POOL-3D 开发提示词

本目录用于驱动 Kimi 等代码代理按阶段开发本项目。所有阶段提示词必须与仓库当前代码、文档和实际工具链结合执行。

## 执行规则
1. 首先完整阅读 `00-project-master-prompt.md`。
2. 严格按编号顺序执行；一次只执行一个阶段。
3. 每阶段开始前检查 Git 状态、当前分支和未提交改动；不得覆盖或丢弃维护者工作。
4. 阶段门禁未通过不得进入下一阶段。完成后提交报告并等待维护者明确批准。
5. 不得只生成文档而不检查代码；也不得为追求进度虚构实现、测试、构建或设备验证结果。
6. 发现需求冲突、重大技术风险或需要新增依赖时，先说明证据、影响和备选方案，等待确认。
7. 所有测试记录命令、环境、结果；无法执行的项目标记为 BLOCKED，并说明原因。
8. 每阶段结束列出变更文件、关键实现、测试证据、遗留问题和建议的下一步。

## 阶段顺序
| 阶段 | 文件 | 目标 |
|---|---|---|
| 0 | 01-project-audit.md | 只读审计现状 |
| 1 | 02-architecture-design.md | 架构与技术方案 |
| 2 | 03-core-foundation.md | 工程基础 |
| 3 | 04-physics-engine.md | 台球物理 |
| 4 | 05-gameplay-system.md | 规则与 AI |
| 5 | 06-touch-camera-ui.md | 操作、镜头与界面 |
| 6 | 07-lan-multiplayer.md | 局域网对战 |
| 7 | 08-replay-training-lab.md | 回放与训练 |
| 8 | 09-audio-effects-polish.md | 音画反馈与打磨 |
| 9 | 10-android-optimization.md | Android 适配优化 |
| 10 | 11-testing-qa.md | 系统测试与质量门禁 |
| 11 | 12-release-final-acceptance.md | 发布验收 |

## 启动语句
请完整阅读 `prompts/README.md` 与 `prompts/00-project-master-prompt.md`。现在只执行 `prompts/01-project-audit.md`。严格遵守阶段门禁；完成后提交审计报告并等待我确认，不要自动进入下一阶段。
