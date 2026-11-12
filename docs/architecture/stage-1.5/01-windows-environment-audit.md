# 阶段 1.5.1：Windows 10 环境审计

- 项目：REAL-POOL-3D
- 审计日期：2026-11-11（本地时区 UTC+08:00）
- 工作分支：`stage-1.5/environment-and-poc`
- 起始 HEAD：`38d517b4662e2ce1ec61977bceace96e21eb8c11`
- 范围：只读硬件、系统、开发工具和当前进程环境审计
- 最终有效结果：31 项检查，**17 PASS／4 FAIL／10 BLOCKED／0 NOT RUN**
- 总结论：**当前机器可有限用于过渡性准备，但不满足完整 Android Studio 当前最低 CPU 要求，也尚未具备 Godot／Android 构建准入条件。建议迁移到受支持的 Windows 11 开发机，而不是在本机直接升级或继续叠加工具。**

> 本报告不表示 Godot、APK 导出、Android 真机、SQLite、ENet、LAN 或渲染器 PoC 已通过。阶段 1.5.2 至 1.5.8 和阶段 2 均未执行。

## 1. 证据与复现入口

| 内容 | 路径 |
|---|---|
| 最终结构化结果，含每项目的、命令、预期、实际输出、退出码、耗时和证据路径 | [results/environment-audit.json](./results/environment-audit.json) |
| 最终完整控制台日志 | [results/environment-audit-console.log](./results/environment-audit-console.log) |
| 只读采集脚本 | [scripts/Invoke-WindowsEnvironmentAudit.ps1](./scripts/Invoke-WindowsEnvironmentAudit.ps1) |
| 历史证据隐私脱敏脚本 | [scripts/Redact-AuditEvidence.ps1](./scripts/Redact-AuditEvidence.ps1) |
| 证据自检脚本 | [scripts/Validate-Stage151Evidence.py](./scripts/Validate-Stage151Evidence.py) |
| 证据自检最终／首次失败日志 | [results/validation.log](./results/validation.log)、[results/validation.initial_fail.log](./results/validation.initial_fail.log) |
| 首次启动失败日志 | [results/environment-audit-console.initial_fail.log](./results/environment-audit-console.initial_fail.log) |
| 第一轮有效采集 JSON／日志 | [results/environment-audit.initial_fail.json](./results/environment-audit.initial_fail.json)、[results/environment-audit-console.run1.log](./results/environment-audit-console.run1.log) |
| 第二轮采集 JSON／日志 | [results/environment-audit.run2.json](./results/environment-audit.run2.json)、[results/environment-audit-console.run2.log](./results/environment-audit-console.run2.log) |
| 第三轮采集 JSON／日志 | [results/environment-audit.run3.json](./results/environment-audit.run3.json)、[results/environment-audit-console.run3.log](./results/environment-audit-console.run3.log) |

最终复现命令从仓库根目录执行。`<GODOT_BROKER>` 表示阶段 1 文档指定的受管 Godot broker 脚本；真实本机路径不写入仓库。

```bash
set -o pipefail
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
  -File "docs/architecture/stage-1.5/scripts/Invoke-WindowsEnvironmentAudit.ps1" \
  -GodotBrokerScript "<GODOT_BROKER>" \
  -OutputPath "docs/architecture/stage-1.5/results/environment-audit.json" \
  2>&1 | tee docs/architecture/stage-1.5/results/environment-audit-console.log
```

`ExecutionPolicy Bypass` 仅传给本次 PowerShell 进程，没有修改持久执行策略。最终 JSON 的 `executionHistory` 保存各轮失败和修复索引；历史文件只做了隐私脱敏，没有重写状态、退出码或数值结果。

## 2. 前置条件与范围核实

开始时的真实 Git 结果：

- 原 `main` 与 `origin/main` 为 `50a6dc6fc828f37dc05a0ff364e68a109d112ea0`。
- 指定执行提示词位于远端专用分支，已执行 `git -c http.proxy= -c https.proxy= fetch origin --prune`。
- 已执行 `git switch --track -c stage-1.5/environment-and-poc origin/stage-1.5/environment-and-poc`。
- 本阶段写入前复核到 HEAD `38d517b`，分支跟踪同名远端，工作区干净。
- 已阅读总控提示词、阶段 0 审计文档、阶段 1 架构文档及 ADR。阶段 1 的“PATH 未发现工具”没有被直接当作本轮全机结论；本轮补查了用户／机器级 PATH 和有界常见位置。

