# 模块接口与契约

本文中的签名是架构契约，不是已创建的 GDScript。具体类型名可在阶段 2 适配语言特性，但所有权、单位和语义不得悄悄改变。

## 1. 通用约定

- 时间：物理使用整数 `tick` 与秒制固定 `dt`；日志同时使用 UTC  wall time 和单调时钟，禁止用 wall clock 驱动物理。
- 几何：权威平面为 `(x, y)`，单位米；映射到 Godot 世界坐标 `(x, cloth_height, y)`。角速度 `(wx, wy, wz)` 使用映射后的右手世界轴，单位 rad/s，其中 `wy` 是竖直轴；权威平面自身的 `y` 不表示高度。角度输入为弧度。
- ID：`match_id`、`shot_id`、`session_id` 是 128 bit 随机值的规范小写十六进制；球 ID 固定为 0–15，球袋 ID 固定为 0–5。
- 值对象：跨边界只传深拷贝或不可变约定对象，禁止共享可变 Dictionary 后被后台修改。
- 错误：返回结构化 `ErrorInfo(code, message, details)`；用户文本与机器码分离，不用异常文本做协议判断。
- 哈希：SHA-256 仅用于完整性/分歧检测，不用于防作弊签名；哈希输入为明确版本的规范二进制。

## 2. 核心 DTO

| DTO | 必填字段 | 约束/所有者 |
|---|---|---|
| `BallState` | `ball_id, pos_x, pos_y, vel_x, vel_y, omega_x, omega_y, omega_z, motion_mode, disposition, sleep_ticks` | 物理拥有；表现不得直接写 |
| `PhysicsConfig` | `config_version, tick_hz, radius, mass, friction/restitution thresholds, pocket geometry` | 只读配置；哈希进入比赛和回放 |
| `ShotCommand` | `match_id, shot_id, expected_turn, seat, aim_angle, power, cue_offset_x/y, called_ball, called_pocket, safety, client_nonce` | 人类、AI、客户端共用；主机规范化 |
| `PlacementCommand` | `match_id, expected_turn, seat, pos_x, pos_y` | 仅手中球阶段；碰撞/区域验证 |
| `PhysicsEvent` | `tick, sub_tick, type, ball_ids, cushion_or_pocket_id, contact, impulse, sequence` | 物理只追加；顺序即规则输入 |
| `ShotResult` | `initial_tick, final_tick, events, final_balls, state_hash, termination` | `termination` 区分静止/不收敛/中止 |
| `MatchState` | `rules_version, phase, rack, turn, shooter, groups, ball_status, cue_in_hand, breaker, winner, foul_streak metadata` | 仅 reducer 产生新实例 |
| `RuleDecision` | `next_state, fouls, assignments, continuation, options, winner, reason_codes` | UI 只显示，不复制判断 |
| `AiContext` | `public_match_state, legal_targets, table_geometry, physics_params, difficulty, seed_stream` | 不含引擎内部随机队列 |
| `VersionSet` | `app, engine, physics, rules, protocol, schema, replay` | 握手、存储和回放共用 |

`called_ball/called_pocket` 使用显式空值表示 safety 或开球；禁止使用魔法数字 `-1` 穿透到领域层。线缆格式可将空值编码为 tagged union，解码后恢复类型。

## 3. 物理接口

```text
PhysicsWorld.create(initial_balls, PhysicsConfig) -> PhysicsWorld
PhysicsWorld.apply_shot(canonical_shot) -> ErrorInfo?
PhysicsWorld.step_one_tick() -> PhysicsEvent[]          # 只推进 1/tick_hz
PhysicsWorld.run_until_rest(max_ticks) -> ShotResult
PhysicsWorld.snapshot() -> BallState[]
PhysicsWorld.restore(verified_snapshot) -> ErrorInfo?
PhysicsWorld.state_hash() -> SHA-256
PhysicsPredictor.evaluate(cloned_state, canonical_shot) -> ShotResult
```

- 实时比赛由 `MatchController` 按每帧 tick 预算调用 `step_one_tick()`；它不读取渲染 delta、系统时间或全局 RNG，帧预算只决定本帧工作量，不丢弃权威 tick。
- `run_until_rest()` 只用于 headless 测试或带取消/预算的 AI worker，不得在主线程长时间阻塞；它只在完整 tick 边界结束，`max_ticks` 或取消触发 `NON_CONVERGENCE`/`ABORTED`，均不是合法静止。
- 物理只报告“首碰、碰库、落袋、飞出、静止”等可测事实；不报告犯规或胜负。
- AI 的 `PhysicsPredictor` 必须克隆输入，不得修改当前权威世界；候选评估与正式世界使用相同版本。

## 4. 规则接口

