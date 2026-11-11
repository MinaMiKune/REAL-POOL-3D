# 环境准备清单与可复现命令

## 1. 当前实测环境

2026-11-11，Windows Git Bash：Git `2.47.1.windows.1`、Python `3.12.15` 可用。Godot Editor、JDK/Javac、Gradle、ADB、sdkmanager 未在 PATH 发现；`ANDROID_HOME/ANDROID_SDK_ROOT/JAVA_HOME/GRADLE_HOME/GODOT_BIN` 未设置。此结论只覆盖当前 shell/ PATH，不证明整台机器从未安装。

当前没有执行以下安装命令，所有依赖这些工具的结果均为 `BLOCKED`。大型工具需维护者明确安装；不要自动下载或升级 Godot。

## 2. 需要准备的组件

| 组件 | 目标/要求 | 安装前检查 | 用途 |
|---|---|---|---|
| Godot Editor | `4.7.2-stable` standard Windows x86_64 | [官方归档](https://godotengine.org/download/archive/4.7.2-stable/)，核对官方 release digest | 导入、测试、导出 |
| Godot export templates | 与 Editor 完全相同的 `4.7.2-stable` | 使用同版官方 `.tpz`，不混用 .NET/standard | Android 导出 |
| OpenJDK | 17，记录发行版和具体 patch | `java -version`、`javac -version` | Gradle/Android 构建 |
| Android Studio | Meerkat 2024.3.1+（若用 GUI） | Android 官方 API 37 setup 文档 | SDK 管理/AGP 兼容辅助 |
| Android cmdline tools | latest 经官方渠道，记录实际版本 | `sdkmanager --version` | 无 GUI SDK 安装 |
| SDK Platform | `platforms;android-37` | `sdkmanager --list` 实际存在 | compileSdk 37 |
| Platform-Tools / ADB | 35.0.0+，安装当前经核验稳定版 | `adb version` | 安装、设备日志 |
| Build-Tools | 优先实际可用的 37.x；保留 Godot 基线 35.0.1 回退 | 包名必须从 `--list` 核实 | APK/AAB 构建 |
| NDK | `28.1.13356709`（仅确需原生构建时） | Godot 文档/插件实际要求 | GDExtension/自定义构建 |
| CMake | `3.10.2.4988404`（仅确需时） | 同上 | 原生构建 |
| Gradle | Godot 生成的 wrapper，准确版本待读取 | 不预装/假定系统 Gradle | Android 构建 |
| 设备 | 至少一台 Android 17/API 37 arm64；建议另有大屏和低端机 | `adb devices -l` 与 `getprop` | 权限、触控、性能、LAN |

Godot 官方 Android 文档还列 Platform 35/Build-Tools 35.0.1；Android API 37 文档要求 compileSdk 37/Build-Tools 37.x。不要凭文档拼接假定最终构建，必须读取 Godot 生成 wrapper 和实际依赖解析。

## 3. 安装顺序

1. 从 Godot 官方归档安装 Editor 和匹配模板，记录下载 URL、文件 SHA-256、实际安装路径。
2. 安装 OpenJDK 17；设置 `JAVA_HOME` 为 JDK 根目录，不写入仓库。
3. 安装 Android Studio 或官方 command-line tools；选择工作区外的用户 SDK 目录，例如 Windows 用户目录下的 `Android\Sdk`，该路径仅作示例。
4. 配置当前 shell 的 `ANDROID_HOME` 和 `ANDROID_SDK_ROOT`；不要把 `local.properties`、密码或 SDK 整个目录提交。
5. 查询 SDK 包后安装 API 37 和必要工具；接受许可证前由维护者阅读。
6. 在 Godot Editor Settings 配置 Java SDK Path/Android SDK Path；再生成项目 Android build/wrapper。
7. 连接 API 37 设备并启用开发者调试；记录型号、SoC、RAM、OS build、ABI、屏幕和渲染能力。

## 4. Windows Git Bash 环境变量示例

将占位路径替换为真实安装路径；以下命令**未执行**：

```bash
export GODOT_BIN="/c/Path/To/Godot_v4.7.2-stable_win64.exe"
export JAVA_HOME="/c/Program Files/Java/jdk-17"
export ANDROID_HOME="/c/Users/<USER>/AppData/Local/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

路径含空格必须加引号。持久环境变量由维护者在 Windows 中设置；不要假定一个 Bash 调用的 export 会保留到下一个 shell。

## 5. 安装后版本核验命令

```bash
git --version
python3 --version
java -version
javac -version
adb version
sdkmanager --version
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --list
adb devices -l
```

Godot 必须通过本环境插件的 broker 调用，不能直接裸跑 Godot。以下命令从仓库工作区执行，使用实际插件脚本路径：

```bash
python3 "E:/KimiData/daimon-share/daimon/runtime/kimi-code/home/plugins/managed/godot/scripts/godot_tool.py" doctor
python3 "E:/KimiData/daimon-share/daimon/runtime/kimi-code/home/plugins/managed/godot/scripts/godot_tool.py" capabilities --json
```

阶段 2 创建项目后，再执行：

```bash
python3 "E:/KimiData/daimon-share/daimon/runtime/kimi-code/home/plugins/managed/godot/scripts/godot_tool.py" project-info --project "E:/KimiData/kimi/Workspaces/REAL-POOL-3D"
python3 "E:/KimiData/daimon-share/daimon/runtime/kimi-code/home/plugins/managed/godot/scripts/godot_tool.py" scan-project --project "E:/KimiData/kimi/Workspaces/REAL-POOL-3D"
```

`doctor` 必须实际读取 binary 的 `--version/--help`；不能用文件名声称版本或 capabilities。项目尚不存在时上述 project 命令不适用。

## 6. SDK 安装命令（准备后执行）

先用第 5 节 `--list` 确认包名。以下是依据官方文档形成的候选命令，**本阶段 NOT RUN，包是否存在尚未在本机验证**：

```bash
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "platforms;android-37" \
  "build-tools;37.0.0" \
  "build-tools;35.0.1" \
  "cmdline-tools;latest" \
  "cmake;3.10.2.4988404" \
  "ndk;28.1.13356709"
```

`build-tools;37.0.0` 是候选，若 `--list` 只提供其他 37.x，应选择经核验的实际版本并更新本文，不得把命令写成已执行。NDK/CMake 只在构建确需时安装，避免无必要的大型依赖。

接受 SDK licenses 是维护者操作：

```bash
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses
```

## 7. Godot/Gradle/Android 验证命令（阶段 2）

生成 `android/build` 后读取实际文件，再使用项目 wrapper：

```bash
cd android/build
./gradlew.bat --version
./gradlew.bat tasks --all
./gradlew.bat assembleDebug
```

具体 task 以 `tasks --all` 和 Godot 生成工程为准；不得从现在猜测最终 task/AGP 版本。更优先通过 Godot broker `export-plan`/`export` 执行已批准的导出，保留 plan、argv、日志和产物。

设备核验：

```bash
adb devices -l
adb shell getprop ro.build.version.sdk
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abi
adb shell getprop ro.product.model
adb install -r -d "path/to/app-debug.apk"
adb shell pm list permissions -g -d
adb logcat
```

`adb install -r -d` 中 downgrade 只在明确测试升级/回退且维护者批准时使用；普通首次安装用 `adb install -r`。不要把真实用户数据设备用作破坏性迁移/损坏测试，优先专用测试设备。

## 8. SQLite v4.9 资产准备（阶段 2）

1. 重新打开[官方 v4.9 release](https://github.com/2shady4u/godot-sqlite/releases/tag/v4.9)和 latest API，确认仍选 v4.9。
2. 只从官方 release 下载 `addons.zip` 到工作区临时目录，记录实际文件 SHA-256，与发布元数据 digest `95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0` 比较。
3. 解压前检查 ZIP slip、文件清单、许可证和 `.gdextension`；只引入需要的经审查文件，并保留第三方 notices。
4. 在隔离 PoC 中运行 `scan-project` 和桌面/Android 测试，未通过前不接入正式业务。

PowerShell 可用 `Get-FileHash` 计算下载 hash；Git Bash 可用 `sha256sum`。这些命令本阶段未运行，因为未下载依赖。

## 9. 设备和网络准备

- 两台设备连接同一专用测试 LAN，关闭 AP client isolation 或记录其存在；准备 directed IP join 测试。
- 测试 Wi-Fi 权限允许、拒绝、设置撤销、网络切换、锁屏、后台和进程杀死。
- 准备 API 37 手机与 sw≥600dp 设备；模拟器可补充 x86_64/窗口测试，但不替代 arm64 真机性能和权限结论。
- 记录路由器/AP 隔离、VPN、防火墙和电量/温度条件；不修改维护者网络持久配置来掩盖问题。

## 10. 当前阻塞解除表

| 阻塞 | 解除前提 | 解除后首个命令 |
|---|---|---|
| Godot binary/版本/flags | 安装 Editor，设置 GODOT_BIN | broker `doctor`、`capabilities --json` |
| Godot 项目导入 | 阶段 2 获批并创建最小项目 | broker `project-info`、`scan-project`、import plan |
| SQLite GDExtension | Godot + 官方 v4.9 固定资产 | 隔离 PoC 加载/CRUD |
| Android APK | JDK 17 + SDK + 模板 + wrapper | `gradlew --version` / Godot export plan |
| ADB/设备 | Platform-Tools + API 37 设备连接 | `adb devices -l`、`getprop` |
| LAN 双设备 | 两台应用构建 + 同 LAN + 权限 | 权限矩阵 + UDP/ENet PoC |
| 渲染器选择 | 双构建 + 目标设备 | 固定场景性能/视觉对比 |

所有安装和命令均需记录实际版本、退出码和输出；准备完成不等于验证通过。