本次没有安装软件、请求管理员权限、修改系统设置、创建 Godot 工程或 PoC、连接或配置 Android 设备，也没有直接调用 Godot。仅写入本目录中的审计脚本和证据文件。

## 3. 最终四态结果总表

下表是最终结果。`—` 表示 PowerShell／CIM 查询没有独立原生进程退出码，不表示退出码 0；完整命令和耗时以 JSON 为准。

| ID | 状态 | 原生退出码 | 实际结论 |
|---|---|---:|---|
| WIN-001 | PASS | — | Windows 10 Pro、22H2、Build 19045.6466、64 位已采集。 |
| WIN-002 | PASS | — | 符合项目指定的 Windows 10 22H2 x64 基线。 |
| WIN-003 | PASS | — | `Get-HotFix` 返回 13 项；只代表该提供器可见记录。 |
| WIN-004 | FAIL | — | 未检测到 ESU Licensing Preparation Package `KB5126256`。 |
| WIN-005 | BLOCKED | — | 实际 ESU enrollment 为 `UNKNOWN`，需用户在 Windows Update 页面确认。 |
| WIN-006 | BLOCKED | — | 非管理员上下文没有可用 TPM 数据；Secure Boot 查询访问被拒绝。 |
| WIN-007 | BLOCKED | — | 未运行官方完整 Windows 11 资格检查，不能宣称整机可升级。 |
| CPU-001 | PASS | — | i7-4710MQ，4 核 8 线程，64 位，支持并启用虚拟化及 SLAT。 |
| CPU-002 | BLOCKED | — | 无 `coreinfo` 等实际特性工具，运行时 SSE4.2 检测未完成。 |
| CPU-003 | PASS | — | `VirtualizationFirmwareEnabled=true`，SLAT 为 true。 |
| CPU-004 | FAIL | — | Intel 官方资料将该 CPU 列为 2014 年 Q2，不满足 Android Studio 的 2017 年后微架构要求。 |
| MEM-001 | PASS | — | 物理内存 16 GiB；Windows 可见 15.89 GiB；最终快照可用 3.55 GiB。 |
| DISK-001 | PASS | — | 三块固定 NTFS 卷及两块 SATA SSD 的容量、健康和映射已采集。 |
| DISK-002 | PASS | — | 项目盘 E 剩余 111.23 GiB，且 E 满足候选工具盘 80 GiB 项目规划阈值。 |
| GPU-001 | PASS | — | Intel HD Graphics 4600、GTX 965M 和两个虚拟显示设备已采集。 |
| GPU-002 | PASS | 0 | `vulkaninfo` 实测 GTX 965M `apiVersion=1.0.65`，达到 Vulkan 1.0 最低线。 |
| GPU-003 | PASS | — | 当前报告分辨率 1920×1080，达到 Android Studio 1280×800 最低线。 |
| GPU-004 | BLOCKED | — | 未找到 `wglinfo`，OpenGL 3.3 能力未实测；DLL 存在不能替代检测。 |
| NET-001 | PASS | — | 网卡、链路和驱动已采集，未记录 IP、SSID、MAC 或凭据。 |
| NET-002 | PASS | — | 两个非虚拟接口为 Up；未做任何 LAN 通信测试。 |
| TOOL-001 | PASS | — | 64 位 Windows PowerShell 5.1.19041.6456。 |
| TOOL-002 | PASS | 0 | Git 2.47.1.windows.1。 |
| TOOL-003 | PASS | 0 | 当前 Python 3.12.15、AMD64；另有 Python 3.11 launcher／候选安装。 |
| TOOL-004 | BLOCKED | 2 | broker `doctor` 返回“找不到 Godot Editor binary”，未验证 Godot 4.7.2。 |
| TOOL-005 | FAIL | 0 | 实际执行到 Temurin JDK 21.0.11 和 javac 21.0.11；不是阶段 1 固定的推荐 JDK 17。 |
| TOOL-006 | FAIL | 9009 | 找到 Gradle 8.5，但当前进程无 `JAVA_HOME`／`java`，版本命令失败；未检查 Godot wrapper。 |
| TOOL-007 | BLOCKED | — | PATH、持久 PATH 和有界 SDK 位置均未找到 ADB。 |
| TOOL-008 | BLOCKED | — | PATH、持久 PATH 和有界 SDK 位置均未找到 sdkmanager。 |
| TOOL-009 | BLOCKED | — | 有界候选中未发现 Android SDK 根目录，未验证任何 SDK 包或组合。 |
| PATH-001 | PASS | — | 记录 41 个脱敏 PATH 条目、3 个失效条目、8 组跨作用域重复项、1 个多重命令解析项。 |
| DEV-001 | BLOCKED | — | 无 ADB，设备存在性、USB 调试和授权均为 `UNKNOWN`；未执行设备命令。 |

