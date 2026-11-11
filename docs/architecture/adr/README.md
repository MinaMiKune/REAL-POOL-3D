# 架构决策记录（ADR）

状态含义：`Accepted` 是架构方向已决定但可能尚未实现；`Conditionally accepted` 必须通过指定 PoC 才能用于正式业务；`Proposed gate` 表示决策流程已确定但最终技术项仍未选定。任何状态都不代表测试通过。

| ADR | 决策 | 状态 |
|---|---|---|
| [ADR-001](ADR-001-godot-4-7-2-gdscript.md) | Godot 4.7.2 standard + GDScript 优先 | Accepted；本机验证 BLOCKED |
| [ADR-002](ADR-002-custom-2-5d-physics.md) | 定制固定步长 2.5D 权威物理 | Accepted；实现/校准未开始 |
| [ADR-003](ADR-003-wpa-rules-reducer.md) | WPA 2026 数字变体 + 纯规则 reducer | Accepted；数字差异待维护者审查 |
| [ADR-004](ADR-004-lan-host-enet.md) | UDP 发现 + ENet + 主机权威二进制协议 | Accepted；Godot/Android 验证 BLOCKED |
| [ADR-005](ADR-005-sqlite-conditional-v4-9.md) | godot-sqlite v4.9 作为条件候选 | Conditionally accepted；未引入依赖 |
| [ADR-006](ADR-006-snapshot-command-replay.md) | 快照+命令+事件+版本/hash 回放 | Accepted；跨版本重算不承诺 |
| [ADR-007](ADR-007-responsive-touch-input.md) | 统一命令输入、手势状态机、响应式横竖屏 | Accepted；设备验证 BLOCKED |
| [ADR-008](ADR-008-renderer-device-gate.md) | Mobile/Compatibility 同内容设备门禁 | Proposed gate；最终渲染器 BLOCKED |
| [ADR-009](ADR-009-android-api37.md) | API 37 标准导出优先、LAN 运行时权限 | Accepted；构建/权限验证 BLOCKED |
| [ADR-010](ADR-010-ai-fairness-and-seeds.md) | AI 同人命令、克隆预测、五档误差和版本化 seed | Accepted；强度/性能未验证 |

## 变更规则

- 重大替代方案、依赖升级、协议/物理/规则 major 变更必须新增或 supersede ADR，不能只改代码。
- 每次真实 PoC 后更新验证证据、状态和风险；失败要保留原始结果，不能删除历史决策痕迹。
- 新 ADR 必须包含背景、备选、理由、代价、风险/降级和可复现验证方法。
