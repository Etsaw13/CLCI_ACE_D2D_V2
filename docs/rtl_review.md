# ACE 缓存与 snoop 排序审核

日期：2026-10-22。审核基线：`6c306d613fd095f712caa8df44ccbe82f55569ae`，本批未修改 ACE/CLCI RTL。

本次审核聚焦 CR16、UC→SC 可达性，以及同地址主事务与 snoop 的交叠，不构成完整 ACE 协议或全部 RTL 的签核。以下复现使用本地 Verilator 5.34；实验源码、通道替身、构建和日志均在工程之外。真实 CLCI、VCS 四态行为和目标时序没有在本批重跑。

## 覆盖缺口的结论

`module_a.sv:626` 附近已实现 UC + ReadShared 返回 CR24；UC + ReadOnce 返回 CR16。`module_a.sv:656` 附近已实现 UC + ReadShared 保留并降为 SC。因此这两项未命中不能解释为功能分支缺失。

新定向测试通过 APB 和内部单拍写先建立 UC，排空所有主事务及 ACK，再开放 Home。测试检查实际握手、独立数据期望、缓存及目录状态和覆盖关联，不改 RTL、不 force/deposit，也不降低覆盖判据。普通 smoke 与压力测试继续保持主事务和 Home 并行；定向覆盖成功不能替代并发正确性检查。

## 发现一：旧 snoop 决策覆盖后续 WU 作废

涉及 `ace/module_a.sv:429`、`:613`、`:689`，以及 `ace/module_b.sv:257`、`:277`、`:406`、`:478` 和 Home 状态机。

实际 A/B RTL、APB 内部发生器、独立三拍通道缓冲的临时复现：

| 时间 | 实际观察 |
|---|---|
| 194 ns | A 发出第 3 笔主写，类型 WU，地址与已有 UC 相同 |
| 196 ns | B 根据旧 UC 目录发出 AC.ReadShared |
| 197 ns | 新 WU 的 AW 到达 B，此时 Home 正等待 CR |
| 199 ns | B 发出该 WU 的写响应，尚未收到 snoop CR |
| 203 ns | A 同拍接受 AC 并发出 WACK；AC 按拍前 UC 锁存 CR24，WU 更新把行作废 |
| 205 ns | A 将先前锁存的 snoop 决策提交，把已作废行恢复成有效 SC |
| 206–208 ns | B 收到 WACK 后作废目录，随后收到 CR24，又按旧 snoop 决策把目录恢复为 SC |

收尾时 A 缓存和 B 目录都为有效 SC，数据相等，双方错误状态为零，3 笔写全部完成。问题不表现为最终 A/B 镜像不一致，而是 WU 的作废被旧决策覆盖，现有错误状态未报告该情况。

Arm IHI0022H 的 D6.2 要求同一缓存行的主响应与 snoop 保持一致顺序：若先发 snoop，则须收到对应 CR 后才能给出同地址主事务响应；若先给主响应，则须收到对应 ACK 后再发同地址 snoop。[协议原文](https://developer.arm.com/-/media/Arm%20Developer%20Community/PDF/IHI0022H_amba_axi_protocol_spec.pdf)

本地复现显示 B 在已发 snoop、尚未收到 CR 的窗口给出了同地址写响应。A 又因 `main_busy` 推迟接收 AC，形成跨链路竞争。真实 CLCI 的实际延迟是否触发同一序列，仍须目标采样确认。

修复应同时评审 A 的 snoop 接受与缓存提交，以及 B 的同地址在途事务和响应排序。单给 A 的 ACREADY 增加 `!rack && !wack`，可能使 A 按更新后的状态响应、B 却仍拿旧状态预测 CR。单在 B 等 CR 才回复主事务，也可能与 A 的 `main_busy` 拒绝 AC 形成相互等待。不能把任一单点门控当成已验证修复。

## 发现二：snoop miss 仍覆盖同槽的其他缓存行

`ace/module_a.sv:691` 锁存 `sn_upd_en_l`，但 `:429` 的实际提交只检查 `sn_upd_fire`，没有使用该使能。

临时 A 模块接口测试先用合法 WLU 建立 slot0/tag0/UC，再对地址 `0x40`（tag4，映射到同一槽）发 ReadShared。查找结果为 miss，`sn_upd_en=0`，CR 正确返回 0；提交后原行却变为 `valid=1/state=I/tag4`，tag0 的 UC 副本丢失，A 的错误状态仍为零。

这是已复现的 A 模块接口行为问题。该独立测试直接控制 A 的接口，不属于正式工程的内部发生器测试；当前 B 内部发生器是否会产生这个 miss 场景，没有据此认定。

修复方向是让缓存提交遵守已锁存的更新使能，并在 snoop 无实际更新时允许合法主更新通过；还须检查 miss 响应、同槽不同 tag、有效位与 state 的一致性。此处只记录定位和修复边界，未实施补丁。

## 未作为已确证错误的静态风险

A 缓存和 B 目录均使用全局 `if/else if` 优先级。若主更新与 snoop 更新同时出现，理论上可能遮掉主更新；本批没有证明在当前流控下该同拍组合可达。上述排序复现中，延迟 snoop 提交拍没有同时发生主更新，因此不能用它声称已复现全局优先级丢写。

并发样本被覆盖观察器记为 `conflict` 仍然合理，不能将其直接改算 UC→SC 命中。更改覆盖统计无法修复缓存/目录排序。
