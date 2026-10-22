# 功能覆盖率说明

本文说明 `ace_v2_44` 覆盖计划中四个 group、九个覆盖点及全部 44 个命名 bin，适用于本工程的 DV 和 UVM 环境。报告中的英文名称、bin 顺序及编号保持与两套环境的 `sim/coverage_plan.json` 一致。

这些覆盖项依据当前 ACE 内部发生器、Home 出题逻辑、响应逻辑和选定的缓存行为设置。它们反映本设计已选功能的执行情况，不等同于完整标准 ACE 协议覆盖，也不构成全部缓存状态转移的证明。

## 1. 报告如何阅读

| Group | 覆盖点 | Metric 编号 | Bin 数 | 主要观察对象 |
|---|---|---:|---:|---|
| Basic | Transaction class | 0 | 4 | 主请求的读写方向和实际 LEN |
| Basic | ACE attribute | 1 | 5 | 主请求的 AWSNOOP / ARSNOOP 类型 |
| Basic | Request start line | 2 | 4 | 相对 BASE 的 AW / AR 起始地址 |
| Basic | Burst length | 3 | 7 | 多拍主请求的实际拍数 |
| Coherence | Snoop type | 4 | 4 | A 接受的 AC 质询类型 |
| Coherence | CR response | 5 | 5 | A 发出的 CRRESP 标志组合 |
| Coherence | R tag | 6 | 3 | B 发出的每拍 RRESP 标签 |
| Data | Data mode | 7 | 6 | 有效主请求使用的数据模式 |
| Cache | Cache behavior | 8 | 6 | 关联事务、缓存状态及数据证据 |
| 合计 | 四组、九点 | — | 44 | — |

- **Group**：相关覆盖点的分类。Basic 共 20 个 bin，Coherence 共 12 个，Data 和 Cache 各 6 个。
- **Hit/Plan**：至少命中过一次的 bin 数 / 本覆盖点的计划 bin 总数。
- **Coverage**：`已命中 bin 数 ÷ 计划 bin 数 × 100%`。单个 bin 命中一次与多次，对该百分比的贡献相同。
- **NOT COVERED**：当前运行或所选运行并集中，命中次数仍为零的 bin。
- **hits**：原始明细中的采样次数。不同覆盖点的采样事件不同，不能把所有 hits 相加当成事务数。

例如 `Burst length 1/7` 表示七个长度 bin 中命中一个；`Data mode 6/6` 表示六种模式均有实际主请求使用。

请求类覆盖点在源端 AW/AR 的 `VALID && READY` 握手后记录；其他覆盖点按下文所述的 AC、CR、R 或缓存关联事件记录。覆盖命中与正确性检查分别承担不同任务。完整成功结果还要求整轮仿真 PASS、所有实际事务完成、双端数据匹配、ACK/CD 义务和队列排空；中途保存的 PARTIAL 报告不能当成完整验证结果。

## 2. Basic：基本主请求

### 2.1 Transaction class：主事务类别（Metric 0，4 个 bin）

本设计数据宽度为 128 bit，每拍 16 B，`AxSIZE=4`。实际拍数为 `AxLEN+1`。事务类别根据线上实际 LEN 判断，而不是仅按测试名称判断。

| Bin 编号 | Bin | 含义与命中条件 |
|---:|---|---|
| 0 | SW | Single Write：一次 AW 握手，`AWLEN=0`，即单拍写 |
| 1 | SR | Single Read：一次 AR 握手，`ARLEN=0`，即单拍读；发生器的单拍补读也属于此类 |
| 2 | BW | Burst Write：一次 AW 握手，`AWLEN>0`，即多拍写 |
| 3 | BR | Burst Read：一次 AR 握手，`ARLEN>0`，即多拍读 |

一笔四拍写只增加一次 BW 命中；它在 W 通道传输四拍，不会因此产生四笔主请求。

### 2.2 ACE attribute：主请求一致性类型（Metric 1，5 个 bin）

报告保留名称 `ACE attribute`，实际统计的是当前发生器支持的 AWSNOOP / ARSNOOP 主请求类型。它不包括 AWCACHE、ARCACHE、DOMAIN、BAR、PROT 等所有接口属性。

| Bin 编号 | Bin | 全称 | 当前设计中的含义 |
|---:|---|---|---|
| 0 | WU | WriteUnique | A 发出的 WU 写；完成确认后，本地对应行无效 |
| 1 | WLU | WriteLineUnique | A 发出的 WLU 单拍写；当前实现将数据写入 B，并在 A 保留 UC 行和数据快照 |
| 2 | RS | ReadShared | A 发出的 RS 主读，包括同地址补读；完成后的状态取决于 RRESP.IsShared |
| 3 | RU | ReadUnique | A 发出的 RU 主读；当前 B 固定返回 PassDirty，A 完成后形成 UD |
| 4 | RO | ReadOnce | A 发出的 RO 主读；当前实现不为这类读分配缓存，burst 读使用此类型 |

