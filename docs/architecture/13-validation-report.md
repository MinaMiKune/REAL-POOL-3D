# 阶段 1 验证报告

## 1. 结论与限制

验证日期：2026-11-11；工作区 `E:\KimiData\kimi\Workspaces\REAL-POOL-3D`；基线 `8d5e069`。实际可执行为 Python 3.12.15 数学/SQL/文档检查、Git 静态检查和官方网页/API证据核验。Godot Editor、JDK、Gradle、ADB、Android SDK 不存在于当前 PATH，相关动态验证统一为 `BLOCKED`。

本报告中的 `PASS` 只覆盖明确探针范围，不表示游戏、物理引擎、插件、网络、渲染或 Android 功能已经实现或通过。

## 2. 状态总表

| 验证 | 状态 | 实际结果/边界 |
|---|---|---|
| 阶段 0 九份审计与阶段提示词读取 | PASS | 已将 R-01…R-13 和产品目标映射到架构、ADR、风险与路线图 |
| 官方技术证据、维护状态、许可证 | PASS（静态证据核验） | Godot 4.7.2、godot-sqlite v4.9、Android API 37、网络/渲染、WPA 原文；未下载二进制 |
| Godot doctor | BLOCKED | 实际退出码 2，`candidates=[]`，找不到 Editor binary |
| JDK/Gradle/ADB/sdkmanager/环境变量 | BLOCKED | 实际探测全部 NOT FOUND/UNSET |
| Python 物理公式探针 | PASS | 8/8；只限公式特例 |
| Python SQLite 探针首次运行 | FAIL（已修正并重跑） | 7 PASS、1 FAIL；损坏库异常路径连接未关闭导致 WinError 32 |
| Python SQLite 探针修正后 | PASS | 8/8；首次失败 JSON 保留，修复为 finally 关闭连接 |
| 架构文档静态检查首次运行 | FAIL（已修正并重跑） | 6 PASS、1 FAIL；自身结果文件尚未生成导致两个结果链接缺失 |
| 架构文档静态检查修正后 | PASS | 7/7、100 个本地链接；首次失败 JSON 保留 |
| Git diff/范围/状态检查 | PASS | 最终命令输出见下文；仅静态检查 |
| Godot/GDScript/插件/网络/渲染/Android/设备 | BLOCKED | 无工具链、工程或设备，未执行，不虚构结果 |
| 后续正式玩法、发布和长周期 QA | NOT RUN | 超出阶段 1，且没有被测实现 |

## 3. 实际执行命令与结果

### 3.1 仓库基线

```bash
git status --short --branch
git log -1 --oneline
git ls-files | wc -l
```

结果：

```text
## main...origin/main
?? docs/architecture/
8d5e069 docs(audit): add stage 0 project audit
24
```

说明阶段 1 开始时 HEAD 与 origin/main 为阶段 0 提交，24 个跟踪文件；开始写入前工作区干净。后续新增 `.gitignore` 与架构文件，最终状态在第 6 节复核。

### 3.2 Godot 与 Android 工具链复测

```bash
python3 "E:/KimiData/daimon-share/daimon/runtime/kimi-code/home/plugins/managed/godot/scripts/godot_tool.py" doctor
```

实际输出：

```json
{
  "candidates": [],
  "error": "找不到 Godot Editor binary",
  "hint": "安装与项目版本匹配的 Godot Editor，并把 Godot.exe 的绝对路径写入 GODOT_BIN",
  "ok": false
}
```

退出码 `2`，判定 `BLOCKED`。没有裸跑 Godot，也没有自动下载。

```bash
for tool in java javac gradle adb sdkmanager godot godot4; do
  command -v "$tool" || echo "$tool=NOT FOUND"
done
for name in ANDROID_HOME ANDROID_SDK_ROOT JAVA_HOME GRADLE_HOME GODOT_BIN; do
  printenv "$name" >/dev/null 2>&1 || echo "$name=UNSET"
done
git --version
python3 --version
python3 -c 'import sqlite3; print("Python sqlite3=" + sqlite3.sqlite_version)'
```

实际结果：`java/javac/gradle/adb/sdkmanager/godot/godot4` 全部 `NOT FOUND`；五个环境变量全部 `UNSET`；Git `2.47.1.windows.1`，Python `3.12.15`，Python SQLite `3.53.1`。探测命令本身退出码 0，不代表构建工具可用。

### 3.3 物理公式探针

```bash
python3 docs/architecture/validation/physics_model_probe.py
```

退出码 `0`；Python `3.12.15`，Windows `10.0.19045`；`PASS=8, FAIL=0`。完整数值见 [physics_model_results.json](validation/results/physics_model_results.json)。

