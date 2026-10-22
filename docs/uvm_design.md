# UVM 文件与测试原理

## 环境中的激励来自哪里

UVM 的主动控制只在两个 ACE 模块各自的 APB 端口上。读写订单、数据、响应及 snoop 由真实 module_a/module_b 产生，经过双 Die 的真实 CLCI 连接。cfg_ord_ext=0，外部订单信号绑不活动。没有直接驱动 ACE 的 master/slave VIP，也不强制 RTL 内部状态。

```text
UVM test -> control_sequence -> APB sequencer -> APB driver -> ACE 配置寄存器
                                             APB monitor -> scoreboard 配置模型

ACE 内部发生器 <-> 两颗真实 CLCI <-> ACE slave / Home
        两端 monitor -> scoreboard 独立模型、载荷队列、数据及义务检查
                                     -> 44 个命名功能 bin / 缓存证据
结束 -> 原生代码覆盖采样 -> 原始文件 -> Python 汇总表及未覆盖项
```

UVM run_test 在仿真零时刻调用。test 的 run_phase 立即提出 objection，运行序列等待两侧 RX、command、TX ready 连续八拍，再配置 APB。硬件训练不放在 run_test 之前，避免旧版 RUNPHSTIME fatal。

ACE/APB 为 1 GHz；其他芯片时钟、复位、绑位与 DV 基线相同。主读写和 Home snoop 持续并行。结束时停止 A 新任务，Home 排空，静默 16 拍后关闭 Home，再观察 32 拍。

## 每个文件负责什么

| 文件 | 职责 |
|---|---|
| tb_top.sv | 实例化新版 ACE 和真实 CLCI，保留原芯片配置，创建接口并在零时刻启动 UVM |
| observe.svh | 连接十通道的源/目的观察信号、错误/计数、缓存和硬件静默条件；只观察 |
| ace_uvm_if.sv | APB 驱动信号与被动观察信号的 virtual interface |
| ace_uvm_model_pkg.sv | 独立内部发生器、六种数据公式、CR 判定与通道载荷 FIFO |
| ace_uvm_cache_cov_pkg.sv | 六项缓存行为的前后快照、握手和 CR/CD 证据关联 |
| ace_uvm_runtime_cov_pkg.sv | 两个 ACE 实例的 VCS 原生覆盖率查询；不调用 URG/Verdi |
| ace_uvm_checker_pkg.sv | 严格检查引擎：事务、数据拍、响应、ACK、AC/CR/CD、双端载荷和 44 个 bin |
| ace_uvm_pkg.sv | 配置对象、analysis 接口声明，包含下列组件与测试 |
| ace_uvm_apb.svh | APB item、sequencer/driver/monitor/agent；完整 SETUP/ACCESS、超时、PSLVERR 和读回 |
| ace_uvm_monitor.svh | 正沿保存握手和更新前缓存，1 ps 后保存更新后缓存；检查链路和允许的错误状态 |
| ace_uvm_env.svh | scoreboard、coverage 和 env；连接两个 monitor 的 analysis port，检查闭合并保存结果 |
| ace_uvm_sequences.svh | APB 配置、运行、停发、排空、暂停恢复、错误注入/清除/恢复和数据别名诊断的控制流程 |
| ace_uvm_tests.svh | 九类测试及独立诊断的 factory 注册、objection、进度/总超时和最终 PASS 条件 |
| sim/filelist.f | 只编译本环境与 ACE/CLCI，不引用 DV |
| sim/coverage_hierarchy.cfg | 代码覆盖范围只包括 u_master/module_a 与 u_slave/module_b |
| sim/coverage_plan.json | 四组九点、44 个命名 bin 的报告字典 |
| sim/check_project.py | 源码校验、依赖检查、旧路径和跨环境引用检查 |
| sim/run.sh / run.py | 用户入口、参数检查、独立编译缓存、结果目录、VCS/UVM 运行和报告判定 |
| sim/regression.sh | 六模式、定向、长度边界及负向回归 |
| sim/report.py | 严格解析、汇总表、未覆盖项和相同环境版本的功能并集 |
| sim/merge_code_coverage.sh / merge_code_coverage.py | 本环境 VDB 逐点并集、基本块源码着色和独立报告目录 |