单拍写模式通过内部 `wr_pat` 在 WU/WLU 间交替；burst 写固定为 WU。单拍读按 RS/RU/RS/RO 轮转，部分 RS 会增加同地址补读；burst 读固定为 RO。

混合模式中，单拍写和 burst 写都会翻转 `wr_pat`，而 burst 写固定使用 WU。因此，从复位开始运行的当前混合序列不会生成 WLU。这个特性不代表 RTL 缺少 WLU 实现。现有 UVM 单拍写入口选择独立单拍写模式，并要求实际观察到 WLU。

这五项是当前内部主请求的实现集合。标准 ACE 还定义其他主请求类型；不能把本点达到 100% 解读为全部标准请求均已验证。

### 2.3 Request start line：相对请求起始行（Metric 2，4 个 bin）

`BASE` 是本次通过 APB 配置的起始字节地址。该点只采样 AW/AR 请求的起始地址。

| Bin 编号 | Bin | 请求起始地址 |
|---:|---|---|
| 0 | L0 | `BASE + 0` B |
| 1 | L1 | `BASE + 16` B |
| 2 | L2 | `BASE + 32` B |
| 3 | L3 | `BASE + 48` B |

L0～L3 是相对 BASE 的位置，不是绝对缓存槽编号。实际缓存槽由绝对行地址的低两位决定。改变 BASE 后，L0 不一定对应物理槽 0。

burst 的后续数据拍会继续推进地址，但不会为这个覆盖点增加额外起始行命中。一拍等于本设计的一条 16 B 行；多拍 burst 可以跨多条行。

### 2.4 Burst length：多拍请求长度（Metric 3，7 个 bin）

仅在 `AxLEN>0` 时采样实际拍数 `N=AxLEN+1`。单拍请求由 SW/SR 表达，因此该点没有长度为 1 的 bin。

| Bin 编号 | Bin | 命中条件 | 对应传输字节数 |
|---:|---|---|---|
| 0 | 2 | 恰好 2 拍 | 32 B |
| 1 | 3 | 恰好 3 拍 | 48 B |
| 2 | 4 | 恰好 4 拍 | 64 B |
| 3 | 5..15 | 5～15 拍中的任意一种 | 80～240 B |
| 4 | 16..254 | 16～254 拍中的任意一种 | 256～4064 B |
| 5 | 255 | 恰好 255 拍 | 4080 B |
| 6 | 256 | 恰好 256 拍 | 4096 B |

`5..15` 和 `16..254` 各自是一个范围 bin。一次 8 拍传输会命中 `5..15`，不表示该范围的每个长度都已执行。读写共用这些长度 bin，本点没有独立统计“长度 × 读写方向”的交叉覆盖。

命中长度 bin 不替代逐拍数据、STRB/LAST、响应、ACK 和 4 KB 边界检查。256 拍传输为 4 KB，需要满足实际起始地址的边界要求。

## 3. Coherence：一致性接口行为

### 3.1 Snoop type：Home 质询类型（Metric 4，4 个 bin）

该点在 AC 请求到达 A、完成握手后采样。

| Bin 编号 | Bin | 全称 | 当前设计中的作用 |
|---:|---|---|---|
| 0 | RS | ReadShared | 对 UC 行进行共享降级；SC 行可继续保留共享副本 |
| 1 | MI | MakeInvalid | 对选中的干净有效行进行作废 |
| 2 | CI | CleanInvalid | 对行进行清理/作废；本设计对 UD 行固定选择此类型，并要求 CD 返回 |
| 3 | RO | ReadOnce | 按当前 A 的状态决定 CR；SC 行保留，UC 行作废 |

当前 B Home 对 UD 行固定发 CI；对其他有效目录行，根据 `h_rot` 轮转 RS/MI/CI/RO。每次 CR 完成都会推进轮转，包括对 UD 发出的 CI。

Home 只有在目录有效、没有待完成的主请求、相关握手不冲突且间隔计数归零时，才有资格发出质询。因此，AC 数量达到四次并不必然命中四种类型。

主请求里的 RS/RO 在 AR 通道，质询里的 RS/RO 在 AC 通道，两处覆盖分别统计。本点也不是标准 snoop 类型全集：例如 A 的响应表处理 RU，但当前 B Home 不主动发 RU，所以未将 RU 作为内部 Home 的计划 bin。

### 3.2 CR response：质询响应标志组合（Metric 5，5 个 bin）

