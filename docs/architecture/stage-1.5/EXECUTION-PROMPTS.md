# REAL-POOL-3D 阶段 1.5：Windows 10 环境建立与技术 PoC 执行提示词

> 项目：REAL-POOL-3D  
> 仓库： https://github.com/MinaMiKune/REAL-POOL-3D  
> 开发主环境：Windows 10  
> 前置基线：阶段 1 提交 `50a6dc6fc828f37dc05a0ff364e68a109d112ea0`  
> 工作分支：`stage-1.5/environment-and-poc`  
> 本阶段性质：环境准备、隔离 PoC、技术准入门禁；不是正式游戏开发。

---

## 使用说明

将本文件交给 Kimi 或其他仓库 Agent。必须先执行「总控提示词」，然后严格按 1.5.1 至 1.5.8 的顺序逐项执行。每个子阶段完成后暂停，提交报告并等待用户审查／授权，再继续下一项。不得一次性跳过门禁批量执行。

本文件是执行规范。仓库当前架构文档、ADR 和用户后续明确指令优先于本文件；若发现冲突，先报告，不自行覆盖决策。

# A. 总控提示词

你正在维护 REAL-POOL-3D 仓库。阶段 0 和阶段 1 已完成，阶段 1 的基线提交为：

`50a6dc6fc828f37dc05a0ff364e68a109d112ea0`

阶段 1 已推送到 `origin/main`。本阶段开发主环境为 Windows 10。

## A1. 总目标

执行阶段 1.5：建立可复现开发环境并完成最小技术 PoC，为后续阶段提供真实证据：

1. Windows 10 开发环境审计。
2. Godot 4.7.2 与 Android 导出工具链安装、版本固定和校验。
3. Godot 编辑器、GDScript、场景、资源导入及 headless 验证。
4. Android APK 导出验证；有设备时完成安装、启动和日志验证。
5. SQLite GDExtension 候选版本的桌面加载、CRUD、事务及故障测试。
6. UDP／ENet 双进程通信及可用条件下的局域网设备验证。
7. Mobile 与 Compatibility 渲染器对比。
8. 汇总证据，更新 ADR、风险、需求追踪和阶段路线图，提出阶段 2 准入建议。

## A2. 阶段边界：禁止提前进入阶段 2

本阶段只允许环境脚本、文档和隔离 PoC。

允许：
- Windows 环境审计脚本及 JSON 结果；
- 工具链安装记录、版本清单、SHA-256；
- 独立 Godot smoke-test 项目；
- 独立 Android 导出测试项目；
- 独立 SQLite GDExtension 测试项目；
- 独立 ENet／UDP 测试项目；
- 独立渲染器基准场景；
- 原始日志、测试数据、结果 JSON、ADR 修改建议。

禁止：
- 创建或初始化正式游戏工程；
- 正式球桌、球体、球杆、球袋或游戏场景；
- 正式物理引擎、规则引擎、AI、UI、对局、回放、存档或网络模块；
- 将 PoC 代码迁移到正式运行时目录；
- 引入未经批准的插件、资源包或依赖；
- 以“顺手完善”为由扩张功能范围；
- 未经用户明确授权进入阶段 2。

所有 PoC 必须位于 `docs/architecture/stage-1.5/poc/`，并与未来正式工程隔离。

## A3. 四态验证规则

每项检查必须且只能标记为以下状态之一：

- `PASS`：实际执行，达到预先定义的验收标准，证据可复核。
- `FAIL`：实际执行，未达到验收标准；保留失败输出和复现步骤。
- `BLOCKED`：因工具、权限、设备、网络、驱动或外部条件无法执行。
- `NOT RUN`：尚未执行。

不得把静态文档阅读写成动态测试通过；不得把 Python 模型测试写成 Godot 测试；不得把桌面结果写成 Android 结果；不得把本机双进程测试写成真实双设备 LAN 测试；不得把 APK 导出成功写成真机运行成功。

首次失败证据必须保留。修复后重跑应另存结果，不能覆盖首次失败 JSON 或日志。报告中同时列出首次结果和最终结果。

## A4. 安装与系统安全