### 状态边界

- `TOOL-005=FAIL` 的验收口径是“阶段 1 推荐的 JDK 17 已就位”。Godot 文档也说明较高 JDK 可受支持，因此这不等于已证明 JDK 21 不能导出；实际兼容性仍须后续验证。
- `GPU-002=PASS` 只证明当前驱动向 `vulkaninfo` 报告了 Vulkan 1.0.65，不证明 Godot Mobile 能启动，也不达到推荐 Vulkan 1.2。
- `NET-002=PASS` 只是适配器清点，不能替代 UDP 发现、ENet、跨设备 LAN 或 Android 权限测试。
- `WIN-004=FAIL` 表示指定准备包未出现在 `Get-HotFix` 中，不表示能够推断所有商业 ESU 场景或真实授权状态。

## 4. 硬件与系统实测

### 4.1 Windows 与更新

| 项目 | 实测值 | 判断 |
|---|---|---|
| Edition | Windows 10 Professional／专业版 | 满足消费者 ESU 的 edition 条件之一。 |
| DisplayVersion／Build | 22H2／19045，UBR 6466 | Windows 10 22H2 基线通过。 |
| 架构 | 64 位 OS、64 位 PowerShell | 满足 Godot／Android Studio 的 64 位方向。 |
| 可见补丁 | 13 项 | `Get-HotFix` 不是完整 servicing／授权记录；部分日期异常，不据此推断系统已最新。 |
| ESU 准备包 | `KB5126256` 未发现 | FAIL；需人工核查更新与 ESU 页面。 |
| ESU enrollment | UNKNOWN | BLOCKED；不能由补丁或 UBR 推断已加入。 |
| TPM／Secure Boot | 无可用非管理员结果 | BLOCKED；未提权。 |

Microsoft 当前说明 Windows 10 常规支持已于 **2025-10-14** 结束。当前消费者 ESU 页面写明，符合条件的设备可加入至 **2027-10-12**；条件包括 22H2、相应版本、最新更新、`KB5126256` 及账户要求。实际机器是否已加入仍是 UNKNOWN。

### 4.2 CPU 与内存

| 项目 | 实测值 | 影响 |
|---|---|---|
| CPU | Intel Core i7-4710MQ @ 2.50 GHz | 4 核满足 Godot 推荐核数，但 Intel 官方列为 2014 年 Q2。 |
| 逻辑处理器 | 8 | 清点结果，不是性能基准。 |
| 虚拟化／SLAT | 均启用／支持 | 满足 Android Studio 的虚拟化条件之一。 |
| SSE4.2 | 未用实际特性工具确认 | Godot x86_64 最低要求仍为 BLOCKED。 |
| 物理内存 | 16 GiB | 达到 Godot 推荐 8 GB、Android Studio 8 GB 及 Studio＋Emulator 16 GB 的数量线。 |
| Windows 可见／可用 | 15.89／3.55 GiB | 可用内存只是瞬时快照，当前余量偏低，不是稳定性测试。 |

Android Studio 当前 Windows 表要求“2017 年后的 CPU 微架构”。因此，**完整 Android Studio GUI 路线在本机有明确 FAIL**。该表属于 Android Studio 整机要求，不能自动外推为独立 `sdkmanager` 命令行工具也具有相同 CPU 限制；Godot＋命令行 SDK 路线仍需单独验证。

### 4.3 磁盘

| 卷 | 文件系统／类型 | 总容量 | 最终快照剩余 | 判断 |
|---|---|---:|---:|---|
| E（项目盘） | NTFS／固定卷，SSD | 231.87 GiB | 111.23 GiB | 唯一满足保守工具盘阈值的候选。 |
| C（系统盘） | NTFS／固定卷，SSD | 149.44 GiB | 2.15 GiB | 低于 Android Studio 8 GB 最低线；系统更新和缓存风险高。 |
| D | NTFS／固定卷，SSD | 326.52 GiB | 14.02 GiB | 不满足 Studio＋Emulator 16 GB 最低线，也不满足项目 80 GiB 阈值。 |

