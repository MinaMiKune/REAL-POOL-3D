# ADR-005：godot-sqlite v4.9 条件候选与 Repository 隔离

- 日期：2026-11-11
- 状态：Conditionally accepted（仅隔离 PoC）；正式接入和运行验证 `BLOCKED`

## 背景

需求指定 SQLite 保存战绩、设置和回放索引，并要求核查维护、Android 支持和许可证。当前仓库没有插件。本机 Python sqlite3 可验证 SQL，但不能证明 Godot/Android ABI。

## 决策

首选官方仓库 `2shady4u/godot-sqlite v4.9` 作为隔离 PoC 候选。其 release 基于 Godot 4.7.1/SQLite 3.51.0，声明 Android arm64/x86_64；固定 `.gdextension` 的 minimum 为 4.7，许可证 MIT，SQLite 为 Public Domain。仅当 Godot 4.7.2 桌面和 Android 的加载、CRUD、外键、事务、迁移、备份和恢复全部满足门禁后才正式接入。所有 SQL 位于 repository 适配器后。

## 备选方案

1. **Python sqlite3 作为运行时**：桌面易用但 Android 集成不合适，仅用于本阶段 SQL 草案探针，拒绝作为游戏依赖。
2. **JSON/文件存储**：少依赖但事务、查询、迁移和损坏恢复弱，且不符合 SQLite 需求，不作静默替代。
3. **其他 Godot SQLite 插件**：可能在维护/ABI 上更优，但需相同官方证据和 PoC，当前无必要同时引入。
4. **自行编译 godot-sqlite/godot-cpp**：可精确匹配 4.7.2，但需要 C++/NDK/SCons 和维护能力；只有 release 二进制失败且维护者批准后考虑。
5. **自研 SQLite GDExtension**：控制高但成本/风险最大，不作为首选。
6. **ORM/云数据库**：超出本地最小依赖和范围，拒绝。

## 理由

v4.9 是官方仓库正式 release，本次 latest API 亦指向它；2026-08-25 有近期维护活动，许可证宽松，明确包含目标 Android ABI。Godot 文档的旧 minor→新 minor 兼容目标使 4.7.1 构建用于 4.7.2 具有合理依据，但不是运行保证。Repository 隔离限制更换代价。

## 代价

- 原生扩展增加 APK 大小、ABI 限制、崩溃面和供应链审计；没有 Android arm32 条目。
- release 针对 4.7.1 而非 4.7.2，必须实测；最新 commit 不一定包含在 v4.9。
- 插件 API 的 backup、journal、threading 和参数绑定行为可能与 Python 不同。

## 风险与降级

未下载前仅核对发布元数据 digest；引入时校验本地 hash、ZIP 内容和 notices。任一平台失败保持正式业务不接入，保存错误并评估同上游匹配构建/替代插件，经维护者批准。禁止自动换 JSON 或声称 Python 测试即插件通过。

## 验证方法

1. 下载官方 addons.zip，核对发布 SHA-256 与本地 hash、ABI、license。
2. Godot 4.7.2 桌面加载，执行 schema v1、参数 CRUD、外键、唯一键、事务回滚。
3. Android arm64 重复，检查 `.so` 打包、`user://`、进程重启和升级。
4. 执行测试迁移、备份/integrity/quarantine、磁盘失败和损坏恢复。
5. 所有结果更新本 ADR；未通过前状态不得改为生产 Accepted。
