# 需求追踪表

## 1. 状态说明

“设计”表示本阶段文档覆盖；所有运行功能仍未实现。`BLOCKED` 表示缺少 Godot/Android 工具链或被测工程；`NOT RUN` 表示属于后续功能阶段、当前没有可执行对象。验证 ID 对应本阶段探针及后续测试矩阵，不把设计追踪当成验收通过。

## 2. 产品目标到架构与阶段

| 需求 ID | 目标/验收要点 | 架构模块与文档 | ADR | 验证方式与当前状态 | 后续阶段 |
|---|---|---|---|---|---|
| REQ-01 | Godot 4.x 可导入、启动、模块边界清晰 | App/MatchController；[总览](01-overview.md)、[接口](02-module-interfaces.md) | [ADR-001](adr/ADR-001-godot-4-7-2-gdscript.md) | 工具/工程 BLOCKED；最小导入启动待阶段 2 | 2 |
| REQ-02 | 三维球桌、球体、球杆与镜头 | Table/Ball/Cue Views、CameraRig；[Android/渲染](07-android-and-rendering.md) | [ADR-008](adr/ADR-008-renderer-device-gate.md) | 渲染/资源/视觉 BLOCKED | 2、4、6、9 |
| REQ-03 | 可信可调校 2.5D 物理、旋转、库边、袋口 | PhysicsWorld/Predictor；[物理](03-physics-model.md) | [ADR-002](adr/ADR-002-custom-2-5d-physics.md) | Python 公式探针 VAL-PHY；Godot 数值/场景 BLOCKED | 3、4 |
| REQ-04 | 完整美式 8 球状态机 | RulesReducer；[规则/AI](04-rules-and-ai.md) | [ADR-003](adr/ADR-003-wpa-rules-reducer.md) | 规则矩阵 RULE-* NOT RUN；无实现 | 5 |
| REQ-05 | 五档非作弊 AI，瞄准/力度/走位/失误差异 | AiPlanner、克隆预测、seed；[规则/AI](04-rules-and-ai.md) | [ADR-010](adr/ADR-010-ai-fairness-and-seeds.md) | 合法性/复现/强度/性能 NOT RUN | 5、11 |
| REQ-06 | LAN 双人、发现、主机权威、重连和输入验证 | LanSession/UDP/ENet；[网络](05-network-protocol.md) | [ADR-004](adr/ADR-004-lan-host-enet.md) | Godot 双进程/双设备 BLOCKED | 2 PoC、7 |
| REQ-07 | 完整触控瞄准、力度、杆点、镜头，防误触 | InputRouter 手势状态机；[Android/渲染](07-android-and-rendering.md) | [ADR-007](adr/ADR-007-responsive-touch-input.md) | 真实多点触控 BLOCKED | 6 |
| REQ-08 | 横竖屏、安全区、比例、分屏/大屏适配 | ResponsiveLayout；[Android/渲染](07-android-and-rendering.md) | [ADR-007](adr/ADR-007-responsive-touch-input.md)、[ADR-009](adr/ADR-009-android-api37.md) | 方向/窗口/安全区设备测试 BLOCKED | 6、10 |
| REQ-09 | Mobile/Compatibility 实测选型与自适应画质 | QualityService；[性能](08-performance-testing-diagnostics.md) | [ADR-008](adr/ADR-008-renderer-device-gate.md) | 双构建和性能 BLOCKED | 2 PoC、9、10 |
| REQ-10 | SQLite 战绩、设置、回放索引，事务/迁移/备份 | MatchRepository；[数据](06-data-and-replay.md) | [ADR-005](adr/ADR-005-sqlite-conditional-v4-9.md) | Python SQL VAL-SQL；插件桌面/Android BLOCKED | 2 |
| REQ-11 | 可复现回放、版本/seed/hash、旧版降级 | ReplayRecorder/Player；[数据](06-data-and-replay.md) | [ADR-006](adr/ADR-006-snapshot-command-replay.md) | 编解码/重算/快照/版本 NOT RUN | 8 |
| REQ-12 | 训练任务、评分和独立进度 | training_attempts、TrainingService；[数据](06-data-and-replay.md) | [ADR-005](adr/ADR-005-sqlite-conditional-v4-9.md) | 后续功能 NOT RUN；隔离查询待测 | 8 |
| REQ-13 | 物理实验室、参数可视化且不污染正式比赛 | Lab 配置副本、PhysicsPredictor；[数据](06-data-and-replay.md) | [ADR-002](adr/ADR-002-custom-2-5d-physics.md) | 后续功能 NOT RUN；配置隔离待测 | 8 |
| REQ-14 | 事件驱动音效、视觉反馈、设置 | PresentationEffects/Audio；[接口](02-module-interfaces.md) | [ADR-002](adr/ADR-002-custom-2-5d-physics.md) | 资源/音画设备验收 NOT RUN | 9 |
| REQ-15 | Android 17+、API 37 导出、权限和生命周期 | PlatformService；[Android/渲染](07-android-and-rendering.md)、[环境](14-environment-preparation.md) | [ADR-009](adr/ADR-009-android-api37.md) | 工具/构建/设备 BLOCKED | 2 PoC、10、12 |
| REQ-16 | 自动化测试、可复现基准、日志和崩溃诊断 | tests/Diagnostics；[性能/测试](08-performance-testing-diagnostics.md) | [ADR-001](adr/ADR-001-godot-4-7-2-gdscript.md) | 文档探针 VAL-DOC；runner/CI/设备 BLOCKED | 2、11 |
| REQ-17 | 依赖来源、维护、许可证、兼容性与仓库卫生 | [技术证据](09-technology-evidence.md)、[风险](10-risk-register.md) | 全部 ADR | 静态证据已核；实际二进制未引入；项目 LICENSE 未决 | 持续，12 门禁 |
| REQ-18 | 不扩展 9 球/斯诺克/互联网/账号/云/商城 | 范围与排除项；[总览](01-overview.md) | [ADR-004](adr/ADR-004-lan-host-enet.md) | 本阶段无越界实现；持续范围审查 | 持续 |