项目额外采用的规划阈值是：**项目盘至少 20 GiB 可用，至少一个候选固定工具盘至少 80 GiB 可用**。这不是任何厂商的官方最低要求。E 通过该阈值；官方 Android Studio 表另列 Studio 8 GB、Studio＋Emulator 16 GB、推荐 SSD 32 GB 以上。

结论：容量可以规划到 E，但不能据此宣称整个系统已准备就绪。C 盘过低仍会影响更新、临时文件和默认缓存；本阶段没有清理、移动或创建任何工具目录。

### 4.4 GPU 与显示

| GPU／设备 | 驱动版本 | 实际 API 结论 |
|---|---|---|
| NVIDIA GeForce GTX 965M | 23.21.13.9135 | `vulkaninfo` 报告 Vulkan 1.0.65；仅达到 Mobile 最低 Vulkan 1.0。 |
| Intel HD Graphics 4600 | 10.18.15.4279 | 本次 Vulkan 输出未列出该设备；OpenGL／Vulkan 能力均未确认。 |
| OrayIddDriver／USB Mobile Monitor | 虚拟显示驱动 | 不作为物理 GPU 能力证据。 |

`vulkaninfo` 的实例版本为 1.1.126，退出码 0，但出现注册表层清单读取警告。原始输出完整保存在 JSON／日志中。GPU UUID、driver UUID 和 LUID 已脱敏，版本与能力字段未改动。

OpenGL 检测工具缺失，Compatibility 所需 OpenGL 3.3 为 BLOCKED。最终渲染器选择继续遵守 ADR-008，不因一次 `vulkaninfo` 结果提前选定 Mobile。

### 4.5 网络

- Realtek PCIe GbE：Up，1 Gbps。
- Remote NDIS Internet Sharing：Up，150 Mbps。
- Intel Wireless-AC 3160：Disconnected。
- 未采集 IP、SSID、MAC 或凭据；未执行 UDP、ENet、双进程或双设备测试。

## 5. 开发工具实测与环境冲突

| 工具 | 实际发现 | 状态／限制 |
|---|---|---|
| PowerShell | 5.1.19041.6456，64 位 | PASS。 |
| Git | 2.47.1.windows.1 | PASS；当前进程存在两个 Git 解析位置。 |
| Python | 当前为 3.12.15 AMD64；另有 3.11 候选 | PASS；安装多版本不等于冲突已解决。 |
| Godot | broker `doctor` 退出 2，未找到 binary | BLOCKED；没有直接运行 Godot。 |
| Java／javac | Temurin 21.0.11，两个命令均退出 0 | 对固定 JDK 17 目标为 FAIL；当前进程 PATH 中不可见。 |
| Gradle | 找到 8.5，但启动退出 9009 | FAIL；当前进程没有 `JAVA_HOME` 和 `java`。 |
| ADB | 未发现 | BLOCKED。 |
| sdkmanager／SDK | 未发现 | BLOCKED。 |
| Android 设备 | 无 ADB，未连接或配置设备 | BLOCKED。 |

`JAVA_HOME` 在用户级和机器级均指向同一 JDK 21 安装，Gradle 8.5 也位于用户 PATH，但当前审计进程没有继承这些条目。这解释了阶段 1“PATH 未发现”和本轮“实际安装存在”的差异。

本轮共记录 41 个 Process／User／Machine PATH 条目：

- 3 个当前不存在的路径；
- 8 组重复项，包含同一进程内重复和跨作用域重复，不应全部当成故障；
- Git 有两个解析位置；
- 当前 Python 路径有重复；
- 未修改任何 PATH、环境变量或持久配置。

## 6. 当前官方要求对照

以下来源均在 2026-11-11 重新读取。网页要求属于静态证据，不替代本机动态结果。

