# UVM 内部发生器环境

本环境与 DV 完全独立，只共同使用工程的 ACE/CLCI 源码和来源记录。所有主事务仍由 ACE 内部发生器产生，UVM 通过 APB 配置和控制，不输入外部订单。

```bash
bash uvm/sim/run.sh ace_v2_apb_test 0 1
bash uvm/sim/run.sh ace_v2_smoke_test 0 1 +TX_TARGET=64
bash uvm/sim/merge_coverage.sh
bash uvm/sim/merge_code_coverage.sh
```

- [运行方法、全部测试和参数](../docs/uvm_user_guide.md)
- [各文件、组件和测试原理](../docs/uvm_design.md)
- [覆盖率计划](../docs/test_plan.md)
- [跨测试代码覆盖率合并与源码查看](../docs/code_coverage.md)
- [检查证据与限制](../docs/VALIDATION.md)

九类测试已实现，另有独立的数据别名诊断。实际 VCS/UVM 调度与真实 CLCI 链路仍须在目标服务器验证；本机和 myserver 都没有 VCS。

`merge_coverage.sh` 合并功能覆盖并单列负向/诊断结果；`merge_code_coverage.sh` 只对普通通过运行做 VDB 逐点并集，结果写入本环境的 `out/code_coverage/`。原生格式适配的目标实测状态见上述使用说明。