- 优先使用 Godot、Microsoft、Android Developers 等官方渠道。
- 每个安装包记录来源 URL、版本、下载日期和 SHA-256；若官方未提供校验值，明确记录自行计算的哈希，不声称其为官方签名。
- Android SDK 优先使用官方 SDK Manager。
- JDK、SDK、Build Tools、Gradle、导出模板的版本必须根据 Godot 4.7 官方导出文档和实际导出链路确定，不凭印象指定“最新版”。
- 不覆盖现有工具，不擅自改变系统级 PATH、注册表、代理、防火墙或系统策略。
- 优先使用独立目录和项目级配置。
- 不关闭 Defender、防火墙或系统安全功能。
- 不运行来源不明的管理员脚本。
- 需要管理员权限、系统设置变更、重启、驱动安装或防火墙规则时，先解释影响并等待用户批准。
- 不记录或提交密码、令牌、签名密钥、个人网络凭据、设备序列号等敏感信息。
- 不提交 Android keystore、私钥、local.properties、机器专属绝对路径或含凭据的日志。

## A5. Windows 10 兼容性门禁

Windows 10 是用户指定的主要开发环境，但不得假定所有当前工具版本仍支持该系统。先检查 Windows Edition、版本、Build、补丁／ESU 状态、CPU 架构、虚拟化、GPU、驱动、磁盘和内存，再逐项核对 Godot、JDK、Android Studio／SDK 的当前官方系统要求。

Windows 10 常规支持已于 2025-10-14 结束。记录设备是否符合 ESU 条件及用户实际状态；不要把 ESU 状态未知写成已覆盖。若关键工具不再支持当前系统，报告具体限制并提出可选方案（例如升级 Windows 11 或使用受支持的替代开发机），不得擅自升级操作系统。

## A6. Git 规则

- 开始前检查远端、分支、HEAD、工作区和未跟踪文件。
- 从最新 `origin/main` 创建或使用 `stage-1.5/environment-and-poc`。
- 不在 `main` 直接开发。
- 不重写历史、不强制推送、不覆盖阶段 0／阶段 1 文件。
- 只提交本阶段新增或经明确批准修改的文件。
- 不提交缓存、临时导入产物、构建目录、机器专属配置、密钥或无关文件。
- 每个子阶段保留结果；最终检查完整 diff、暂存清单和 `git diff --cached --check`。
- 最终提交可以在用户明确授权后创建；推送必须另有明确授权。没有授权时只报告本地提交建议，不推送。
- 不自动合并到 main，不自动创建或合并 PR。

## A7. 建议目录

    docs/architecture/stage-1.5/
    ├── README.md
    ├── 01-windows-environment-audit.md
    ├── 02-toolchain-installation.md
    ├── 03-godot-validation.md
    ├── 04-android-export-validation.md
    ├── 05-sqlite-poc.md
    ├── 06-enet-network-poc.md
    ├── 07-renderer-benchmark.md
    ├── 08-final-acceptance.md
    ├── results/
    └── poc/
        ├── godot-smoke-test/
        ├── android-smoke-test/
        ├── sqlite-test/
        ├── enet-test/
        └── renderer-test/

实际目录可根据仓库现状调整，但不得把 PoC 放入正式游戏运行时代码目录。每个 PoC 的 README 应说明它是一次性验证项目，不是正式模块。

## A8. 每个子阶段的通用交付

每项测试都记录：
- 唯一测试编号；
- 测试目的和前置条件；
- Windows Build、硬件、工具及依赖版本；
- 执行命令和工作目录；
- 预期结果；
- 实际输出、退出码和耗时；
- 四态结论；
- 原始日志／截图／JSON 证据路径；
- 首次失败及修复重跑记录；
- 已知限制和后续动作。

每个子阶段完成后：
1. 更新对应 Markdown；
2. 保存结构化 JSON；
3. 核查证据文件确实存在；
4. 运行适用的文档／脚本自检；
5. 输出本阶段摘要和阻塞项；
6. 停止，等待用户审查和继续指令。

# B. 阶段 1.5.1 — Windows 10 环境审计

## 前置

读取并理解：
- `docs/architecture/README.md`
- `docs/architecture/14-environment-preparation.md`
- `docs/architecture/12-stage2-roadmap.md`
- `docs/architecture/adr/README.md`
- `docs/architecture/10-risk-register.md`
- `docs/architecture/11-requirements-traceability.md`