| 断言 | 关键实测值 |
|---|---|
| 正碰扫掠圆 TOI | `t=0.94285 s`，接触位置 `-0.05715 m` |
| 完全弹性等质量正碰 | 末速度 `0, 1 m/s`；动量前后 `0.17 kg·m/s`；能量前后 `0.085 J` |
| 分离接触 | 冲量 `0 N·s` |
| 库边特例 | `(2.0,0.5) → (-1.6,0.5) m/s`，未增能 |
| 高速连续库边检测 | tick `1/240 s`；TOI `0.000471425 s`；离散终点 `4.1667 m` 超过 `0.5 m` 限制但连续检测命中 |
| 减速不过零 | `0.001 → 0 → 0 m/s` |
| 滑动到滚动闭式特例 | `t_roll=0.5096839959 s`，`v_roll=rω=2.5 m/s`，转换滑移 `0` |
| 平行/超出 tick | 均返回无接触 |

这些结果不覆盖 GDScript、多接触、三维角冲量、jaw/袋口、收敛、渲染、Android 或跨平台确定性。

### 3.4 SQLite 草案探针：首次 FAIL 与修正

首次命令：

```bash
python3 docs/architecture/validation/sqlite_schema_probe.py
```

退出码 `1`；Python SQLite `3.53.1`；`PASS=7, FAIL=1`。失败为：

```text
corruption_quarantine_and_restore: FAIL
PermissionError: [WinError 32] 另一个程序正在使用此文件，进程无法访问。
.../corrupt.db
```

根因是探针在 `PRAGMA integrity_check` 抛出 `DatabaseError` 后未关闭 `candidate` connection，Windows 文件锁阻止隔离重命名。原始结果保留在 [sqlite_schema_results.initial_fail.json](validation/results/sqlite_schema_results.initial_fail.json)。没有将这次运行改写为 PASS。

随后保留失败文件并重跑：

```bash
cp docs/architecture/validation/results/sqlite_schema_results.json \
  docs/architecture/validation/results/sqlite_schema_results.initial_fail.json
python3 docs/architecture/validation/sqlite_schema_probe.py
```

首次修正是在异常/正常路径共用的 `finally` 中关闭 candidate。提交前自检又补齐了 bootstrap 的 v1 迁移基线/hash 校验，并将正常 shot 的 `termination` 约束收紧为仅 `AT_REST`。最终重跑退出码 `0`，`PASS=8, FAIL=0`，schema SHA-256 为 `39f5c38d1fc2e4d7f73fd8759ff499fa23592fc3f8600099eec15f7fa28d7c9b`。完整结果见 [sqlite_schema_results.json](validation/results/sqlite_schema_results.json)。

| 断言 | 修正后结果 |
|---|---|
| schema/PRAGMA/迁移基线 | 7 个目标表存在，`user_version=1`，`foreign_keys=1`；唯一 v1 基线记录及 schema SHA-256 一致 |
| 参数化 CRUD | 类 SQL 注入文本作为数据保留，matches 表仍存在 |
| shot 原子提交与回放 hash | shots=1、revision=1、ordinal=1，chunk SHA-256 一致 |
| 重复 ordinal | UNIQUE 错误，回滚后 shots=1、revision=1 |
| 外键/JSON/技术失败约束 | 非存在 match、非法 JSON 和 `NON_CONVERGENCE` 均被约束拒绝；技术失败回滚后 shots=0、revision=0 |
| 注入异常回滚 | 状态保持 IN_PROGRESS/revision=0，临时设置 0 行 |
| 备份完整性 | integrity_check=ok，外键违规 0，三表计数正确 |
| 损坏隔离与恢复 | 检出 `file is not a database`；原损坏字节保留；恢复 integrity=ok、matches=1 |

只证明 Python sqlite3/SQL 草案与文件流程；godot-sqlite 未下载、未加载、未测试，Android/user:// 行为不在此结果内。

### 3.5 文档静态检查

首次命令：

```bash
python3 docs/architecture/validation/check_architecture_docs.py
```

首次退出码 `1`，`PASS=6, FAIL=1`：检查器在写出自身 JSON 前检查链接，导致报告和验证 README 中指向 `documentation_check_results.json` 的两个链接被判不存在。原始结果保留在 [documentation_check_results.initial_fail.json](validation/results/documentation_check_results.initial_fail.json)。

随后保留失败文件，令检查器在链接检查前创建自身输出文件，再执行：

```bash
cp docs/architecture/validation/results/documentation_check_results.json \
  docs/architecture/validation/results/documentation_check_results.initial_fail.json
python3 docs/architecture/validation/check_architecture_docs.py
```

