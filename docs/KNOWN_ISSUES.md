# 已发现问题与复现范围

## ACE 数据公式包含拍号，跨不同拍位置读取可能自检失败

状态：本地真实新版 ACE 已复现；ACE/CLCI RTL 未修改。目标VCS/真实CLCI仍待复核。

复现入口：

```bash
bash uvm/sim/run.sh ace_v2_data_alias_diag_test 0 1
```

步骤：通过APB配置内部burst写，从0x20000000写四拍；完成并排空后，将A的BASE改为0x20000010，切换内部单拍读。全程不输入外部订单、不强制内部状态。

地址0x20000010在第一次写中是beat1。B的带tag存储命中，返回先前真正写入的数据。后一次单拍读的当前拍号为0，而A内部数据自检使用 f(地址,当前拍号)。当前地址相同，但拍号变了，非固定字节模式的数据公式结果不同，因此A锁存err_rd_data。

UVM独立检查器按真实存储返回值检查，不把已存数据替换成新生成的期望；A的错误状态仍必须检查，因此诊断保持DIAGNOSTIC_FAIL。不是简单将计数放宽就能消除的问题。

本地执行适配自检结果：

| 模式 | 结果 |
|---|---|
| 0 PRBS31 | DIAGNOSTIC_FAIL |
| 1 固定字节 | PASS，数据不依赖拍号 |
| 2 sequence | DIAGNOSTIC_FAIL |
| 3 walking-one | DIAGNOSTIC_FAIL |
| 4 PRBS23 | DIAGNOSTIC_FAIL |
| 5 PRBS10 | DIAGNOSTIC_FAIL |

这些结果用真实新版ACE和独立延迟缓冲替代CLCI完成控制流程自检，尚不是目标VCS/UVM调度结果。普通测试默认组合通过，不代表上述重读场景被修复。诊断不计入正常回归通过率或覆盖合并。

后续应先确认规格：数据应由物理地址唯一决定，还是允许相同地址随事务拍位置改变；若允许后者，读自检如何跟踪已存内容。该选择涉及ACE功能RTL，须单独确认后处理。当前环境保留失败和复现入口。

## 工具范围

myserver和本机没有VCS。完整UVM1.2库已参与静态检查；本地Verilator5.34无法直接执行这份完整UVM1.2库，因此只在工程外用控制流程执行适配器检查真实ACE、APB/监视/模型的功能体。没有将适配器或简化CLCI替身放进交付工程。

实际UVM phase/objection、sequencer/driver传递、VCS四态行为、加密CLCI和原生代码覆盖查询仍须目标服务器验证。URG/Verdi不可用不影响默认运行，本项目继续保存VDB并使用原生实时覆盖API。