模型文件虽然由已检查的 DV 算法建立独立副本，但没有 include/import DV 文件。后续修改必须分别检查，不能隐式依赖另一套环境。

## 检查如何保证不是只看计数

APB monitor 根据真正接受的配置写更新模型，未定义地址用独立地址表判断。发生器模型根据配置和真实 AW/AR 接受事件推进，不用 DUT 私有选择信号预测下一笔。

W 按地址、拍号、模式独立预测，检查 STRB/LAST。R 使用四槽带 tag 模型，反映已到达的 W/CD 和存储替换；不能将 B 当无限内存。CR 根据 AC 时刻的缓存快照独立判定，CD 必须与对应 AC/CR 和该快照匹配。十个通道均保留源/目的 FIFO，检查顺序、载荷和数量，背压时检查 VALID/载荷稳定。

最后同时核对实际请求、数据拍、B/R、ACK、CD 义务、队列、硬件 FSM/目录和 APB 计数。TX_TARGET 是下限，不能把多出的已接受工作丢弃。功能覆盖命中不代替这些正确性检查。

CR 判定和六项缓存覆盖使用真实缓存前后快照，不是全程独立缓存状态模型；因此不把本环境描述成完整 ACE 一致性证明。X/Z 和真正 UVM 调度还需要四态 VCS 验证。

## 暂停恢复

达到暂停位置后 APB 停止 A，Home 继续排空。暂停段检查无通道活动、无新增请求和配置保持；恢复后必须出现新请求。独立发生器、存储和匹配历史不重置，后续每笔仍要符合连续序列。

## 错误状态测试

先运行无注入单拍写基线，再依次执行：

1. B BRESP 注入 SLVERR。独立检查器必须观察到实际 SLVERR，A STATUS 必须精确为 0x22，B 为 0；等待后仍锁存。
2. 关闭注入，在排空状态清 A/B 错误与计数。状态必须为零，读回计数按新的基线核对，随后无注入流量必须成功。
3. 切到单拍读，B 开启“CR 期望取反”。必须有真实 CR 事件，实际 CR/CD 仍保持正确；B STATUS 必须精确为 0x24，A 为 0，且保持锁存。
4. 再关闭注入、清除、核对并恢复无注入流量。

只允许对应阶段的指定错误位，其他位仍失败。读数据、LAST、ID、ACK、双端匹配和超时等检查始终生效。B snoop 计数不随清错清零，因此单独按累计 CR 到达数核对；A TX/snoop、B WR/RD 则减去清除时的基线。发生器不会因清错重新起序列。

负向测试结果单列，禁止与普通通过测试的功能覆盖混合合并。

## 独立数据别名诊断

先从 BASE 做四拍 burst 写，再通过 APB 将 BASE 改为原 BASE+16，做单拍读。相同物理地址先处在写 beat 1，随后处在读 beat 0。检查器仍按实际存储内容判断；A 内部自检若与此矛盾，会如实 DIAGNOSTIC_FAIL，不改 RTL，也不算预期通过。

固定字节模式不依赖拍位置，因此可能通过这一诊断；这不能证明其他模式没有问题。诊断结果不参加正常功能覆盖合并。

## 功能与代码覆盖

仍是已确认的四组九点 44 个 bin：主事务 4、属性 5、起始行 4、burst 长度 7、snoop 4、CR 5、R 标签 3、数据模式 6、缓存行为 6。具体命名及证据定义见 test_plan.md。

checker 在真实握手时采样，coverage 组件只负责统一保存，不重复采样。控制台由脚本打印一次汇总表和未覆盖项，完整 bin/缓存证据另存。

代码覆盖仅两个 ACE，统计窗口从零时刻包含复位、启动、流量、暂停和收尾。实时接口没有 branch 入口，显示 N/A；保留 coverage.vdb。两个不重叠实例可按分子分母合计；不同仿真不能从汇总数推算代码点并集。独立 `sim/merge_code_coverage.sh` 读取各运行 VDB 的位图做逐点 OR，生成基本块源码视图；适配范围、指标差异和目标验证状态见 [代码覆盖率说明](code_coverage.md)。
