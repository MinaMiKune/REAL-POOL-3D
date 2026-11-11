# 阶段 2 实施路线图（仅工程基础与真实 PoC）

## 1. 进入条件与禁止事项

只有在维护者审查并批准本阶段架构后才执行。阶段 2 的目标是建立可导入/启动的工程基础、统一接口和最小工具链/依赖验证；不得提前实现正式物理、规则、AI、对局、LAN 对战、回放、训练或美术功能。

阶段 1 的 Python 探针不是 Godot PoC 的替代品。凡本报告标为 `BLOCKED` 的高风险选型，必须在阶段 2 获得真实结果或由维护者批准替代/降级方案，才能解除对应门禁。

## 2. 工作分解与依赖

| 顺序/ID | 任务 | 交付物（计划，当前不存在） | 验证/退出门禁 | 依赖 |
|---|---|---|---|---|
| S2-00 | 准备并锁定工具链 | 版本/路径/模板/SDK 清单 | Godot doctor/capabilities；JDK/SDK/ADB 版本；API 37 包可查询 | 维护者安装大型工具，见环境文档 |
| S2-01 | 仓库卫生与归属基线 | 检查 .gitignore；依赖/资源台账；维护者决定项目 LICENSE | 无缓存、密钥、本地路径入库；每个依赖有证据 | 无 |
| S2-02 | 最小 Godot 4.7.2 工程 | `project.godot`、最小主场景、app 启动组合、空白诊断页 | 实际导入、启动、关闭；无缺失资源/脚本错误 | S2-00、S2-01 |
| S2-03 | 应用基础接口 | App 状态、场景切换、版本化配置、日志/ErrorInfo、能力检测、输入抽象 | 纯单元和最小场景测试；接口不是空壳，不含玩法 | S2-02 |
| S2-04 | 测试与复现链 | `tests/`、SceneTree runner、可复现脚本、基础 CI（若环境允许） | 一个真实通过和一个故障注入测试；记录命令/退出码 | S2-02 |
| S2-05 | SQLite 桌面隔离 PoC | 固定 v4.9 的 PoC 插件资产和最小 repository 适配 | 加载、CRUD、外键、参数绑定、事务回滚、迁移、备份/损坏；记录 hash/license | S2-00、S2-04 |
| S2-06 | Android 最小导出 | export preset、生成 Gradle wrapper、debug APK | compile/target/min 37；APK hash、安装、启动、Manifest 和 logcat | S2-00、S2-02 |
| S2-07 | SQLite Android PoC | 同一数据 PoC 的 arm64 APK | 设备加载、CRUD、事务、迁移、备份；进程杀死/升级初步验证 | S2-05、S2-06 |
| S2-08 | LAN API 与 API 37 权限 PoC | 仅 discovery/echo/版本拒绝的隔离测试入口 | UDP 广播/单播、ENet 双通道、拒绝/撤销、限长/畸形输入；不实现对战 | S2-06，双设备 |
| S2-09 | 渲染器双路径 PoC | 同内容诊断 3D 场景、Mobile/Compatibility 两构建 | 截图、shader 日志、固定负载帧时间、内存/启动基线；更新 ADR-008 | S2-06 |
| S2-10 | 阶段验收与架构回写 | 环境/版本实测、PoC 报告、风险/ADR 更新 | 全部变更、命令、四态、未决项；独立提交等待批准 | S2-03…09 |

S2-05 和 S2-06 在各自前置完成后可并行；S2-07 必须在两者都成功后。S2-08/09 若缺设备仍 BLOCKED，不能用桌面截图或 echo 代替 Android 验收。

## 3. 最小工程边界

允许创建：

- 应用入口、主场景、Debug/Settings/Storage 测试页；
- `src/app`、`src/core/model` 中的通用值对象和错误/版本类型；
- `src/adapters/storage/network/platform` 的 PoC 适配器；
- `src/presentation` 中仅用于渲染/输入能力验证的诊断视图；
- `tests/{unit,integration,fixtures,performance,device}` 与可复现脚本。

不允许创建：