在 A 发出的 CR 完成源端握手、且响应与独立预测匹配后采样。CRRESP 是标志位组合：

| 位 | 标志 | 含义 |
|---:|---|---|
| 4 | WasUnique | 质询前为独占状态 |
| 3 | IsShared | 响应方仍保留共享副本 |
| 2 | PassDirty | 转移脏数据回写责任 |
| 1 | Error | 数据错误标志 |
| 0 | DataTransfer | 本次响应要求后续 CD 数据 |

当前 A 的正常响应生成逻辑只输出下列五个数值，故设置五个精确值 bin：

| Bin 编号 | 报告名称 | CRRESP 十进制/二进制 | 置位标志及当前内部闭环条件 |
|---:|---|---|---|
| 0 | none(0) | `0 / 00000` | 所有标志为零；例如 SC/UC 遇到 MI/CI。A 对无效行也返回 0，但正常 Home 只对有效目录发题 |
| 1 | shared(8) | `8 / 01000` | IsShared；SC 行接受 RS 或 RO |
| 2 | unique(16) | `16 / 10000` | WasUnique；UC 行接受 RO。A 也处理 UC+RU，但当前 Home 不主动发 RU |
| 3 | unique_shared(24) | `24 / 11000` | WasUnique + IsShared；UC 行接受 RS，行降为 SC |
| 4 | dirty_data(21) | `21 / 10101` | WasUnique + PassDirty + DataTransfer；正常内部 Home 对 UD 发 CI，并建立 CD 返回义务 |

`none(0)` 是真实 CR 响应，不表示未响应。`unique(16)`、`unique_shared(24)` 是报告简称，应按置位标志解释；尤其 WasUnique 描述质询前的状态。

当前 A 不主动置 CRRESP.Error。五个 bin 覆盖了本实现的正常输出数值，但没有单独覆盖每个“初始状态 × 质询类型”组合，也不代表标准 ACE 所有允许的响应组合。

### 3.3 R tag：主读数据响应标签（Metric 6，3 个 bin）

该点在 B 发出的每拍 R 完成源端握手、通过数据/ID/LAST/响应检查后采样，和 CR 响应覆盖相互独立。

| Bin 编号 | Bin | 当前 RRESP | 当前 RTL 条件 |
|---:|---|---|---|
| 0 | plain | `0 / 0000` | RO；或 RS 对该拍地址没有有效目录命中 |
| 1 | PassDirty | `4 / 0100` | RU 固定置 PassDirty |
| 2 | IsShared | `8 / 1000` | RS 且该拍地址命中目录 |

当前 B 的 RRESP 低两位固定为 OKAY，PassDirty 与 IsShared 在此实现中互斥。三个 bin 是当前正常读响应的标签集合，不统计所有标准 RRESP 组合及错误响应。多拍读可以贡献多次 R tag 命中。

## 4. Data：数据模式（Metric 7，6 个 bin）

每次有效主请求握手时记录该请求使用的数据模式。只写 APB 配置、没有主请求时，不会命中数据模式 bin。模式正确性另由独立模型逐拍检查。

| Bin 编号/模式值 | Bin | 含义 |
|---:|---|---|
| 0 | PRBS31 | 使用 PRBS31 码型；数据由行地址、拍号和 PRBS_CODE 确定 |
| 1 | fixed_byte | 将 XCODE 指定的一个字节重复铺满 128 bit 数据拍 |
| 2 | sequence | 四个重复的 32 bit 字段，每字段包含行地址与拍号信息 |
| 3 | walking_one | 一位为 1，其余为 0；位置由行地址低位与拍号决定 |
| 4 | PRBS23 | 使用 PRBS23 码型，种子取地址/拍号/PRBS_CODE 混合值的相应低位 |
| 5 | PRBS10 | 使用 PRBS10 码型，种子取地址/拍号/PRBS_CODE 混合值的相应低位 |

`6/6` 表示六种模式均有实际主请求使用，不表示所有 PRBS_CODE、XCODE、地址、拍位置或数据位组合都已遍历。例如，固定字节模式只运行一次 XCODE=0x5A，就可以命中该模式 bin。

命令位置参数 seed 传给仿真器，与 APB 的 PRBS_CODE 不同。当前 ACE 主请求发生器按固定逻辑推进，改变仿真 seed 不会主动改变其事务类别、地址或属性轮转。

## 5. Cache：关键缓存行为（Metric 8，6 个 bin）

本设计 A 侧缓存有四行，行大小 16 B，状态为 I（无效）、SC（共享干净）、UC（独占干净）、UD（独占脏）。下列六项是选定的实现行为，主要观察 A 缓存，并关联主事务和两端 CR/CD 传输证据。

