# CLCI_ACE_D2D_V2

新版 ACE 与真实 CLCI 双 Die 链路的独立工程。ACE 和其 APB 为 1 GHz，内部发生器通过 APB 配置，主事务与 Home snoop 并行工作。

**DV 与 UVM 两套环境均已实现；尚待目标服务器 VCS/真实 CLCI 首轮验证。**

```text
CLCI_ACE_D2D_V2/
├── ace/       新版 ACE 原始 RTL
├── clci/      已跑通基线的 CLCI 及必要头文件、模型、ROM
├── docs/      模块、验证设计、使用、文件清单和检查记录
├── dv/        独立非 UVM 顶层、模型、三个测试入口、sim工具与运行生成的out
└── uvm/       独立UVM顶层、组件、九类测试、诊断、sim工具与运行生成的out
```

两套环境不互相引用测试文件。代码覆盖率只统计两个 ACE 实例。ACE 固定于 `6c306d613fd095f712caa8df44ccbe82f55569ae`，CLCI 来自旧工程已跑通版本；31份收录源码/依赖校验值保持不变，旧工程未修改。

- [DV运行方法与参数](docs/user_guide.md)
- [UVM运行方法、九类测试与全部参数](docs/uvm_user_guide.md)
- [UVM各文件与测试原理](docs/uvm_design.md)
- [模块与顶层设计](docs/design.md)
- [已确认测试及44个功能覆盖bin](docs/test_plan.md)
- [功能覆盖率四组、九点及全部44个bin详解](docs/functional_coverage.md)
- [跨测试代码覆盖率合并与源码查看](docs/code_coverage.md)
- [检查证据与限制](docs/VALIDATION.md)
- [已复现的数据诊断问题](docs/KNOWN_ISSUES.md)
- [本批文件清单](docs/files.md)

```bash
python3 dv/sim/check_project.py
python3 uvm/sim/check_project.py

bash dv/sim/run.sh smoke 0 1 +TX_TARGET=64
bash uvm/sim/run.sh ace_v2_apb_test 0 1
bash uvm/sim/run.sh ace_v2_smoke_test 0 1 +TX_TARGET=64

# 各自合并本环境的代码覆盖率并生成源码页面
bash dv/sim/merge_code_coverage.sh
bash uvm/sim/merge_code_coverage.sh
```

需要 Python 3.6+、Bash、支持原CLCI加密模型的授权VCS及其UVM1.2。默认使用VCS原生覆盖查询，不调用URG/Verdi。本地控制流程自检不代表完整UVM调度或真实CLCI已经仿真通过。

独立数据别名诊断已在本地真实ACE上复现五种模式的数据自检矛盾；RTL按要求保持不变，失败不计作PASS。该诊断与普通回归分开，详见KNOWN_ISSUES.md。