先确认仓库工作区干净且当前分支正确。若不干净，先报告，不覆盖用户改动。

## 审计内容

使用 PowerShell 原生命令和必要的只读工具采集：

1. Windows Edition、DisplayVersion、Build、架构、补丁状态、ESU 状态（ESU 无法自动确认时标记 UNKNOWN）。
2. CPU 型号、架构、逻辑处理器、虚拟化支持。
3. 总内存和可用内存。
4. 磁盘类型、总容量、剩余空间；检查项目盘和工具盘。
5. GPU 型号、驱动版本、Vulkan／OpenGL 能力（只能使用实际检测工具确认，缺工具则 BLOCKED）。
6. 网络适配器和网卡能力；不要输出公网 IP、SSID 密码或其他凭据。
7. PowerShell、Python、Git 版本。
8. Godot、Java／JDK、Gradle、ADB、sdkmanager、Android SDK 的存在性和版本。
9. 相关环境变量和 PATH 冲突；输出时隐藏用户目录之外的敏感路径信息。
10. Android 真机是否可用、USB 调试条件、ADB 授权状态；不要求用户现在连接设备。

## 建议只读命令

    Get-ComputerInfo
    Get-CimInstance Win32_Processor
    Get-CimInstance Win32_OperatingSystem
    Get-CimInstance Win32_PhysicalMemory
    Get-CimInstance Win32_VideoController
    Get-Volume
    Get-PhysicalDisk
    Get-Command git, python, godot, java, javac, adb, sdkmanager -ErrorAction SilentlyContinue
    $env:PATH

命令按实际系统可用性调整。不要因单条命令不可用而中止整个审计。

## 交付

- `01-windows-environment-audit.md`
- `results/environment-audit.json`

报告必须回答：
- 当前 Windows 10 是否适合继续作为开发主机？
- 是否满足 Godot 4.7.2 当前官方系统要求？
- 是否满足 Android 工具链当前官方要求？
- GPU 是否具备候选渲染器所需能力？
- 磁盘空间是否足够容纳 SDK、导出模板和 PoC？
- 是否建议升级 Windows 11？理由是什么？
- 哪些结论是已验证、哪些未知、哪些 BLOCKED？

**停止条件：** 完成审计后停止，不安装软件、不创建 PoC，等待用户审查。

# C. 阶段 1.5.2 — 工具链安装与固定

## 前置

1.5.1 已审查通过；用户已批准安装计划和任何所需系统级变更。

## 安装目标

- Godot 4.7.2 Standard x86_64（仅在官方发布和 Windows 兼容性核验通过后安装）。
- Godot 对应的 Android Export Templates。
- Godot 官方文档要求的 JDK。
- Android SDK Command-line Tools。
- Android Platform Tools（ADB）。
- 实际目标 API 所需 Android SDK Platform。
- Godot 导出所需 Android Build Tools。
- Python 仅在 PoC 确实需要且当前版本不足时补装。

项目使用 GDScript，不安装无关的 C#／.NET 工作负载。

## 安装步骤

1. 查阅 Godot 4.7 官方 Android 导出文档和下载页，确认 JDK、SDK、Build Tools、模板要求。
2. 查阅 Microsoft／Android Developers 官方要求，核实 Windows 10 支持边界。
3. 检查现有安装和目录，避免覆盖。
4. 提出安装清单、版本、体积、来源、目标路径和系统影响。
5. 等待用户批准安装计划。
6. 从官方来源下载和安装。
7. 记录下载 URL、版本、日期、SHA-256、安装路径。
8. 配置 Godot Editor Settings 中的 JDK／Android SDK 路径，优先项目或用户级设置；不要擅自修改机器级 PATH。
9. 安装与 Godot 版本匹配的 Android Export Templates。
10. 检查 ADB、sdkmanager 和 Godot 是否识别正确工具链。

## 目录建议

