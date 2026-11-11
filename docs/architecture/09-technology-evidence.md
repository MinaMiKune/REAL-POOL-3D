# 技术选型与官方证据台账

## 1. 核验范围

核验日期：2026-11-11。优先使用 Godot/Android/SQLite/WPA 官方文档和项目官方 GitHub 仓库。网页内容可能变化，阶段 2 实际下载前必须重新核对 release、digest、许可证与目标平台。本阶段没有下载或安装 Godot、模板、插件、SDK 或第三方二进制。

## 2. 决策总表

| 领域 | 选择/状态 | 证据与许可证 | 兼容性和维护结论 | 必须验证 |
|---|---|---|---|---|
| 引擎 | Godot `4.7.2-stable`，standard/GDScript | 官方 release 与下载归档；MIT | 官方仓库 2026-08-18 发布正式版；本机未安装 | doctor、capabilities、导入、模板匹配 |
| 物理 | 定制固定 240 Hz 2.5D，非通用刚体权威 | 项目需求；无需新增库 | 架构可行不等于真实感/收敛已验证 | 数值、场景、跨平台、性能 |
| 规则 | `WPA_2026_DIGITAL_V1` 纯 reducer | WPA 2026-10-21 官方规则 PDF | 数字差异显式化；规则文本不是开源代码许可证授权 | 全状态迁移和争议样例 |
| AI | 同一 ShotCommand、克隆预测、版本化 seed | 自研设计，无新增依赖 | 五档参数仅为待校准初值 | 合法性、难度分布、移动端耗时 |
| LAN | UDP 广播 + ENet + 固定二进制 envelope | Godot 官方类文档；随引擎的第三方许可需保留 | API 存在证据，不是 Android API 37 可用证据 | 双进程/双设备、异常注入、权限 |
| SQLite | `2shady4u/godot-sqlite v4.9` 条件候选 | 官方仓库 release；插件 MIT，SQLite Public Domain | release 基于 4.7.1；声明 Android arm64/x86_64；近期有提交，质量不保证 | 4.7.2 桌面/Android 加载和完整数据 PoC |
| 回放 | 初始快照+命令+事件+最终状态+版本/hash | 自研格式；无新增依赖 | 不承诺跨版本浮点重算 | 规范编解码、分歧、旧版降级 |
| Android | API 37，OpenJDK 17，Godot 生成 wrapper | Godot/Android 官方文档 | AGP/Gradle/SDK 实配未读取，构建 BLOCKED | 最小 APK、安装、升级、Manifest |
| LAN 权限 | `ACCESS_LOCAL_NETWORK` 运行时请求 | Android 官方 API 37 文档；Godot OS 文档 | `OS.request_permission` 路径未经 Godot 4.7.2/API 37 实测 | 允许、拒绝、撤销、UDP 收发 |
| 渲染 | Mobile 与 Compatibility 双构建门禁，最终选择 BLOCKED | Godot 官方 renderer 对比 | 理论上分别适配移动/低端，不可替代设备数据 | 同内容性能、视觉、稳定性 |
| 触控/UI | Godot Control/Input + 自研状态机，响应式横竖屏 | Android 官方大屏行为变化 | 不能锁方向规避 sw≥600dp 要求 | 多点、旋转、安全区、分屏 |

## 3. Godot 官方证据

### E-G01：准确版本和导出模板