| Bin 编号 | Bin | 命中条件与所证明的行为 |
|---:|---|---|
| 0 | WU_invalid | 关联到 WU 的 AW、W、B 和 WACK，确认完成后对应行 valid=0。此 bin 不要求事务前该行有效，因此只证明完成后的无效状态 |
| 1 | WLU_UC | 关联到 WLU 写及其完成确认，确认对应 tag 有效、状态为 UC，并保留正确的写数据快照 |
| 2 | RU_PD_UD | 关联到 RU 主读、RRESP.PassDirty、读数据及 RACK，确认对应 tag、数据和最终 UD 状态正确 |
| 3 | RS_IS_SC | 关联到 RS 主读、RRESP.IsShared、读数据及 RACK，确认对应 tag、数据和最终 SC 状态正确 |
| 4 | UC_RS_SC | AC 握手前确认目标行是 UC，接受 RS snoop，观察匹配的 CR24、向 B 的 CR 交付和正确的 SC 状态更新/数据保持 |
| 5 | UD_CI_CD_invalid | AC 握手前确认目标行是 UD，接受 CI，观察 CR21、正确的源端 CD 快照/数据/LAST、CD 到达 B，以及 A 行无效的状态证据 |

其中两种 RS 的区别是：`RS_IS_SC` 观察 AR 主读填充；`UC_RS_SC` 观察 AC 质询造成的降级。

UC 可由 WLU 完成建立，也可由 RS 主读没有收到 IsShared 时建立。因此，没有 WLU 命中不代表整个运行中从未出现过 UC。

UD 行的失效更新发生在 CR 握手后的更新阶段，可能早于 CD 到达 B；`UD_CI_CD_invalid` 等到所需 CD 数据交付完成、相关证据闭合才计为命中，不能把这一统计时点解释为 RTL 等 CD 交付后才作废。

缓存明细中的诊断字段含义如下：

| 字段 | 含义 |
|---|---|
| attempted | 观察到了该行为的候选事务或初始状态条件 |
| matched | 关联证据满足定义，实际计入对应 bin 的命中次数 |
| conflict | 更新或采样冲突导致无法可靠归属，未计入命中 |
| unmatched | 未形成完整命中证据的候选；PARTIAL 报告中也可包含尚未闭合的候选 |

六项没有穷举全部初始状态和状态变化。例如，RS 不带 IsShared 时形成 UC、SC 遭 MI/CI 作废、RO 不分配缓存，没有各自独立的缓存行为 bin。即使六项全部命中，也应理解为这六个选定目标得到观察证据。

## 6. 多次运行的统计边界

同一环境的普通 PASS 运行，只有 ACE/CLCI 源码、验证模型及覆盖计划一致时，才可以使用其报告脚本合并。合并按每个 bin 的命中并集计算：任何一次命中过就算已覆盖，重复运行相同配置不会重复增加已覆盖 bin 数。

DV 和 UVM 的 bin 定义相同，但现有报告器按各自格式和环境校验值处理，不能直接把两套运行目录混入同一个环境的合并命令。错误注入和独立诊断结果与普通通过覆盖分开报告。

功能覆盖原始明细为每轮输出目录中的 `functional_coverage.txt`；汇总表与未覆盖项位于 `coverage_summary.log` 或用户指定的合并报告。命令参数和输出路径见 [DV 使用说明](user_guide.md) 与 [UVM 使用说明](uvm_user_guide.md)。

本文描述功能覆盖。代码覆盖的 line、condition、toggle、FSM 等由 VCS 原生采集，统计维度与这 44 个命名功能 bin 不同。

## 7. 定义依据

- 计划名称及 bin 顺序：[DV 覆盖计划](../dv/sim/coverage_plan.json)、[UVM 覆盖计划](../uvm/sim/coverage_plan.json)。
- 主请求和一致性采样：[DV 检查器](../dv/ace_dv_checker_pkg.sv)、[UVM 检查器](../uvm/ace_uvm_checker_pkg.sv)。
- 缓存行为证据：[DV 缓存观察器](../dv/ace_dv_cache_cov_pkg.sv)、[UVM 缓存观察器](../uvm/ace_uvm_cache_cov_pkg.sv)。
- 当前实现：[A 模块](../ace/module_a.sv)、[B 模块](../ace/module_b.sv)、[参数与编码](../ace/ace_pkg.sv)、[数据码型](../ace/ace_funcs.svh)。
- 范围及通过条件：[已确认测试方案](test_plan.md)。
- 标准术语对照：[Arm AMBA AXI and ACE Protocol Specification，IHI 0022H.c](https://documentation-service.arm.com/static/602a9df190ee6824a1e02b98)，D3.1、D3.6、D3.7。本工程覆盖分母由当前实现和本计划定义。
