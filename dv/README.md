# DV 环境

独立非 UVM 环境，使用 `ace/` 与 `clci/`，不引用 `uvm/` 的任何文件。

```bash
bash dv/sim/run.sh apb 0 1
bash dv/sim/run.sh smoke 0 1 +TX_TARGET=64
bash dv/sim/run.sh burst_boundary 2 1 +DIRECTION=read +BURST_BEATS=256
bash dv/sim/merge_coverage.sh
bash dv/sim/merge_code_coverage.sh
```

从工程根目录执行上述命令。具体参数、通过条件及输出文件见 [运行说明](../docs/user_guide.md)。

`merge_coverage.sh` 合并功能覆盖；`merge_code_coverage.sh` 合并本环境 VDB 的代码覆盖点，生成 `out/code_coverage/` 下的统计和源码着色页面。格式支持范围及目标验证状态见 [代码覆盖率使用说明](../docs/code_coverage.md)。

`tb_top.sv` 放置芯片和 ACE、配置 APB、控制流程；`observe.svh` 被动观察真实链路的两端。
模型、缓存行为覆盖、原生代码覆盖查询和严格对账分别在四个 `ace_dv_*_pkg.sv` 文件中。
`sim/` 收纳运行工具与编译/覆盖配置；结果自动写入本环境自己的 `out/`。
