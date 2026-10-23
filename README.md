# CLCI_ACE_D2D_V2

新版 ACE 与真实 CLCI 双 Die 链路的独立工程。ACE 和其 APB 为 1 GHz，内部发生器通过 APB 配置，主事务与 Home snoop 并行工作。

**DV 与 UVM 两套环境均已实现；历史 s206 运行证据和本批新增用例的待验证范围见检查记录。**

```text
CLCI_ACE_D2D_V2/
├── ace/       新版 ACE 原始 RTL
├── clci/      已跑通基线的 CLCI 及必要头文件、模型、ROM
├── docs/      模块、验证设计、使用、文件清单和检查记录
├── dv/        独立非 UVM 顶层、模型、六个测试入口、sim工具与运行生成的out
└── uvm/       独立UVM顶层、组件、十二类功能入口、独立诊断、sim工具与运行生成的out
```

两套环境不互相引用测试文件。代码覆盖率只统计两个 ACE 实例。ACE 固定于 `6c306d613fd095f712caa8df44ccbe82f55569ae`，CLCI 来自旧工程已跑通版本；31份收录源码/依赖校验值保持不变，旧工程未修改。

- [DV运行方法与参数](docs/user_guide.md)
- [UVM运行方法、全部测试与参数](docs/uvm_user_guide.md)
- [UVM各文件与测试原理](docs/uvm_design.md)
- [模块与顶层设计](docs/design.md)
- [已确认测试及44个功能覆盖bin](docs/test_plan.md)
- [功能覆盖率四组、九点及全部44个bin详解](docs/functional_coverage.md)
- [跨测试代码覆盖率合并与源码查看](docs/code_coverage.md)
- [检查证据与限制](docs/VALIDATION.md)
- [已复现的数据诊断问题](docs/KNOWN_ISSUES.md)
- [缓存与snoop排序RTL审核](docs/rtl_review.md)
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

新增 `regression.sh cache` 分别运行三个 CR/缓存定向用例；`regression.sh coverage` 分别运行25项覆盖回归。DV与UVM各自独立执行。ACE/CLCI RTL及44个bin的覆盖判据保持不变；本批新增用例尚待s206运行。


## GitHub 源码与本地 CLCI 依赖

Git 不追踪根目录 `clci/`，发布历史也不包含该目录。GitHub 克隆只提供 ACE、DV/UVM 验证环境、脚本和文档。

完整仿真仍需要原有 27 份 CLCI 依赖。请在有授权的环境中将其放回工程根目录 `clci/`，保持 `docs/source_manifest.json` 的目录结构和校验值，然后运行两套 `sim/check_project.py`。服务器和本机已有的 CLCI 文件继续保留，Git 排除不会删除它们。

`docs/files.md` 列出本地完整工程所需文件；其中 CLCI 项是本地外部依赖，不属于 Git 追踪文件。
