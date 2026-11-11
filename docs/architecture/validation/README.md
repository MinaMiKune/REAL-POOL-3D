# 阶段 1 隔离最小验证

## 边界

本目录只含设计验证资产，不是 Godot 工程、正式游戏功能或生产依赖。Python 探针不能替代 Godot/GDScript、godot-sqlite、ENet、渲染器或 Android 设备验证。

## 资产

| 文件 | 用途 | 能证明 | 不能证明 |
|---|---|---|---|
| `physics_model_probe.py` | 扫掠圆、弹性正碰、库边特例、高速 TOI、减速、滑动到滚动 | 所列 Python 数学特例的实际断言结果 | 多接触、3D 旋转耦合、袋口、Godot 物理、真实感、跨平台确定性 |
| `schema_v1.sql` | SQLite v1 可执行草案 | 表/约束/索引的明确版本 | 已是正式生产 schema 或迁移完成 |
| `sqlite_schema_probe.py` | 临时库建表、CRUD、事务、约束、备份、损坏隔离恢复 | 当前 Python SQLite 版本上的 SQL/文件流程 | 插件 ABI、user://、Android 打包/升级、线程或设备行为 |
| `check_architecture_docs.py` | 文档、链接、ADR、需求/风险 ID、版本 pin、阶段边界 | 静态一致性和无阶段 2 工程文件 | 技术结论正确或运行时通过 |
| `results/*.json` | 实际运行输出 | 可复核版本、时间、逐项状态与限制 | 未执行项目的证据 |

## 可复现命令

从仓库根目录运行：

```bash
python3 docs/architecture/validation/physics_model_probe.py
python3 docs/architecture/validation/sqlite_schema_probe.py
python3 docs/architecture/validation/check_architecture_docs.py
```

退出码 `0` 表示该探针自身全部断言通过，`1` 表示至少一项 `FAIL`。探针使用 Python 标准库，无第三方安装。SQLite 临时文件只写入本目录 `.tmp/`，每个检查结束自动删除；`.tmp/` 已忽略，JSON 结果保留供审查。

可用 `--output <path>` 改结果路径，但默认结果路径为：

- [物理公式结果](results/physics_model_results.json)
- [SQLite 草案结果](results/sqlite_schema_results.json)
- [文档检查结果](results/documentation_check_results.json)

## 状态口径

- `PASS`：本阶段实际执行，探针断言通过，仅限声明范围。
- `FAIL`：实际执行且至少一项断言失败；报告具体错误，不隐藏。
- `BLOCKED`：缺少 Godot/JDK/SDK/设备/被测工程等前提，无法执行。
- `NOT RUN`：并非必然受环境阻塞，但属于后续阶段或本阶段选择不执行。

完整命令、退出码、未执行矩阵见 [阶段 1 验证报告](../13-validation-report.md)。