```text
RulesReducer.validate_command(MatchState, ShotCommand) -> ErrorInfo?
RulesReducer.reduce(MatchState, ShotCommand, ShotResult) -> RuleDecision
RulesReducer.apply_choice(MatchState, BreakChoice) -> RuleDecision
RulesReducer.validate_placement(MatchState, PlacementCommand, BallState[]) -> ErrorInfo?
RulesReducer.legal_targets(MatchState) -> BallTarget[]
```

`reduce()` 无 I/O、无定时器、无动画、无全局状态；相同输入必须返回相同值。它必须检查 `ShotResult.termination=AT_REST`，否则返回技术错误而非规则结果。事件顺序和首碰/碰库去重规则见物理文档。

规则阶段：`RACK_SETUP → BREAK_PLACEMENT/AWAIT_BREAK → SIMULATING → (AWAIT_BREAK_CHOICE | AWAIT_SHOT | BALL_IN_HAND | RACK_OVER)`。`MATCH_OVER`、`SUSPENDED`、`TECHNICAL_ERROR` 为独立终态/控制态。选择、放置和击球各有单独命令，不能由 UI 直接改 `phase`。

## 5. AI 接口

```text
AiPlanner.choose_shot(AiContext) -> ShotCommand
AiPlanner.rank_candidates(AiContext) -> CandidateEvaluation[]
AiPlanner.choose_placement(AiContext) -> PlacementCommand
```

`CandidateEvaluation` 至少包含合法目标、叫袋、名义瞄准/力度、几何评分、候选走位摘要和风险；供测试解释五档差异。AI 只输出与人相同的命令，最终扰动成为命令的一部分并写入回放。不得调用 `PhysicsWorld.apply_shot()` 或直接改变 `MatchState`。

## 6. 存储接口

```text
MatchRepository.open(path, expected_schema) -> ErrorInfo?
MatchRepository.migrate_with_backup() -> MigrationReport
MatchRepository.commit_shot(ShotCommit) -> ErrorInfo?    # 原子事务
MatchRepository.load_match(match_id) -> MatchSnapshot
MatchRepository.list_replays(filter, limit, cursor) -> ReplayIndexEntry[]
MatchRepository.backup(destination) -> BackupReport
MatchRepository.check_integrity() -> IntegrityReport
MatchRepository.close() -> ErrorInfo?
```

`ShotCommit` 同时携带 match 更新、shot、事件、回放块和校验。领域层不知道 SQL；所有值使用参数绑定。单写者队列串行执行，读取不可看见半次提交。数据库异常返回错误，不自动切换到 JSON 或内存“假成功”。

## 7. 网络接口

```text
LanDiscovery.start_host(advertisement) / start_client() / stop()
LanTransport.host(config) / join(endpoint, auth) / close()
LanTransport.send_control(peer, Envelope) -> ErrorInfo?
LanTransport.send_snapshot(peer, Snapshot) -> void
LanSessionController.submit_intent(ShotCommand) -> request status
HostSession.authorize(sender_peer, Envelope) -> CanonicalCommand / Rejection
HostSession.build_resume(peer, ResumeRequest) -> ResumeBundle
```

发送方身份以 `multiplayer.get_remote_sender_id()` 为准，payload 中的 seat/peer 字段只能交叉检查，不能授权。RPC 仅限固定节点和固定方法；更推荐通过 `SceneMultiplayer.peer_packet`/`send_bytes()` 传严格限长的二进制 envelope，避免通用 RPC 面。

## 8. 表现、输入与平台接口

```text
Presentation.apply_snapshot(previous, current, interpolation_alpha)
Presentation.consume_events(authoritative_event_batch)
InputRouter.emit_preview(AimPreview)                     # 不触球
InputRouter.emit_command(ShotCommand | PlacementCommand)
ResponsiveLayout.rebuild(viewport_size, safe_area, orientation)
PlatformService.query_capabilities() -> CapabilitySnapshot
PlatformService.request_local_network() -> async PermissionResult
LifecycleService.pause(reason) / resume(reason)
```

- 预览不是权威命令；击球需明确确认。
- UI 控件先消费触控，未处理的桌面手势才进入 `_unhandled_input`。
- 权限结果必须异步处理；禁止在授权前启动 UDP/ENet。
- 音效/动画事件只影响表现，不回写物理和规则。

## 9. 事件顺序与幂等

每球每 shot 的 `FIRST_OBJECT_CONTACT` 只保留首个；`RAIL_CONTACT` 按 `(ball_id, cushion_id)` 记录是否发生，同时保留原始事件供音效；`BALL_POCKETED` 每球最多一次；`SHOT_AT_REST` 必须最后。`sequence` 严格递增，存储和网络以 `(match_id, shot_id, sequence)` 去重。

重放同一 `shot_id` 的命令返回先前接受/提交结果，不再次推进世界。不同 `shot_id` 但 `expected_turn` 过期则拒绝。数据库唯一键 `(match_id, ordinal)` 是最后一道幂等保护。
