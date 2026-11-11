# Android 导出与平台行为审计

## 1. 结论

仓库没有 Android 工程或 Godot Android 导出配置，当前环境也未发现 Godot、JDK、Gradle、ADB 或 SDK Manager。因此不能导入、导出、安装或验证 Android 应用，目标 API、最低 API、权限、生命周期、方向、LAN 和性能均没有实现或设备证据。

目标要求来自 `prompts/00-project-master-prompt.md:7,23-29,48-51` 和 `prompts/10-android-optimization.md`。要求中的“Android 17+ / API 37”是目标，不是当前项目实际配置。

## 2. 导出配置检查

| 检查项 | 当前状态 | 证据 |
|---|---|---|
| Godot 项目与准确版本 | 未实现/无法确认 | 无 `project.godot`；Godot `doctor` 找不到 binary |
| Android 导出预设 | 未实现 | `git ls-files export_presets.cfg` 无输出 |
| 目标 API 37 | 未配置 | 无导出预设或 Gradle 配置 |
| 最低 Android 版本 | 未配置 | 无导出预设或 Manifest |
| 应用 ID、版本、名称、图标 | 未配置 | 无项目、导出或 Android 资源 |
| 横竖屏策略 | 未实现 | 无方向配置或布局代码 |
| Android Manifest | 未实现 | 完整跟踪清单无 `AndroidManifest.xml` |
| Gradle/包装器 | 未实现 | 无 `.gradle`、`.kts`、`gradlew` 文件 |
| APK/AAB | 未实现/未构建 | 已跟踪 `.apk`、`.aab` 数量为 0，且无构建前提 |
| 签名与发布配置 | 未实现 | 无签名配置；也未发现密钥材料 |
| 导出模板 | 无法确认 | 本机未发现 Godot，无法检查匹配模板 |

## 3. 本机工具链实测

审计环境：Windows MSYS2/Git Bash，`git version 2.47.1.windows.1`，`Python 3.12.15`。实际命令及结果：

```text
python3 scripts/godot_tool.py doctor
# 退出码 2；candidates: []；找不到 Godot Editor binary

java -version; javac -version; gradle -v; adb --version; sdkmanager --version
# java: command not found
# javac: command not found
# gradle: command not found
# adb: command not found
# sdkmanager: command not found
# 最终退出码 127

printenv ANDROID_HOME ANDROID_SDK_ROOT JAVA_HOME GRADLE_HOME GODOT_BIN
# 无输出；这些变量在当前 shell 中未设置
```

`where.exe java javac gradle adb sdkmanager godot godot4` 也未找到文件。以上仅证明当前 shell/ PATH 环境不可用，不断言整台机器从未安装这些工具。

| 工具链组件 | 版本核验结果 |
|---|---|
| Godot Editor | BLOCKED：未发现 binary |
| Godot Android 导出模板 | BLOCKED：无法核验 |
| JDK/Javac | BLOCKED：当前 PATH 无命令 |
| Gradle | BLOCKED：当前 PATH 无命令 |
| Android SDK/Platform API 37 | BLOCKED：无 SDK 路径或 `sdkmanager` |
| Android Build Tools | BLOCKED：无 SDK 可查询 |
| ADB 与连接设备 | BLOCKED：无 `adb` |
| NDK | NOT TESTED：没有已声明原生依赖，也无 SDK 环境可核验 |

## 4. 权限与平台行为

| 领域 | 实现状态 | 验证状态与证据 |
|---|---|---|
| 网络/局域网权限声明 | 未实现 | 无 Manifest；BLOCKED，无法检查安装后行为 |
| 权限用途与最小化 | 未实现 | 无权限声明或拒绝分支；BLOCKED |
| 权限拒绝/撤销 | 未实现 | 无代码或设备测试 |
| 网络切换、断线和重连 | 未实现 | 无 LAN 代码；BLOCKED |
| 暂停、恢复、切后台 | 未实现 | 无入口脚本或生命周期处理 |
| 进程被系统回收 | 未实现 | 无持久化或恢复代码 |
| 屏幕旋转与窗口变化 | 未实现 | 无配置、UI 或输入处理 |
| 安全区、DPI 与长宽比 | 未实现 | 无布局实现或设备结果 |
| 音频焦点、静音和震动 | 未实现 | 无音频/触觉代码 |
| 存储策略和数据持久化 | 未实现 | 无 SQLite 或本地数据代码 |
| 安装、升级与数据保留 | 未实现 | 无 APK/AAB 或版本配置 |

不能将“没有权限声明”解释为“权限设计安全”，也不能将“没有生命周期缺陷报告”解释为“生命周期兼容”。

## 5. 渲染、兼容性和性能

- Mobile 与 Compatibility Renderer 均未选择；无 `project.godot`，也无真实设备对比，符合总控中“不得仅凭理论决定”的审计口径。
- 没有低/中/高画质档、自适应策略或手动设置实现。
- 没有启动时间、帧率、帧时间、内存、发热、耗电或长时间运行数据。
- 没有 Android 17 模拟器或真实设备结果；所有安装、启动、核心对局、暂停恢复、方向、数据和 LAN 验证均为 `BLOCKED`。

## 6. 后续验证前提

后续获批阶段需先记录 Godot、导出模板、SDK Platform/Build Tools、JDK、Gradle 和必要 NDK 的准确版本与路径，再建立最小导出和真机冒烟证据。不能假定“最新版”相互兼容，也不能用桌面运行替代 Android 验收。本阶段未安装工具、未修改配置、未执行导出。