## 3. 架构任务到交付物

| 阶段 1 任务 | 交付物 | 验证/审查点 |
|---|---|---|
| 读取并承接阶段 0 | [风险更新](10-risk-register.md) 的 R-01…R-13 迁移 | 无既有代码被假定存在；工具链复测 |
| 模块边界、依赖、场景树、目录、数据流 | [总览](01-overview.md)、[接口](02-module-interfaces.md) | Core 不依赖 Node/UI/网络/文件/Android |
| 物理设计 | [物理](03-physics-model.md)、ADR-002 | 单位、240 Hz、TOI、旋转、袋口、静止、不收敛 |
| 规则与 AI | [规则/AI](04-rules-and-ai.md)、ADR-003/010 | WPA 条款、开球选择、8 胜负、五档同命令 |
| LAN | [网络](05-network-protocol.md)、ADR-004 | 版本、身份、限长、幂等、重连、API 37 权限 |
| SQLite/回放 | [数据](06-data-and-replay.md)、ADR-005/006 | schema、事务、迁移、备份、跨版本路径 |
| UI/Android/渲染 | [Android/渲染](07-android-and-rendering.md)、ADR-007/008/009 | 横竖屏、手势、生命周期、工具链、双渲染门禁 |
| 性能/测试/诊断 | [性能/测试](08-performance-testing-diagnostics.md) | 初始预算非实测；矩阵、日志、错误边界 |
| 技术证据 | [证据](09-technology-evidence.md) | 官方来源、维护、许可证、兼容限制 |
| 最小验证 | [隔离验证](validation/README.md)、[验证报告](13-validation-report.md) | 真实命令/输出；四态严格区分 |
| 环境/路线图 | [环境](14-environment-preparation.md)、[路线图](12-stage2-roadmap.md) | 安装后命令可复现；不提前实现阶段 2 |

## 4. 本阶段验证 ID

| ID | 对象 | 实际结果记录 |
|---|---|---|
| VAL-ENV | Godot/JDK/Gradle/ADB/SDK 与环境变量 | [验证报告](13-validation-report.md)；缺失项 BLOCKED |
| VAL-PHY | Python 标准库数学模型探针 | 同上；仅公式特例，不是 Godot 物理验收 |
| VAL-SQL | Python SQLite schema/事务/备份/损坏探针 | 同上；不是插件或 Android 验收 |
| VAL-DOC | 文档存在、ADR、需求 ID、本地链接、占位检查 | 同上；仅静态一致性 |
| VAL-GIT | diff、状态、范围、提交与推送 | 同上；不包含运行时正确性 |

## 5. 不可追溯承诺

当前没有证据支持“高仿真已达标、跨平台位级确定、五档强度已校准、Android 可导出、SQLite 插件兼容、LAN 可靠安全、60 FPS、全设备横竖屏、回放永久兼容”。这些只能在本表对应后续阶段获得真实证据后改为完成。