| 来源 | 与本机有关的当前要求 | 本机判断 |
|---|---|---|
| [Godot stable 系统要求](https://docs.godotengine.org/en/stable/about/system_requirements.html) | Windows 10；x86_64 SSE4.2；最低 4 GB／推荐 8 GB；Mobile 最低完整 Vulkan 1.0；Compatibility 最低 OpenGL 3.3；编辑器和缓存 200 MB、全部模板约 1.3 GB、推荐存储项合计 1.5 GB | OS、核数和 RAM 通过；SSE4.2、OpenGL、Godot binary 未完成；GTX 965M 仅实测 Vulkan 1.0 最低线。 |
| [Godot Android 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) | 推荐 OpenJDK 17；Platform-Tools 35.0.0+；Build-Tools 35.0.1；Platform 35；最新 Command-line Tools；NDK 28.1.13356709；CMake 3.10.2.4988404 | JDK 17 未就位，SDK／模板未验证，整体 BLOCKED。 |
| [Android Studio Windows 要求](https://developer.android.com/studio/install?hl=en#windows) | 64 位 Windows 10；Studio 8 GB／Studio＋Emulator 16 GB；2017 年后微架构；虚拟化；8／16 GB 磁盘，推荐 SSD 32 GB；1280×800 | CPU 明确 FAIL；完整 IDE 路线不推荐在本机实施。 |
| [Android 17 SDK setup](https://developer.android.com/about/versions/17/setup-sdk?hl=en) | `compileSdk=37`；Android Studio Meerkat 2024.3.1+；AGP 至少 8.9.0-rc01；最新 Build-Tools 37.x | API 37 目标尚未与 Godot 实际生成的构建链共同验证。 |
| [Microsoft Windows 10 支持结束说明](https://support.microsoft.com/en-us/windows/windows-10-support-ends-on-october-14-2025-2ca8b313-1946-43d3-b55c-2b95b107f281) | 常规支持于 2025-10-14 结束，建议升级受支持系统或加入 ESU | 当前继续长期使用有明确支持风险。 |
| [Microsoft Windows 10 ESU](https://www.microsoft.com/en-us/windows/extended-security-updates) | 消费者 ESU 至 2027-10-12；列出版本、更新、KB 和账户条件 | 本机准备包 FAIL，实际 enrollment UNKNOWN。 |
| [Intel 第四代 Core i7 官方规格](https://www.intel.com/content/www/us/en/ark/products/series/75023/4th-generation-intel-core-i7-processors.html) | i7-4710MQ 为 Q2'14 | 用于 CPU-004 的型号／年代核验。 |
| [Microsoft Windows 11 支持的 Intel 处理器](https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-intel-processors) | 当前列表从第八代 Core 起列示支持系列，未列第四代 i7-4710MQ | 不建议本机原地升级 Windows 11；完整资格检查仍 BLOCKED。 |

**不能拼接成已验证组合：**Godot 的 35.x 基线和 Android 17 的 API 37／37.x 要求服务于不同层面。必须在后续隔离 PoC 中读取 Godot 生成的 wrapper、AGP 和实际依赖解析结果，再确定最终包矩阵。

## 7. 必须回答的审计问题

### 7.1 当前 Windows 10 是否适合继续作为开发主机？

**只适合短期、受控的过渡准备，不适合作为长期主开发机。**它仍满足 Godot 的 Windows 版本基线，E 盘也有足够空间；但常规支持已结束、ESU 状态未知、准备包未检出、C 盘空间低，并且完整 Android Studio 的 CPU 最低要求不符合。

### 7.2 是否满足 Godot 4.7.2 当前官方系统要求？

**不能整体判定满足。**OS、CPU 核数、RAM、E 盘和 GTX 965M 的 Vulkan 1.0 最低线有正面证据；SSE4.2 运行时检测、OpenGL 3.3 和真实 Godot 4.7.2 binary 仍为 BLOCKED。因此 ADR-001 的本机验证状态不升级。

### 7.3 是否满足 Android 工具链当前官方要求？

**完整 Android Studio 路线不满足，CPU-004 为 FAIL。Godot＋命令行 SDK 路线为 BLOCKED。**JDK 21 不等于固定 JDK 17 已就位，Gradle 在当前进程启动失败，Godot、ADB、sdkmanager、SDK、模板和设备均未验证。

### 7.4 GPU 是否具备候选渲染器能力？

**Mobile 只有最低 Vulkan 能力的初步正面证据；Compatibility 为 BLOCKED。**GTX 965M 实测 Vulkan 1.0.65，但没有 Godot 渲染实测、没有达到推荐 Vulkan 1.2，也没有 OpenGL 3.3 检测。不能选择最终渲染器。

### 7.5 磁盘是否足够容纳 SDK、导出模板和 PoC？

**E 盘足够用于后续经批准的安装规划；C、D 不适合承担该工具链。**项目保守阈值通过，但 C 盘只剩 2.15 GiB，可能阻塞系统更新和默认缓存。实际安装体积仍须在 1.5.2 计划中逐项确认。

### 7.6 是否建议升级 Windows 11？

**建议迁移到受支持的 Windows 11 开发机，不建议在这台第四代 i7 机器上直接原地升级。**当前 Microsoft 支持 CPU 列表未列该型号；TPM／Secure Boot 和完整资格检查也未完成。若必须暂时保留本机，应先由用户人工确认 ESU 状态和更新条件，本阶段不执行升级或 ESU 操作。

### 7.7 哪些已验证、未知或 BLOCKED？

- 已验证：真实 OS／CPU／RAM／磁盘／GPU 型号、Vulkan 1.0.65、显示分辨率、网卡清点、PowerShell／Git／Python、JDK 21、Gradle 启动失败和当前 PATH 状态。
- 已明确失败：ESU 准备包未检出、Android Studio CPU 年代要求不符合、固定 JDK 17 未就位、Gradle 当前进程无法启动。
- 未知／BLOCKED：ESU enrollment、完整 Windows 11 资格、TPM／Secure Boot、SSE4.2 动态检测、OpenGL、Godot、SDK／ADB／sdkmanager、Android 设备与授权、全部后续 PoC。

## 8. 失败、修复与重跑记录

| 轮次 | 真实结果 | 修复与最终处理 |
|---|---|---|
| 初次启动 | `tee` 在结果目录不存在时退出 1，PowerShell 未启动，无 JSON | 原错误单独保留；创建结果目录后重跑，未修改系统配置。 |
| Run 1 | 16 PASS／2 FAIL／11 BLOCKED；`vulkaninfo --summary` 退出 1；Python 探针引号错误；漏查持久 PATH 工具 | 改用本机支持的无参数 `vulkaninfo`；修复 Python 探针；补查 User／Machine PATH；保留原 JSON／日志。 |
| Run 2 | 17 PASS／5 FAIL／9 BLOCKED；真实识别 JDK 21 和 Gradle 8.5；Vulkan 括号版本被解析器漏读 | 修复版本解析、数组／布尔值序列化和路径脱敏；原 GPU-002 FAIL 是解析缺陷，不改写历史。 |
| Run 3 | 18 PASS／4 FAIL／9 BLOCKED；仍有三处运行时路径未脱敏，TPM 空字段误为 PASS | 增加路径规则，要求至少一个真实 TPM／Secure Boot 值；保留原 JSON／日志。 |
| Run 4（最终） | **17 PASS／4 FAIL／10 BLOCKED** | JSON、日志、状态和 ID 自检；GPU UUID／LUID 仅做隐私替换。 |

辅助脚本的真实失败也保留在本记录中：

1. 脱敏脚本第一次用逗号字符串传数组，被绑定为单个不存在路径并产生 `Write-Error`；第二次把额外路径当作位置参数，退出 1；改用 PowerShell `-Command` 和显式数组后成功，六份历史证据分别完成 59、59、20、20、3、3 处路径替换。
2. 一次补充脱敏调用漏传进程级 `ExecutionPolicy Bypass`，被当前策略拒绝；改为仅该进程 Bypass 后成功，九份最终／历史文件各检查一次，含 GPU 标识的文件各替换 3 处。
3. 一条只读 Python 路径扫描命令因 shell 引号转义出现 `SyntaxError`，没有修改文件；随后改用 JSON 解析和仓库搜索工具完成复检。
4. Android Studio 系统要求的两次搜索请求返回工具侧 404；改为读取官方 install 页面并用实际 HTML 段落提取，最终取得 Windows 要求，未用猜测补全。
5. 首次证据验证器直接比较执行历史的 `NOT_RUN` 与归档 JSON 的 `NOT RUN` 键名，产生 `AssertionError: run1`；仅将验证器的历史汇总键名归一化后重跑，最终输出 `EVIDENCE_VALIDATION PASS`。首次和最终日志均已保留，未修改历史 JSON、审计状态或数值。
6. 新增文件空白自检首次把 LF→CRLF 提示视为失败；第二次关闭行尾转换后，又将原始控制台日志的 CRLF 逐行标记为 `trailing whitespace`。最终仅以命令级 `-c core.safecrlf=false -c core.whitespace=cr-at-eol` 重跑，在保留 CRLF 原样的同时检查真实行尾空格／Tab，结果通过；未修改 Git 持久配置或日志内容。
7. 一次 GPU 占位符负向前瞻搜索因当前搜索工具不支持 look-around 返回正则语法错误；改为在证据验证脚本中穷举实际值。首次穷举又因 JSON 字面前缀 `\t` 紧邻键名、开头词边界断言不匹配而以 `AssertionError` 结束；去掉多余的开头边界后重跑，18 个 GPU 标识值均为白名单占位符。上述验证器问题不影响任何审计检查状态，最终验证日志已覆盖本次中间失败输出。

## 9. 风险与 ADR 影响（仅建议，不修改既有决策）

| 关联项 | 本次增量证据 | 当前建议 |
|---|---|---|
| ADR-001 Godot 4.7.2 | OS／RAM／部分 GPU 有正面证据，但 binary、SSE4.2、OpenGL 未闭环 | 保持本机验证 BLOCKED，不改变 Accepted 的验证边界。 |
| ADR-004 LAN／ENet | 仅适配器清点 | 不升级任何网络验证状态。 |
| ADR-005 SQLite | 本阶段未检查扩展或数据库 | 不改变条件候选状态。 |
| ADR-007 触控／设备 | 无 ADB 和设备 | 设备验证仍 BLOCKED。 |
| ADR-008 渲染器门禁 | GTX 965M 仅达到 Vulkan 1.0 最低线；OpenGL 未测 | 保持 Proposed gate，不提前选定 Mobile。 |
| ADR-009 Android API 37 | 完整 Studio CPU FAIL；命令行路线和包矩阵未验证 | 优先评估受支持主机；若过渡使用本机，先验证命令行路线，不强行安装完整 IDE。 |

新增高优先级风险：Windows 10 支持状态、C 盘低余量、旧显卡驱动、持久 PATH 与当前进程不一致，以及把 JDK 21／Gradle 8.5 误当成已验证 Godot 构建链的风险。

## 10. 阶段 1.5.2 的前置条件与后续状态

进入 1.5.2 前必须由用户审查并明确授权，且先确定以下事项：

1. **主机路线：**优先选择受支持的 Windows 11 开发机；若继续暂用本机，确认这是过渡方案。
2. **系统支持：**由用户在“设置 → 更新和安全 → Windows Update”人工确认 ESU enrollment；不要仅凭本报告推断。
3. **安装路线：**本机完整 Android Studio 已有 CPU FAIL。若走 Godot＋命令行 SDK，先提交独立安装计划、版本、体积、来源、SHA-256、目标路径和系统影响，等待批准。
4. **磁盘与内存：**工具目标优先考虑 E；C 盘清理、缓存迁移或任何持久变更须另行批准。安装前关闭不必要应用以降低低可用内存风险。
5. **工具固定：**准备 Godot 4.7.2 Standard、匹配模板和 JDK 17；不要覆盖现有 JDK 21。Gradle 以 Godot 实际生成的 wrapper 为准，不把现有 8.5 当作已验证版本。
6. **环境配置：**任何 JAVA_HOME／PATH／Godot Editor Settings 变更都需列入获批计划，优先项目级或进程级，不擅自修改机器级配置。
7. **验证边界：**后续分别记录桌面、导出、真机、LAN、SQLite 和渲染器结果，不能互相替代。

| 后续工作 | 状态 |
|---|---|
| 阶段 1.5.2 工具链安装与固定 | NOT RUN |
| 阶段 1.5.3 Godot 基础验证 | NOT RUN |
| 阶段 1.5.4 Android 导出与设备验证 | NOT RUN |
| 阶段 1.5.5 SQLite PoC | NOT RUN |
| 阶段 1.5.6 UDP／ENet PoC | NOT RUN |
| 阶段 1.5.7 渲染器基准 | NOT RUN |
| 阶段 1.5.8 综合验收 | NOT RUN |
| 阶段 2 工程骨架及正式游戏功能 | NOT RUN，未授权 |

**本阶段已停止，等待用户审查。未执行阶段 1.5.2，未进入阶段 2。**
