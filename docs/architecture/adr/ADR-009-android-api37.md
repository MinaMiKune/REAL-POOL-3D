# ADR-009：Android API 37 标准导出与 LAN 运行时权限

- 日期：2026-11-11
- 状态：Accepted；构建和设备验证 `BLOCKED`

## 背景

目标是 Android 17+/API 37，优先 GDScript，版本必须实测。Android 官方要求 target 37 的 LAN 权限，并改变大屏方向行为；Godot 与 Android 文档的工具链基线不同，需要实际 Gradle 兼容验证。

## 决策

设置目标 `minSdk=targetSdk=compileSdk=37`，使用 Godot 4.7.2 standard 导出和同版模板、OpenJDK 17、SDK Platform 37，优先 Godot 生成的 Gradle wrapper。声明 INTERNET 和 ACCESS_LOCAL_NETWORK，首次进入 LAN 时解释并异步请求，授权前不启动 socket。优先 `OS.request_permission` 无 Kotlin 路径，失败才另评最小 Android v2 插件。响应式支持大屏，不锁方向。

## 备选方案

1. **降低 minSdk/targetSdk 以扩大设备/规避权限**：违背 Android 17+ 和 API 37 目标，拒绝。
2. **compileSdk 35 按 Godot 旧基线**：不满足 API 37 目标，拒绝；35 Build-Tools 可作兼容回退但不是 compile 目标。
3. **立即 Kotlin/Android 插件**：可调用原生权限，但未证明必要且增加维护，后置。
4. **只声明 INTERNET**：API 37 target 下 LAN 会被阻断，拒绝。
5. **系统 NSD picker**：可减少广域 LAN 权限，但改变发现模型，不是广播/direct join 的等价替换；仅后续评审。
6. **锁定横屏**：target 37 大屏限制不可依赖且不满足需求，拒绝。

## 理由

符合产品目标与官方平台要求，最小化原生代码。将权限请求放在用户明确进入 LAN 时，保留离线单机并减少不必要权限。先验证 Godot 标准链路可避免维护一套原生工程。

## 代价

- minSdk 37 排除旧设备，设备覆盖较窄。
- 新权限需要允许/拒绝/撤销/网络变化完整 UX 和测试。
- Godot 生成 AGP/Gradle 可能需要受控调整；Release/AAB 签名和升级另有工作。

## 风险与降级

权限失败则 LAN 不可用并明确提示，不绕过隐私保护；广播失败 directed join；标准导出失败记录真实错误并评估匹配工具链或最小插件。不得用降低 target 规避问题。签名通过环境变量/本地安全存储，密钥不入库。

## 验证方法

读取生成 wrapper/AGP/SDK/Manifest；构建 debug APK 并在 API 37 arm64 设备安装。检查 min/target/compile、权限列表、启动、方向、后台、进程恢复和升级。对 LAN 权限分别测试允许、拒绝、撤销后的 UDP 广播/单播与 ENet，保存 logcat 和版本。
