# 模块与顶层设计

## 源版本与范围

ACE 来自 `Etsaw13/ace-full-project` 提交 `6c306d613fd095f712caa8df44ccbe82f55569ae` 的四个 RTL 文件；CLCI 来自开发服务器原来已跑通的 `CLCI_ACE_D2D`。所有收录源码与其来源的 SHA-256 一致。不会混入新版 ACE 仓库中的另一套 CLCI、外部订单 UVM、简化链路或历史结果。

新 ACE 支持 APB 配置、SW/SR/BW/BR 四种发生器类型、可配置 burst 和 PRBS31/23/10 等六种数据模式。B 的数据存储为四槽带 tag 的有限存储。设计不是通用 ACE VIP，也不是完整缓存一致性系统的替代验证。

## 连接与时序

```text
APB 控制 -> module_a (u_master) <-> die0 ACE slave
                                     || 真实 CLCI 主带/边带 ||
APB 控制 -> module_b (u_slave)  <-> die1 ACE master
              └ Home snoop 与主读写持续并行
```

`dv/tb_top.sv` 保留原工程的 Die 配置、双向主带/边带连接和复位顺序。芯片 `pclk/soc_i_pclk` 保持 200 MHz，ref_clk 保持 25 MHz，axi_5_clk 保持 1 GHz。ACE 与其自带 APB 改为同一个 1 GHz 时钟，使用相同复位。

mcu_trst_n 初始为 0，50 ns 后拉高，再过 100 ns 释放其他复位。保留 strapping_mode=0001 及原 chipid/MCU 等绑定位。die0 未使用 ACE master 的 AWREADY/WREADY/ARREADY/CRREADY/CDREADY 改绑 1。

A 的外部订单接口保持不活动，cfg_ord_ext=0；正常订单全部由 ACE 自带发生器产生。TB 通过 APB 配置和使能，不直接喂订单，不修改或强制 ACE 内部状态。

## APB 寄存器

地址均为各自模块内的偏移，32 位访问。

| A 地址 | 名称 | 内容 |
|---|---|---|
| 000 | CONTROL | bit0 enable，bit1 清错/清计数脉冲；读回只有 enable |
| 004 | DATA_CFG | [7:0] PRBS code，[10:8] mode，[23:16] XCODE，[27:24] TEST_TYPE |
| 008 / 00C | BASE_LO / HI | 44 位起始地址，高寄存器保留低 12 位 |
| 010 | STATUS | 错误状态 |
| 014 / 018 | CNT_TX / SNOOP | 已完成主事务 / snoop 计数 |
| 01C | WAIT_COUNT | 等待计数 |
| 020 | BURST_CFG | 低 8 位为 AXI LEN，拍数=LEN+1 |

| B 地址 | 名称 | 内容 |
|---|---|---|
| 000 | CONTROL | Home enable / 清错脉冲，主数据响应不靠此位开启 |
| 004 | DATA_CFG | code/mode/XCODE，与 A 保持一致 |
| 008 | SNOOP_CFG | [7:0] gap，[11:8] 现有错误注入位 |
| 010 | STATUS | 错误状态 |
| 014 / 018 / 01C | CNT_WR / RD / SNOOP | 写 / 读 / snoop 计数 |
| 020 | WAIT_COUNT | 等待计数 |

PREADY 当前固定为 1，驱动仍执行 SETUP/ACCESS 并检查超时和 PSLVERR。未定义地址在 ACCESS 报错；已定义只读寄存器写入被忽略，不报错。清错会清 A 的 TX/snoop 和 B 的 WR/RD，但 B 的 snoop 计数仅复位清零。UVM 错误测试分段对账，不能假定所有计数同步清零。

当前 DV APB 测试检查复位值、配置/只读写读、两侧未定义地址及清除脉冲读回；不把零计数时的清除测试称作非零计数清除验证。后者由 UVM 错误/恢复测试实现。

## 启动、并行运行与收尾

1. 同时满足两侧 RX=11、command-ready=1、TX-ready=1，连续八个 ACE 周期。
2. APB 配置并读回两侧数据模式、种子、A 地址/burst、B gap。
3. 先使能 Home，随后使能 A；流量阶段始终并行。
4. AW/AR 实际接受请求达到 TX_TARGET 后通过 APB 停止 A；所有已接受工作仍继续监视。
5. Home 继续运行，直到模型队列、数据、ACK、四个控制状态机及目录待处理项闭合，连续静默 16 拍。
6. 关闭 Home，再观察 32 拍；通过 APB 核对最终错误及计数，然后生成报告。

TX_TARGET 为最小请求数，实际完成数可能更多。请求数是 AW/AR 事务数，W/R 是数据拍数。RS 补读也算一笔实际请求。链路、数据、协议和内部错误在正常测试中均不允许发生。

最大 burst 不放进无限轮转的混合场景；boundary 每次只要求首笔请求，分别运行方向/长度，始终检查实际地址是否跨 4 KB。APB 停发若出现额外请求，也必须完整核对；实际跨界仍失败。

## 检查组件

- `ace_dv_model_pkg.sv`：独立事务发生器模型、六种数据公式和 CR 判定，不调用 DUT 数据函数，不读取私有发生器状态决定下一笔。
- `ace_dv_checker_pkg.sv`：十通道双端 FIFO 比较；地址/属性/顺序；W/R 数据、STRB、LAST、响应及 ACK；AC/CR/CD 义务。R 使用独立四槽带 tag 模型，反映已送达 W/CD，而非无限内存。
- `ace_dv_cache_cov_pkg.sv`：被动关联六项缓存行为，使用握手及缓存前后快照；冲突和证据不足单列，不虚报命中。CR 的期望基于 AC 接受时的实际缓存快照；这不是全程独立缓存一致性证明。
- `observe.svh`：正沿保存 NBA 之前的握手，1 ps 后观察缓存更新；不参与驱动。
- `ace_dv_runtime_cov_pkg.sv`：两个 ACE 实例的 VCS 原生覆盖查询，保留已验证的字面量路径/常量参数形式，避免旧版 API 的 string 类型错误。

最终要求 AW=B=WACK=写事务数，AR=RACK=读事务数，W/R 拍数分别等于所有 LEN+1，AC=CR，CD=DataTransfer 义务。各通道 source=destination=matched，队列为空。纯 burst 可不产生 snoop；smoke 必须四类主事务及 AC/CD 非零。

## 限制与后续

ACE 内部超时仍为原 RTL 的 256 周期，1 GHz 下为 256 ns，脚本扩大等待时间不会改变它。发现真实链路超时或数据矛盾要定位，不能通过串行化主事务/snoop、关闭数据比较或修改 RTL 来使之通过。

同地址跨不同 burst 拍位置的重读已有独立 UVM 诊断入口，已在本地真实 ACE 上复现数据自检矛盾，见 KNOWN_ISSUES.md。DV 和 UVM 的普通存储比较都不绕过这一问题。两套环境现各自提供 `sim/merge_code_coverage.sh`，读取兼容 VDB 做代码点并集并生成基本块源码视图；格式边界和 s206 待验证状态见 [代码覆盖率说明](code_coverage.md)。当前运行不依赖 URG/Verdi。