- [Godot 官方 GitHub latest release](https://api.github.com/repos/godotengine/godot/releases/latest) 在本次核验返回 `4.7.2-stable`，`prerelease=false`，`published_at=2026-08-18T16:12:28Z`，并列出同版 export templates。
- [Godot 4.7.2 官方下载归档](https://godotengine.org/download/archive/4.7.2-stable/)提供 Windows、Android 和 Export templates 下载入口。
- 选择 standard 而非 .NET，因需求优先 GDScript，未证明 .NET Android 额外复杂度的必要性。

### E-G02：许可证

- [Godot 官方许可页](https://godotengine.org/license/)明确引擎为 MIT/Expat；分发引擎 binary 必须附版权与许可声明，游戏内容可另行授权。
- 本项目自身尚未声明 LICENSE，不能因 Godot MIT 推断项目代码/资源许可证。

### E-G03：Android 导出工具链

- [Exporting for Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)列出 OpenJDK 17、Platform-Tools 35.0.0+、Build-Tools 35.0.1、Platform 35、Command-line Tools latest、NDK `28.1.13356709`、CMake `3.10.2.4988404`。
- 同页说明可在编辑器配置 Java SDK/Android SDK 路径，以及 Gradle build/AAB 和签名环境变量。
- 这些版本是官方基线，不证明它们与 API 37/插件在本机组合可构建。

### E-G04：GDExtension 兼容性

- [GDExtension C++ example](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/gdextension_cpp_example.html)说明旧 minor 目标扩展向后兼容较新 minor 是长期目标，但反向不成立；文档仍提示兼容性风险。
- 因而针对 4.7.1 构建且 `compatibility_minimum=4.7` 的 v4.9 与 4.7.2 是合理候选，不是免实测保证。 precision/feature 必须一致，standard 与 .NET 模板选择也需实测。

### E-G05：网络 API

- [`PacketPeerUDP`](https://docs.godotengine.org/en/stable/classes/class_packetpeerudp.html)支持 raw UDP、broadcast、multicast，并提示 Android `INTERNET`；部分设备广播/组播另有权限要求。
- [`ENetMultiplayerPeer`](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)明确 ENet 只使用 UDP，提供 client/server 和 channel 参数。
- [`SceneMultiplayer`](https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html)提供 `send_bytes`/`peer_packet`；`allow_object_decoding` 默认 false，开启不可信对象解码有远程代码执行风险。高层 Godot 协议是实现细节，因此应用 envelope 自行版本化。

### E-G06：渲染器

- [Godot renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)对比 Forward+、Mobile、Compatibility：Mobile 面向移动端和 RenderingDevice 后端；Compatibility 面向低端/OpenGL；Forward+ 面向桌面。
- 文档明确选择需结合硬件和功能，故本项目坚持同内容真机门禁。

### E-G07：权限 API

- [`OS.request_permission`](https://docs.godotengine.org/en/stable/classes/class_os.html)要求完整权限名，返回 true 仅表示已经授予；结果通过 `MainLoop.on_request_permissions_result` 返回，权限必须在导出时声明。
- 这是 API 存在证据，不证明新 `ACCESS_LOCAL_NETWORK` 在 4.7.2 的导出 UI/custom permission 和 Android 17 设备链路已工作。

## 4. godot-sqlite 官方仓库证据

### E-S01：release 和维护状态

- [v4.9 release](https://github.com/2shady4u/godot-sqlite/releases/tag/v4.9)由官方仓库发布于 2026-08-09，非 draft/prerelease；release notes 写明 Godot `4.7.1-stable`、SQLite `3.51.0`、Android arm64/x86_64。
- [GitHub latest release API](https://api.github.com/repos/2shady4u/godot-sqlite/releases/latest)本次返回 tag `v4.9`，`addons.zip` 大小 72,102,324 bytes，digest `sha256:95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0`。该 digest 来自发布元数据，**不是本地下载文件 hash**。
- [官方 commits API](https://api.github.com/repos/2shady4u/godot-sqlite/commits?per_page=1)本次返回最近提交 `1e432b3b03eac186351a8f482226654e1ccd0ce3`，日期 2026-08-25。只能说明近期有维护活动，不能证明无缺陷、长期维护或发布包含该后续提交。

### E-S02：平台条目

- 固定 tag 的 [`gdsqlite.gdextension`](https://raw.githubusercontent.com/2shady4u/godot-sqlite/v4.9/demo/addons/godot-sqlite/gdsqlite.gdextension)写明 `compatibility_minimum="4.7"`，含 Windows/Linux x86_64、Android arm64/x86_64、macOS/iOS/web library 条目。
- 目标首个真机为 Android arm64；x86_64 可用于模拟器。没有 arm32 条目，不支持 32-bit Android 是明确限制，与 Android 17 目标不冲突但需写入设备范围。

### E-S03：许可证和 SQLite

- 固定 tag 的 [`LICENSE.md`](https://raw.githubusercontent.com/2shady4u/godot-sqlite/v4.9/LICENSE.md)为 MIT，版权 2019–2026 Piet Bronders & Jeroen De Geeter。
- [SQLite 官方版权页](https://www.sqlite.org/copyright.html)声明 SQLite deliverable code 为 Public Domain；构建脚本可能有其他许可，但最终 SQLite library 不包含这些构建脚本。
- 引入 `addons.zip` 时仍需检查实际 ZIP 内全部 notices、 bundled libraries 和文件清单，不能仅用仓库顶层 LICENSE 覆盖所有二进制。

### 条件决策

v4.9 仅作为隔离 PoC 的首选候选，**尚未引入**。若桌面或 Android 任一关键 PoC 失败：先保留 repository 接口，评估同一上游针对 4.7.2 的构建或维护者批准的替代插件；不私自更换 JSON/云数据库，也不从非官方镜像下载二进制。

## 5. Android 官方证据

### E-A01：API 37 编译

- [Set up the Android 17 SDK](https://developer.android.com/about/versions/17/setup-sdk?hl=en)要求 `compileSdk=37`，推荐 Android Studio Meerkat 2024.3.1+，AGP 至少 8.9.0-rc01，并说明安装 Build-Tools 37.x。
- Godot 生成工程的 AGP/Gradle wrapper 必须在阶段 2 读取后决定是否需要升级；不得把 rc 下限写成项目最终锁定版本。

### E-A02：LAN 运行时权限

- [Local network permission](https://developer.android.com/privacy-and-security/local-network-permission?hl=en)（页面更新 2026-11-03）说明 Android 17/API 37 对 target 37+ 强制 `ACCESS_LOCAL_NETWORK`；UDP 单播/广播/组播收发均需权限，未授权 UDP 可出现 `EPERM`。
- 权限必须 Manifest 声明并在 LAN 前运行时请求；拒绝/撤销会阻断流量。系统 picker 是不同使用模式的替代，不是本项目广播发现的直接等价替换。

### E-A03：大屏方向

- [Apps targeting Android 17 behavior changes](https://developer.android.com/about/versions/17/behavior-changes-17?hl=en)说明 sw≥600dp 的方向/可调整大小/长宽比限制忽略行为，target 37 不再提供 Android 16 的 opt-out。
- 因此响应式横竖屏和分屏是基础要求，不可锁定横屏规避。

## 6. WPA 规则证据

- [WPA Rules of Play，effective 2026-10-21](https://wpapool.com/wp-content/uploads/2026/10/WPA-Rules-2026-10-21-211.pdf)第 4 节明确：合法开球进球后继续且桌面开放；无进球时至少四个目标球碰库；非法开球选择；开球 8 的特殊处理；开放球桌/叫球；safety；8 输局条件。
- 通用 3.13 明确三次连续犯规规则不适用于 8-Ball，故默认不采用“三次犯规判负”。
- 规则文档的文本/图表版权不因此转化为可随意再分发资源；实现只引用条款号和自行表达状态逻辑，发布时保留来源链接，不直接捆绑 PDF/图片除非另有许可。

## 7. 第三方依赖治理

阶段 2 每个新增组件必须登记：名称、用途、精确版本、来源 URL、release/digest、许可证、维护证据、目标 ABI、引入文件、验证命令、回退方案。Godot 自带 ENet 等组件也要随引擎第三方 notices 保留归属。

Android SDK/JDK/Gradle 是构建工具，不应把其可再分发许可与游戏 bundle 混为一谈；只记录安装版本和许可接受情况，不把工具链复制进仓库。签名材料、SDK 本地路径和密码不能入库。

当前没有批准其他网络库、ORM、AI 库、测试框架、Kotlin 插件或资源包；任何新增都需要独立证据，不以“GitHub 流行”替代兼容性与维护核验。
