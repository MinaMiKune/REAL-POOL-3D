# ADR-004：UDP 发现、ENet 会话与 LAN 主机权威

- 日期：2026-11-11
- 状态：Accepted；Godot 双进程和 Android 双设备验证 `BLOCKED`

## 背景

项目只需 LAN 双人，客户端不得裁决得分、犯规或胜负，还需发现、版本、重连、超时和输入验证。Android API 37 增加本地网络运行时权限。

## 决策

使用 `PacketPeerUDP` IPv4 广播发现，`ENetMultiplayerPeer` 建立一主一客 UDP 会话。可靠有序 channel 传命令/规则/最终状态，unreliable ordered channel 传可丢弃表现快照。通过 `SceneMultiplayer.send_bytes/peer_packet` 传固定二进制 envelope，`allow_object_decoding=false`。身份以 remote sender ID 为准；主机完成所有验证、物理、规则和提交。不支持主机迁移，广播失败可 directed IP join。

## 备选方案

1. **TCP 自研**：可靠但发现仍需 UDP，队头阻塞和重连/消息帧需自研，拒绝。
2. **纯 UDP 自研可靠性**：可定制但重复实现重传/排序/拥塞，风险高，拒绝。
3. **Godot 高层 RPC/Variant 自动同步**：接入快，但公共线协议不稳定、对象解码和状态所有权容易模糊，不用于核心数据面。
4. **WebSocket/HTTP**：不适合轻量 LAN 发现和表现快照，仍需要服务器模型，拒绝。
5. **mDNS/NSD**：发现体验好但需原生桥接；可在广播实测失败后另评，首版不引入。
6. **客户端锁步/P2P 双方裁决**：跨端浮点和作弊/分歧复杂，违背主机权威约束，拒绝。

## 理由

Godot 官方提供所需 API，ENet 自带 UDP 可靠/channel 能力；原始字节 envelope 能显式限制长度、类型和版本。主机复用单机 MatchController，避免跨端锁步，并将规则攻击面集中到一个验证入口。

## 代价

- 需要实现 codec、限流、幂等、重连、版本协商和故障注入。
- UDP 广播受 AP 隔离和 Android 权限影响；ENet 不提供本设计的应用授权/完整安全。
- 无主机迁移，主机退出会结束房间；LAN 首版不承诺加密、互联网或反主机作弊。

## 风险与降级

Android 权限拒绝则保留单机，不能绕过；广播失败 directed join；客户端分歧请求主机全量快照；主机退出只用最近完整 shot 边界经双方确认开新房间恢复。大包/flood 采用限长、限速和断开，不继续分配内存。

## 验证方法

双进程测试 hello/version/echo、通道、重复/乱序/丢包、伪造 seat、NaN/超长包、shot 幂等和 resume hash。双 Android 设备测试权限允许/拒绝/撤销、广播/单播、Wi-Fi 切换、后台和主机退出。记录实际 Godot 版本、OS、网络、日志与消息序列。
