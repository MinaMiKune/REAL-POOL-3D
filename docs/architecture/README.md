# 阶段 1：架构设计与技术验证

## 状态与边界

- 基线：阶段 0 提交 `8d5e069`；仓库没有 Godot 工程、源码、场景或资源。
- 本目录描述**目标架构**，不表示任何运行时功能已经实现。
- 本阶段只交付设计、决策、风险、环境准备与隔离的最小模型验证；没有创建 `project.godot`、正式场景、GDScript 游戏逻辑或 Android 工程。
- 证据检索日期：2026-11-11（UTC+08:00）。版本与维护状态此后可能变化，阶段 2 引入依赖时必须重新核对。
- 状态口径：`PASS` 仅指实际执行且断言通过；`FAIL` 指已执行且断言失败；`BLOCKED` 指缺少明确前提；`NOT RUN` 指本阶段未执行且并非必然受环境阻塞。

## 文档导航

| 文档 | 内容 |
|---|---|
| [架构总览](01-overview.md) | 模块图、依赖方向、场景树、目录和核心数据流 |
| [模块接口](02-module-interfaces.md) | DTO、接口契约、事件顺序和模块所有权 |
| [物理模型](03-physics-model.md) | 2.5D 坐标、固定步长、碰撞、旋转、库边、球袋与静止 |
| [规则与 AI](04-rules-and-ai.md) | WPA 数字规则变体、状态机、五档非作弊 AI |
| [LAN 协议](05-network-protocol.md) | UDP 发现、ENet 会话、主机权威、重连与校验 |
| [数据与回放](06-data-and-replay.md) | SQLite schema、迁移、事务、备份和回放格式 |
| [Android 与渲染](07-android-and-rendering.md) | API 37 工具链、权限、生命周期、触控适配和渲染门禁 |
| [性能、测试与诊断](08-performance-testing-diagnostics.md) | 初始预算、测试矩阵、日志和崩溃诊断 |
| [技术证据](09-technology-evidence.md) | 官方来源、维护状态、许可证和兼容性证据 |
| [风险更新](10-risk-register.md) | 阶段 0 风险迁移、剩余风险与降级方案 |
| [需求追踪](11-requirements-traceability.md) | 目标到模块、ADR、验证与后续阶段的映射 |
| [阶段 2 路线图](12-stage2-roadmap.md) | 仅工程基础的可执行任务和门禁 |
| [验证报告](13-validation-report.md) | 实际命令、完整结果及 PASS/FAIL/BLOCKED/NOT RUN |
| [环境准备](14-environment-preparation.md) | 安装准备、版本锁定和可复现命令 |
| [ADR 索引](adr/README.md) | 关键技术决策、备选方案、代价、风险和验证 |
| [隔离验证](validation/README.md) | 可运行模型探针，非生产代码 |

## 决策摘要

1. 提议锁定 Godot **4.7.2-stable** 与匹配导出模板；GDScript 为主，只有已证明必要的 SQLite GDExtension。
2. 权威物理采用定制固定步长 2.5D 模型；Godot 刚体只可用于表现或查询，不拥有比赛结果。
3. 默认规则为 `WPA_2026_DIGITAL_V1`，以 WPA 2026-10-21 的 8 球规则为基线并明确数字化差异。
4. LAN 使用 `PacketPeerUDP` 发现、`ENetMultiplayerPeer` 会话；仅主机裁决，客户端发送意图。
5. SQLite 首选候选为 `2shady4u/godot-sqlite` **v4.9**，但桌面/Android 加载、读写、事务、迁移和备份未实测前不得进入正式业务。
6. 回放保存初始快照、规范化击球、事件、版本和校验；跨版本不承诺浮点重放兼容。
7. Android 以 `minSdk=targetSdk=compileSdk=37` 为目标；API 37 的 LAN 权限在首次进入 LAN 时请求。
8. Mobile 与 Compatibility 必须制作同内容对比构建；在真实设备数据出来前，**渲染器最终选型为 BLOCKED**。

## 阶段 1 门禁结论

架构、接口、风险、追踪和实施顺序已形成闭环；Python 标准库可完成的数学/SQL/文档检查可执行。Godot 导入、插件、网络 API、渲染和 Android 构建均因缺少工具链而 `BLOCKED`。因此本阶段可提交维护者审查，但不能据此批准任何功能完成或跳过阶段 2 的真实 PoC 门禁。
