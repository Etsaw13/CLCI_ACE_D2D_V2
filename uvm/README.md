# UVM 内部发生器环境

本环境与 DV 完全独立，只共同使用工程的 ACE/CLCI 源码和来源记录。所有主事务仍由 ACE 内部发生器产生，UVM 通过 APB 配置和控制，不输入外部订单。

```bash
bash uvm/sim/run.sh ace_v2_apb_test 0 1
bash uvm/sim/run.sh ace_v2_smoke_test 0 1 +TX_TARGET=64
bash uvm/sim/regression.sh --list
bash uvm/sim/regression.sh all
```

- [运行方法、全部测试和参数](../docs/uvm_user_guide.md)
- [各文件、组件和测试原理](../docs/uvm_design.md)
- [覆盖率计划](../docs/test_plan.md)
- [跨测试代码覆盖率合并与源码查看](../docs/code_coverage.md)
- [检查证据与限制](../docs/VALIDATION.md)

实际 VCS/UVM 与真实 CLCI 联合仿真在目标服务器运行。本机和 myserver 可执行参数及依赖检查。

`all` 共启动 34 次仿真，完成后将逐项结果和覆盖率汇总写入 `uvm/out/regression/<批次>/summary.txt`。默认自动生成 ACE 源码覆盖视图，入口为同批次的 `code_coverage/index.html`。

`cache_snoop` 运行两个缓存定向用例，`coverage_targets` 运行 24 次覆盖回归。手动分析已有运行时，可用 `merge_coverage.sh` 和 `merge_code_coverage.sh`。参数和统计范围见 [UVM 运行说明](../docs/uvm_user_guide.md)。