- 正式 `PhysicsWorld` 碰撞/击球算法、规则 reducer、AI planner；
- 可开始比赛、计算得分/胜负或联机对战的按钮和逻辑；
- 正式 replay/training/lab 功能、球桌美术生产和音频系统；
- 为绕过 Godot/Android 门禁而未经批准的整套 Kotlin 原生工程。

若 PoC 需要一球一桌的几何诊断，只能作为隔离 fixture，不连接正式比赛，并在报告中明确不是玩法实现。

## 4. SQLite PoC 具体步骤

1. 重新查询 v4.9 release 和兼容证据，下载官方 `addons.zip`，核对发布 digest 与本地下载 SHA-256；检查 ZIP 路径、二进制、许可证和平台条目。
2. 插件先只放在隔离 PoC 工程/测试目录，运行 Godot `scan-project`，记录 native/editor 执行面。
3. 桌面加载并执行 SQL v1：打开临时 `user://` 测试库、建表、参数写入/读取、外键拒绝、唯一键、事务回滚。
4. 创建测试用 v1→v2 小迁移（只用于验证迁移器，不提前改变正式 v1 设计），验证备份、失败回滚、未来版本拒绝和重复迁移保护。
5. Android arm64 重复同套测试，记录 `.so` 是否打包、`user://` 路径、日志和进程重启数据保留。
6. 任一步失败保持正式 repository 未接入，记录错误并回到 ADR-005；不得自动改用 JSON。

## 5. Android/权限 PoC 具体步骤

1. 读取 Godot 生成的 Gradle wrapper、AGP、SDK 和 Manifest merger 结果，形成实际兼容矩阵。
2. 构建标准 debug APK，记录命令、完整日志、APK SHA-256、签名类型和包名；安装到 API 37 设备。
3. 验证首次启动、横竖屏/分屏、后台/恢复、进程杀死、最低/target SDK 和权限列表。
4. 仅声明 INTERNET/ACCESS_LOCAL_NETWORK 等已批准权限；在用户动作后请求 LAN 权限，覆盖允许、拒绝、设置撤销和再次进入。
5. 授权后运行 UDP/ENet echo；未授权时必须无 socket 收发，并保留离线页面。若 Godot 路径失败，保存证据并提出最小 Android v2 插件 ADR，不直接扩张实现。

## 6. 渲染和性能 PoC 具体步骤

- 用相同资源、相机、灯、材质和窗口配置构建 Mobile 与 Compatibility。
- 场景只包含可测量的球体/桌面代理几何和 UI 诊断，不是正式游戏美术。
- 固定 60 秒 idle 和可重复动画负载，记录 p50/p95/p99、启动、内存、渲染错误与截图；在至少两台不同能力设备上比较。
- 若设备不足，最终渲染器继续 BLOCKED；不可因某一台 Mobile 更快就宣布全设备默认。
- 建立低档降效开关但不得改变权威模拟（此时只允许诊断动画，不得加入正式物理）。

## 7. 测试与 CI 最小门

- 每次变更执行文档探针、Python 模型/SQL 探针和 Godot headless 单元测试。
- 导入、主场景启动、桌面 SQLite、Android 构建按阶段门禁执行；日志保留失败 stderr 和退出码。
- CI 如无法安全提供 Android SDK/签名/设备，不伪造这些任务；将 CI 标为仅桌面/静态，设备流程保留可复现本地命令。
- 第三方插件和二进制固定版本，禁止构建时无版本自动拉取 latest。

## 8. 阶段 2 完成判定

必须同时满足：

1. 最小 Godot 工程实际导入、启动，基础状态切换和测试 runner 有真实结果。
2. SQLite 桌面与 Android 读写、事务、迁移和备份有真实结果；任何失败明确阻断正式接入。
3. Android 至少完成工具链验证；按本架构目标，建议 debug APK 安装启动后再申请阶段 3。
4. LAN API、API 37 权限和双渲染器高风险项已实测，或维护者书面接受明确降级与剩余 BLOCKED。
5. 未实现任何后续正式玩法；文档、ADR、风险和需求追踪与实测同步。

阶段 2 完成后单独提交并停止。阶段 3 才可按获批设计实现正式物理核心。