可以评估 `D:\DevTools\`、`D:\Android\Sdk\`、`D:\Projects\REAL-POOL-3D\`，但必须先检查磁盘和现有目录，不能盲目创建或假定盘符可用。

## 验证命令

    godot --version
    java -version
    javac -version
    adb version
    sdkmanager --version
    sdkmanager --list_installed

如工具命令不在 PATH，使用已确认的绝对路径并记录，不为了方便而擅自改全局 PATH。

## 交付

- `02-toolchain-installation.md`
- `results/toolchain-versions.json`
- `results/toolchain-verification.json`

记录版本、安装来源、SHA-256、路径、官方支持证据、导出模板状态、Godot 对 JDK／SDK 的识别结果和所有阻塞。

**停止条件：** 工具链安装和验证完成后停止，等待用户审查。

# D. 阶段 1.5.3 — Godot 基础验证

## 前置

1.5.2 的 Godot Editor 和模板相关检查通过。创建独立项目：

`docs/architecture/stage-1.5/poc/godot-smoke-test/`

## 测试内容

1. Godot 4.7.2 编辑器启动和退出。
2. 新建空项目。
3. 创建最小 Node 场景并保存。
4. 创建 GDScript，验证解析和执行。
5. 测试一个信号连接与触发。
6. 导入一个合法的测试资源（仅使用自制或许可清晰的资源）。
7. 关闭并重新打开项目，确认资源与场景可复现。
8. headless 模式编辑器检查。
9. headless 运行最小场景。
10. 采集标准输出、标准错误、退出码和 Godot 日志。
11. 检查是否存在脚本错误、资源导入错误、崩溃或警告。

命令示例（按实际安装路径替换）：

    godot --headless --path <项目路径> --editor --quit
    godot --headless --path <项目路径> --quit-after 3

不得仅凭退出码 0 就宣称全部通过；必须核对日志和预期行为。

## 交付

- `03-godot-validation.md`
- `results/godot-smoke-test.json`
- PoC 项目及原始日志。

**停止条件：** 完成后停止，等待用户审查。

# E. 阶段 1.5.4 — Android 导出验证

## 前置

1.5.3 PASS；Android SDK、JDK、导出模板已配置。

创建独立项目：

`docs/architecture/stage-1.5/poc/android-smoke-test/`

## 测试内容

1. 检查导出模板。
2. 检查 Godot 对 Android SDK 和 JDK 的识别。
3. 检查 Android export preset。
4. 核对 compile API、target API、Build Tools 与 Godot 官方要求。
5. 导出 Debug APK。
6. 检查 APK 文件存在、大小合理、SHA-256 可计算。
7. 检查 APK 包名、ABI 和最低系统版本。
8. 有 Android 设备时运行 `adb devices`，确认设备授权。
9. 安装 APK。
10. 启动应用并确认测试场景显示。
11. 采集 logcat，检查崩溃、权限和资源错误。
12. 测试应用退出和重新启动。
13. 初步检查横竖屏适配行为，但不实现正式 UI。

## Android 17/API 37 重点

核对 Android 17 对 target API 37 应用的最新权限规则，尤其是 `ACCESS_LOCAL_NETWORK` 运行时权限以及 UDP 单播、广播、接收相关限制。此子阶段只核对导出配置和权限能力，不实现正式 LAN 功能。以 Android 官方最新文档为准，不仅凭旧资料或架构文档断言。

## 结果边界

- APK 导出成功只证明导出链路，不代表 APK 能在设备运行。
- 模拟器和真机分别记录。
- 无设备时，安装、启动、生命周期和设备权限测试标记 BLOCKED。
- 不创建正式 Release／AAB，不进行商店签名或发布。

## 交付

- `04-android-export-validation.md`
- `results/android-export.json`
- APK SHA-256、导出日志、ADB 日志、设备型号（如有）。
- 不提交 APK，除非仓库已有明确的测试制品管理规则并经用户批准。

**停止条件：** 完成后停止，等待用户审查。

# F. 阶段 1.5.5 — SQLite GDExtension PoC

## 前置

Godot 桌面基础验证 PASS。依据 ADR-005 检查 godot-sqlite v4.9 候选版本；不要默认其已获最终批准。

## 静态核验

1. 确认官方仓库、发布页、维护状态和许可证。
2. 确认发布资产、支持平台、Godot 版本声明。
3. 检查 GDExtension ABI／构建兼容性说明。
4. 记录二进制来源、版本和 SHA-256。
5. 记录无法从静态资料确认的事项。

## 桌面动态测试

在 `poc/sqlite-test/` 建立隔离 Godot 项目，验证：

1. GDExtension 文件被发现和加载。
2. 扩展初始化成功，无 ABI 或符号错误。
3. 创建数据库和表。
4. 插入、查询、更新、删除。
5. 参数化 SQL。
6. 事务提交。
7. 事务回滚。
8. 唯一键约束。
9. 外键约束。
10. 数据库关闭和重新打开。
11. 数据库迁移／user_version。
12. 数据库损坏识别及恢复策略。
13. 资源释放和文件句柄关闭。
14. 重复执行测试的可重复性。

## Android 边界

桌面 PoC 通过不代表 Android GDExtension 可用。只有在 Android 导出工具链通过后，才可开展 Android 架构／ABI 对应的扩展加载和 CRUD PoC。没有 Android 设备时可完成导出层面的部分检查，但真机运行必须 BLOCKED。

不得把 Python sqlite3 测试当作 GDExtension 测试；Python 只能作为独立辅助对照。

## 决策输出

- 可进入 Android 扩展 PoC；
- 需要修复后重测；
- 需要更换候选扩展；
- 因缺少目标平台二进制或设备而 BLOCKED。

不因 ADR 已记录候选版本就强行通过。任何最终依赖变更须给出证据并更新 ADR。

## 交付

- `05-sqlite-poc.md`
- `results/sqlite-poc.json`
- 独立 PoC、原始日志、二进制来源及哈希清单。

**停止条件：** 完成桌面阶段后停止，等待用户审查；不得擅自进入正式数据层开发。

# G. 阶段 1.5.6 — UDP／ENet PoC

## 前置

Godot 桌面基础验证 PASS。

在 `poc/enet-test/` 创建最小独立 Host／Client 测试程序。

## 测试内容

1. 创建 ENet Host。
2. 创建 ENet Client。
3. 同一 Windows 主机运行两个独立进程。
4. 建立连接握手并交换连接状态。
5. 交换可靠消息。
6. 交换不可靠消息。
7. 检查消息顺序、丢失和重复（记录实际测量方法）。
8. 检查断线事件。
9. 客户端重连。
10. Host 异常退出。
11. 端口占用和错误处理。
12. Windows Defender Firewall 阻断时的表现；不擅自添加放行规则。
13. UDP 广播发现测试。
14. 有第二台设备时，验证同一局域网内真实设备发现和连接。
15. 分别记录有线、Wi-Fi 或不同网段等实际拓扑；未测不推断。

## Android 17 约束

以 Android 官方最新文档核验：
- `ACCESS_LOCAL_NETWORK` 声明和运行时授权；
- UDP 单播、广播和接收限制；
- Wi-Fi 网络切换；
- 应用前后台切换；
- 网络断开与恢复；
- 权限拒绝和再次授权的行为。

本机双进程只证明本机通信；不能证明 Android 权限、广播发现、跨设备连接或路由器隔离行为。

## 交付

- `06-enet-network-poc.md`
- `results/enet-poc.json`
- Host／Client 日志、测试拓扑、复现步骤、失败证据。

**停止条件：** 完成本机测试及可执行的设备测试后停止，等待用户审查。

# H. 阶段 1.5.7 — 渲染器基准

## 前置

Godot 基础测试 PASS。若 Android 导出尚未通过，桌面结果与 Android 结果必须分开，不得推断移动设备表现。

在 `poc/renderer-test/` 建立同一份测试内容，分别使用 Mobile 与 Compatibility Renderer。

## 对比原则

- 相同测试场景、资源、分辨率、窗口尺寸和测试时长。
- 记录渲染器名称、Godot 版本、GPU、驱动、操作系统 Build。
- 每种配置预热后重复测量，说明测量次数和统计口径。
- 不用单次 FPS 决定最终方案。
- 不把编辑器 FPS 当作导出游戏 FPS。
- 不将桌面 GPU 结果外推到 Android GPU。
- 不在没有设备数据时作出“目标设备性能达标”结论。

## 测量项目

1. 启动和场景加载时间。
2. FPS 分布（平均值及低分位数据，说明采样方式）。
3. CPU 使用情况。
4. GPU 使用情况（若工具可测）。
5. 内存占用。
6. 渲染错误和兼容性警告。
7. 材质、透明、阴影、纹理和基础后处理表现。
8. 长时间运行稳定性（仅在时间允许且测试方法明确时）。

## 交付

- `07-renderer-benchmark.md`
- `results/renderer-benchmark.json`
- 原始采样数据和复现命令。

结论应为有证据支持的建议，必要时保留双方案或 BLOCKED，不强行选定。

**停止条件：** 完成后停止，等待用户审查。

# I. 阶段 1.5.8 — 综合验收

## 前置

1.5.1 至 1.5.7 已逐项执行；未执行项必须保留 NOT RUN／BLOCKED，不得补写为 PASS。

## 验收工作

1. 汇总所有测试编号及四态结果。
2. 检查原始失败证据和修复后结果是否同时保留。
3. 检查所有 PASS 是否有真实命令、输出和可复核证据。
4. 检查 Godot 版本、JDK、SDK、Build Tools、模板版本一致性。
5. 检查 APK 导出与设备运行结论是否分开。
6. 检查 SQLite 桌面／Android 平台结论是否分开。
7. 检查 ENet 本机双进程／真实双设备结论是否分开。
8. 检查渲染器基准是否在相同条件下执行。
9. 更新 ADR：仅在实测证据足以支持时提出接受、修改或撤销决策。
10. 更新风险登记和需求追踪。
11. 更新阶段 2 路线图中的准入条件，但不得开始阶段 2。
12. 检查 Markdown 本地链接、结果 JSON 格式和证据文件存在性。
13. 检查 PoC 与正式运行时代码隔离。
14. 检查 Git diff、未跟踪文件、敏感信息和暂存范围。
15. 形成最终准入建议。

## 最终报告

创建 `08-final-acceptance.md`，至少包含：

- 执行摘要；
- 环境配置和 Windows 10 支持边界；
- 工具链版本、来源和 SHA-256；
- 各子阶段四态结果表；
- 证据索引；
- 首次失败及修复记录；
- BLOCKED／NOT RUN 项及原因；
- SQLite、ENet、渲染器实测结论；
- ADR 修改清单及理由；
- 风险变化；
- 未解决问题；
- 阶段 2 准入建议；
- Git 提交／推送状态。

最终结论只能是：
- `ACCEPTED`：所有规定的准入门禁均有足够证据通过；
- `ACCEPTED WITH BLOCKERS`：部分基础能力通过，但存在明确未解除的设备／平台门禁；不得将完整准入描述为已通过；
- `REJECTED`：关键基础能力失败或证据不可信。

## Git 与停止条件

- 检查只包含本阶段允许的文档、结果和隔离 PoC。
- 检查无密钥、凭据、个人绝对路径、无关缓存和大体积构建产物。
- 输出建议提交信息和完整文件清单。
- 未经用户明确授权，不创建最终提交、不推送、不合并。
- 用户授权提交后，创建独立提交并核验 SHA。
- 推送必须有单独明确授权。
- 阶段 1.5 完成后停止，等待用户审查。
- 不自动进入阶段 2，不创建正式游戏工程。

# J. Agent 每次执行时必须遵守的开场与结束格式

## 开始前

先报告：
1. 当前分支、HEAD、工作区状态；
2. 当前准备执行的子阶段；
3. 已满足的前置条件；
4. 本次预计修改／新增的文件范围；
5. 是否涉及安装、管理员权限、系统设置或设备操作；
6. 本次明确不会做的事项。

如前置条件不满足，停止并说明，不得跳过。

## 结束时

报告：
1. 实际执行命令；
2. 每项测试的 PASS／FAIL／BLOCKED／NOT RUN；
3. 原始证据路径；
4. 失败和修复情况；
5. 文件变更清单；
6. 未解决问题；
7. 下一子阶段的前置条件；
8. 明确声明已停止等待用户审查。

**本文件的最终约束：阶段 1.5 不是阶段 2 的隐式授权。任何阶段 2 工作都必须等待用户另行明确批准。**
