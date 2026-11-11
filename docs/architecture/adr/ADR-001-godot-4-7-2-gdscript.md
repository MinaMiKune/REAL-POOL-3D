# ADR-001：Godot 4.7.2 standard 与 GDScript 优先

- 日期：2026-11-11
- 状态：Accepted（架构基线）；本机运行验证 `BLOCKED`

## 背景

项目要求 Godot 4.x、Android API 37 和优先 GDScript。阶段 0 无现有工程或依赖，本机也没有 Godot binary。官方仓库本次 latest release 为 `4.7.2-stable`，4.8 预览版不作为生产基线。

## 决策

锁定 Godot `4.7.2-stable` standard（非 .NET）与同版导出模板；应用、物理、规则、AI、网络和回放优先 GDScript。仅 SQLite 使用经审批的 GDExtension，只有实测证明标准 API 不足才考虑 Kotlin/Android v2 插件。引擎升级必须单独 ADR 和全量兼容测试。

## 备选方案

1. **Godot 4.8 beta/最新开发版**：可能含新功能，但预览版稳定性和插件兼容证据不足，拒绝。
2. **较旧 Godot 4.x**：可能有旧插件，但无法同时获得当前修复和 API 37 验证，且扩展仍要实测，拒绝。
3. **.NET/C#**：利于部分类型/库生态，但引入 Android 工具链和部署复杂度，项目无此需求，拒绝。
4. **Unity/自研引擎/其他引擎**：违背明确技术约束且没有复用代码，拒绝。
5. **大量 C++ GDExtension**：可能改善局部性能，但增加 ABI、NDK、维护和崩溃面；只有基准证明 GDScript 瓶颈后才可局部考虑。

## 理由

正式稳定版、同版模板、GDScript 与需求最匹配；Godot MIT 允许游戏分发但要求保留引擎版权/许可。官方文档覆盖 Android、ENet、UDP、GDExtension 和渲染器，能最大限度减少自研平台桥接。

## 代价

- 固定版本意味着升级修复不能自动获得；依赖插件必须跟随兼容矩阵。
- GDScript 在重物理/AI 下可能有性能瓶颈，需要 worker、算法预算和基准。
- standard 版本没有 C# 生态，不能事后假定 NuGet 库可用。

## 风险与降级

若 4.7.2 无法完成 API 37 或 SQLite 导出，先保存实际错误，评估官方 patch/插件匹配构建；不得静默升级或改用非官方引擎。若确需升级，重新验证插件、网络、渲染、物理和回放。

## 验证方法

1. 安装后通过 Godot broker `doctor`、`capabilities --json` 读取实际 binary/version/help。
2. 阶段 2 创建最小项目后 `project-info`、`scan-project`、真实导入/启动。
3. 核对导出模板版本并构建 Android debug APK，记录 JDK/SDK/Gradle 实际组合。
4. 执行最小 GDScript 单元测试和桌面/Android SQLite PoC。

当前只完成官方 release/license 证据核验；上述运行项均 `BLOCKED`。