最终重跑退出码 `0`；`PASS=7, FAIL=0`，本地链接 `100` 个且无缺失。检查必需文档和非空内容、无占位标记、本地 Markdown 链接、ADR 六类必要章节、REQ-01…18 与 R-01…22、无阶段 2 运行文件、.gitignore 和版本/许可证证据 pin。完整结果见 [documentation_check_results.json](validation/results/documentation_check_results.json)。

这是静态一致性检查，不证明架构技术正确、外部 URL 永不可变或运行功能完成。

### 3.6 官方来源读取

本阶段实际读取 Godot 官方 release/download/license/Android/GDExtension/PacketPeerUDP/ENetMultiplayerPeer/SceneMultiplayer/renderers/OS 文档，godot-sqlite 官方 release/API/固定 tag manifest/LICENSE，SQLite 官方版权页，Android 官方 API 37 setup/local network/behavior changes，以及 WPA 2026-10-21 规则 PDF。准确 URL、返回版本和限制见 [技术证据](09-technology-evidence.md)。

这些是读取工具请求而非本地 shell 构建命令；没有把网页内容当作运行 PoC。

## 4. BLOCKED 矩阵

| 验证 | 缺失前提 | 安装后可复现入口 |
|---|---|---|
| Godot capabilities/version | Editor binary/GODOT_BIN | broker `doctor`、`capabilities --json` |
| project-info/scan-project | 上项 + 阶段 2 最小 project.godot | broker `project-info --project <ROOT>`、`scan-project --project <ROOT>` |
| 导入、主场景、GDScript | 上项 + 场景/脚本/runner | broker import/test plan，经批准后执行 |
| SQLite GDExtension | Godot + 官方 v4.9 资产 | 桌面隔离加载/CRUD/事务/迁移/备份 |
| Android SQLite | 上项 + JDK/SDK/模板/Gradle/ADB/arm64 设备 | Android 隔离 PoC 同套测试 |
| UDP/ENet 网络 | Godot + 隔离网络 PoC；Android 另需权限和设备 | 双进程、双设备协议/故障矩阵 |
| Mobile/Compatibility | Godot + 双构建 + 目标设备 | 同内容性能/截图/稳定性比较 |
| Android API 37 导出 | JDK 17、SDK 37、模板、wrapper、ADB | 读取实际版本，export/assemble/install |
| LAN 权限/生命周期/触控 | API 37 应用和设备 | 允许/拒绝/撤销、旋转/后台/多点输入 |
| 性能/温度/耗电/崩溃 | 可运行构建、基准和设备 | 固定场景、原始指标、logcat/soak |

完整安装准备和命令见 [环境准备](14-environment-preparation.md)。这些项目没有被标记 FAIL，因为它们没有可执行的测试对象；也没有标记 PASS。

## 5. NOT RUN 矩阵

| 项目 | 原因 |
|---|---|
| 正式物理、规则、AI、对局、回放、训练、实验室测试 | 属于后续阶段且没有实现；本阶段禁止提前创建 |
| Release/AAB、签名、商店、安装升级和回滚发布验收 | 后续发布范围，无工程/产物 |
| 真实球桌参数校准、人机难度体验、长局/长周期 QA | 后续校准/QA 范围，无实现和设备矩阵 |
| 其他 SQLite 插件、自编译 GDExtension、Kotlin 插件、NSD/mDNS | 首选方案尚未能实测，不能未获批准扩张替代依赖 |
| 外部测试框架和完整 CI 服务 | 尚未选型/搭建，阶段 2 路线已列 |
| SDK 安装、依赖下载和本文中的准备命令 | 当前未获安装任务且大型工具缺失；命令提供作后续复现，不声称已执行 |

## 6. 最终 Git 与范围自检

最终自检命令及其结果在本节保持与提交前实际输出一致：

```bash
git diff --check
git status --short
git diff --stat
```

`git diff --check` 无输出、退出码 0；状态只包含本阶段 `.gitignore` 和 `docs/architecture/` 新文件。`git diff --stat` 对未跟踪文件默认不显示，因此完整新增清单以 `git status --short --untracked-files=all` 和提交后 `git show --stat --oneline HEAD` 为准。没有创建 `project.godot`、GDScript、场景、addons、Android 工程、构建产物或正式游戏功能。

## 7. 未解决项

工具链、SQLite ABI/Android、渲染器、物理多接触/校准/跨平台、LAN 权限与广播、数字规则差异、项目许可证和设备矩阵仍未解决，详见 [风险更新](10-risk-register.md)。阶段 2 必须按 [路线图](12-stage2-roadmap.md) 先完成真实 PoC，不得把本报告的 Python PASS 当作解除这些门禁。
