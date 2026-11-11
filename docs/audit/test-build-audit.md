# 测试、CI、构建与复现审计

## 1. 总体结论

仓库没有测试、CI、构建脚本、性能基准、构建产物或复现说明。当前唯一可完成的是 Git/文档层面的静态核验；Godot 导入运行、GDScript 检查、资源导入、自动化测试、Android 构建和设备测试全部为 `BLOCKED`。

根 `README.md:1-2` 只有项目名称与简介，没有安装、导入、测试、导出或环境说明。`git ls-files` 的完整清单只有 15 个 Markdown 文件。

## 2. 测试与构建资产

| 检查项 | 仓库现状 | 证据 |
|---|---|---|
| 单元/集成/场景测试 | 无 | `git ls-files 'test/*' 'tests/*'` 无输出 |
| 测试 runner 与测试依赖 | 无 | 无 GDScript、项目文件或依赖清单 |
| CI | 无 | `git ls-files '.github/workflows/*'` 无输出 |
| 构建脚本 | 无 | 无 Gradle、包装器、Makefile 或构建配置 |
| Godot 导出配置 | 无 | 无 `export_presets.cfg` |
| 性能基准与结果 | 无 | 无基准场景、脚本、日志或报告 |
| 缺陷记录 | 无专门台账 | 本阶段风险见 `risk-register.md`；无历史实现缺陷可复现 |
| 构建产物与校验和 | 无 | 无 APK/AAB，无法计算产物 SHA-256 |
| 干净环境复现说明 | 无 | `README.md` 无工具链或步骤 |

## 3. 实际执行的检查

审计环境：2026-11-11 11:35:12（UTC+08:00），Windows MSYS2/Git Bash；Git `2.47.1.windows.1`，Python `3.12.15`。

| 命令 | 实际结果 | 判定 |
|---|---|---|
| `git fetch origin` | 默认代理 `127.0.0.1:10808` 连接失败，退出码 128 | 环境问题；未同步 |
| `git -c http.proxy= -c https.proxy= fetch origin` | 成功获取 `c90d986..bf0cbba` | PASS |
| `git merge --ff-only origin/main` | Fast-forward；本地 HEAD 与 `origin/main` 均为 `bf0cbba70867f09ad7363e455dd7bcdc89a5092e` | PASS |
| `git status --short --branch` | 写审计文档前只有 `## main...origin/main` | PASS，基线干净 |
| `git log --oneline --decorate --stat --all` | 仅初始 README 与提示词文档提交 | PASS，未见实现提交 |
| `git ls-files -s` | 15 个条目，全部 `100644` Markdown | PASS，建立清单 |
| `git fsck --full` | 无错误输出，退出码 0 | PASS，仅证明 Git 对象完整 |
| `git diff --check` | 写审计文档前无输出，退出码 0 | PASS，仅覆盖当时已跟踪 diff |
| `git check-ignore -v --no-index .godot/ .gradle/ build/ local.properties export_presets.cfg` | 无匹配 | 暴露忽略规则缺口，不是构建测试 |
| `git submodule status` | 无输出 | 未发现子模块 |
| `git lfs ls-files` | 无输出 | 无 LFS 跟踪文件 |
| `python3 scripts/godot_tool.py doctor`（从 Godot 插件根目录执行） | 退出码 2；`candidates: []`；找不到 Godot Editor binary | BLOCKED |
| `java -version; javac -version; gradle -v; adb --version; sdkmanager --version` | 五个命令均 `command not found`，最终退出码 127 | BLOCKED |
| `printenv ANDROID_HOME ANDROID_SDK_ROOT JAVA_HOME GRADLE_HOME GODOT_BIN` | 无输出 | 当前 shell 未设置这些变量 |

代理问题通过单次明确绕过失效代理解决，没有修改持久 Git 配置。这属于本次同步环境限制，不是项目代码缺陷。

## 4. 未执行项目及原因

| 检查 | 状态 | 原因 |
|---|---|---|
| Godot `capabilities` | BLOCKED | `doctor` 未找到 binary，不能读取实际版本/flags |
| `project-info` / `scan-project` | BLOCKED | 无 `project.godot`，且无 Godot binary |
| Godot 导入与主场景启动 | BLOCKED | 无项目、主场景和 Godot binary |
| GDScript 语法/静态检查 | BLOCKED | 无 `.gd` 文件和 Godot binary |
| 场景树与资源依赖回读 | BLOCKED | 无场景、资源和 Godot binary |
| 规则/物理/AI/网络/存储自动化测试 | BLOCKED | 无实现、测试资产和 runner |
| Android Debug/Release 构建 | BLOCKED | 无导出配置、源码、SDK、JDK、Gradle 和模板 |
| APK/AAB 安装和冒烟 | BLOCKED | 无构建产物和 ADB |
| 横竖屏、触控、生命周期和 LAN 双设备测试 | BLOCKED | 无应用与设备连接 |
| 性能、发热、耗电和长时间基准 | BLOCKED | 无可运行构建、基准或设备 |
| 资源缺失和视觉验收 | BLOCKED | 无资源、场景和渲染环境 |

没有将这些未执行项目标为失败或通过；它们都没有测试证据。

## 5. CI 与复现风险

- 无 CI 意味着即使后续加入代码，也没有自动阻止回归的现有门禁。
- 无版本锁定与安装文档，无法从干净环境复现 Godot 或 Android 工具链。
- 无 `.gitignore`，未来 `.godot/`、`.gradle/`、`build/` 和本地配置可能被误提交。
- 无测试金字塔、覆盖率目标、物理数值断言、协议异常注入或性能基线。
- 无发布产物，因而没有文件大小、SHA-256、签名、安装升级或回滚证据。

## 6. 后续最小验证链建议

后续获批阶段应先建立：项目导入 → 最小主场景启动 → 测试 runner → 核心单元/场景测试 → 可复现 Android 导出 → 实机冒烟 → 性能基准。每一步记录准确命令、环境、版本、结果和限制。本阶段仅完成审计文档，不提前搭建该链路。
