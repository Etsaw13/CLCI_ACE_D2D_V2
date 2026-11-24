# UVM 运行使用说明

## 首轮运行

工程已同时包含 DV 与 UVM。myserver 上位置为 `/cluster/home/yvly/mywork/CLCI_ACE_D2D_V2`，该服务器没有 VCS，仅可检查文件。将完整工程放到有授权 VCS 的目标服务器，进入根目录后运行：

```bash
bash uvm/sim/run.sh ace_v2_apb_test 0 1
bash uvm/sim/run.sh ace_v2_smoke_test 0 1 +TX_TARGET=64
```

运行脚本会在调用 VCS 前校验源码清单中的 SHA-256。若找不到工具，可按 s206 原安装配置：

```bash
export VCS_BIN=/eda/synopsys/V-2023.12-SP2/amd64/bin/vcs
export VCS_INCLUDE=/eda/synopsys/V-2023.12-SP2/include
```

需要 Python 3.6+、Bash、VCS 自带 UVM 1.2 和支持原 CLCI 加密文件的授权安装。不需要安装 Python 第三方包，不调用 URG 或 Verdi。

## 原有九类测试与独立诊断

格式：`bash uvm/sim/run.sh 测试名 模式 seed [附加参数...]`。

| 测试名 | 目标 |
|---|---|
| ace_v2_apb_test | 复位值、配置/只读保护、未定义地址、清除脉冲；不发主事务 |
| ace_v2_smoke_test | SW/SR/BW/BR 混合轮转，Home snoop 并行，必须观察四类及 AC/CD |
| ace_v2_single_write_test | 单拍 WU/WLU、B/WACK 和缓存行为 |
| ace_v2_single_read_test | 单拍 RS/RU/RO 与补读、R/RACK、并行 snoop |
| ace_v2_burst_write_test | 多拍写、逐拍数据、STRB/LAST、B/WACK |
| ace_v2_burst_read_test | 多拍读、存储/生成数据、RLAST/RACK |
| ace_v2_snoop_stress_test | 单拍读，默认 gap=0，至少 4 次 AC 且有 CD；仍与主读并行 |
| ace_v2_pause_resume_test | 停发、Home 排空、配置/计数保持、恢复及序列连续 |
| ace_v2_error_status_test | BRESP/CR 两轮注入、指定错误锁存、清除、计数分段和恢复；结果单列 |
| ace_v2_data_alias_diag_test | 另列的同地址不同拍位置数据诊断，不属于上述九类正常/负向功能入口 |

```bash
bash uvm/sim/run.sh ace_v2_single_write_test 0 1 +TX_TARGET=64
bash uvm/sim/run.sh ace_v2_single_read_test 4 1 +TX_TARGET=128
bash uvm/sim/run.sh ace_v2_burst_write_test 2 1 +BURST_BEATS=16
bash uvm/sim/run.sh ace_v2_burst_read_test 0 1 +BURST_BEATS=256 +TX_TARGET=1
bash uvm/sim/run.sh ace_v2_snoop_stress_test 0 1 +TX_TARGET=128 +SNOOP_GAP=0
bash uvm/sim/run.sh ace_v2_pause_resume_test 0 1 +TX_TARGET=64 +PAUSE_AT=24 +PAUSE_CYCLES=200
bash uvm/sim/run.sh ace_v2_error_status_test 0 1 +TX_TARGET=64 +ERROR_TARGET=8

# 单独诊断，发现真实矛盾会返回失败，不自动算 XFAIL
bash uvm/sim/run.sh ace_v2_data_alias_diag_test 0 1
```

## 所有参数

三个位置参数默认分别为 ace_v2_smoke_test、0、1。模式：0 PRBS31，1 固定字节，2 sequence，3 walking-one，4 PRBS23，5 PRBS10。seed 范围 1..2147483647，传给仿真器；本版控制序列确定，改变 seed 不等于改变硬件发生器序列。

| 附加参数 | 默认 | 范围与含义 |
|---|---|---|
| +TX_TARGET=N | 64 | 1..100000，请求下限。smoke/pause 至少18，single_write至少2，single_read至少6，stress至少32，error_status至少8 |
| +BURST_BEATS=N | 4 | 2..256，仅多拍事务使用；诊断固定4拍 |
| +BASE_ADDR=HEX | 20000000 | 十六进制，可带0x；44位、16字节对齐，需留四个起始行空间，实际 burst 不跨4KB |
| +PRBS_CODE=N | 165 | 0..255，两侧 PRBS seed 混入值 |
| +XCODE=N | 90 | 0..255，固定字节值 |
| +SNOOP_GAP=N | 普通10；stress为0 | 0..255，Home间隔；间隔大时可增加目标数以满足专项活动要求 |
| +PAUSE_AT=N | TX_TARGET/2，最小1 | 1..99999，仅pause测试，须小于TX_TARGET；达到后发起停发 |
| +PAUSE_CYCLES=N | 100 | 16..1000000，排空后的暂停周期 |
| +ERROR_TARGET=N | 8 | 8..100000，每个注入/恢复段的最少新增请求数 |
| +LINK_TIMEOUT_US=N | 1000 | 1..100000，链路就绪等待上限，仿真us |
| +RUN_TIMEOUT_US=N | 500 | 1..100000，每个运行段达到目标的上限，仿真us |
| +GLOBAL_TIMEOUT_US=N | 3000 | 1..100000，全程仿真时间保护，错误测试包含全部阶段 |
| +DRAIN_TIMEOUT_CYC=N | 50000 | 16..10000000，排空的ACE周期上限 |
| +PROGRESS_US=N | 10 | 0..1000，进度打印周期；0关闭 |
| +APB_TRACE | 关闭 | 无值开关，打印每次APB访问 |

APB测试不使用TX_TARGET发流量。error_status先跑TX_TARGET笔基线，再跑四个ERROR_TARGET段（两轮注入/恢复），最终按所有实际请求对账。诊断使用两个受控运行段，TX_TARGET不决定其规模。

停发有 APB 生效延迟，最终可能多于目标；所有已接受工作仍必须成功排空。seed不是PRBS_CODE。时间参数是仿真时间，不是墙钟分钟数，不能改变 RTL 内部256周期超时阈值。

混合自动起始行覆盖 BASE+0/16/32/48。最大长度的读应使用 TX_TARGET=1；脚本对254..256拍读强制此限制，运行时继续检查所有真实地址。不要把256拍直接用于混合轮转来追求覆盖。

| 环境变量 | 默认 | 作用 |
|---|---|---|
| VCS_BIN | PATH里的vcs | 可执行文件路径，不附加参数 |
| VCS_INCLUDE | 自动查找 | 包含CoverMeter.vh的所选VCS include目录 |
| PYTHON_BIN | python3 | Python解释器 |
| UVM_VERBOSITY | UVM_LOW | NONE/LOW/MEDIUM/HIGH/FULL/DEBUG对应完整名称，例如UVM_HIGH |
| CHECK_ONLY | 0 | 1只检查参数与源码 |
| COVERAGE | 1 | 0明确关闭代码覆盖；功能覆盖和正确性检查仍运行 |
| COV_BACKEND | runtime | runtime原生计数，collect只保存VDB；两者均不调用URG |

```bash
UVM_VERBOSITY=UVM_HIGH bash uvm/sim/run.sh ace_v2_apb_test 0 1 +APB_TRACE
COVERAGE=0 bash uvm/sim/run.sh ace_v2_smoke_test 0 1
COV_BACKEND=collect bash uvm/sim/run.sh ace_v2_smoke_test 0 1
```

## 回归

```bash
# 六种数据模式，每次独立仿真
bash uvm/sim/regression.sh smoke

# 八个无注入入口，不含错误测试与诊断
bash uvm/sim/regression.sh directed

# 双方向，2/3/4/5/8/16/255/256拍，各次TX_TARGET=1
bash uvm/sim/regression.sh boundary

# 独立运行注入、清除、恢复测试
bash uvm/sim/regression.sh negative
```

所有回归失败即停止。诊断不默认加入通过率回归。

## 如何判断结果

每次打印 RUN_DIR，结果保存在 `uvm/out/测试_mode模式_burst长度_seed种子_时间_标识/`；DV 的 out 与编译缓存不参与本环境。

成功需同时满足：ACE_V2_UVM_PASS、UVM_ERROR/FATAL均为0、SIMULATION_RESULT=PASS、REPORT_RESULT=PASS，脚本退出0。错误测试允许的是RTL指定状态，不会把UVM_ERROR/FATAL当作预期通过。

`run.log`保存UVM日志和十通道对账；`run.json`保存实际配置、版本及源码校验值；`functional_coverage.txt`保存44个bin、缓存证据和CD闭合；`runtime_code_coverage.txt`保存真实原生计数；`coverage_summary.log`为汇总表与未覆盖项；开启代码覆盖时保留`coverage.vdb/`。

仿真通过但覆盖报告失败会分开打印，脚本仍退出非零。失败时保存的PARTIAL结果不能当完整覆盖。UVM_FATAL会尽可能保存部分报告；仿真器本身在UVM启动前退出时可能没有报告。

```bash
# 紧接运行命令执行
 echo $?

# 不重新仿真，重新生成某次报告
python3 uvm/sim/report.py uvm/out/实际运行目录

# 只合并相同版本的普通通过测试
python3 uvm/sim/report.py uvm/out/实际目录1 uvm/out/实际目录2 --summary uvm/out/merged_functional_summary.log
```

错误测试和诊断单独报告，禁止并入普通覆盖。功能覆盖按bin命中并集，不平均百分比；原报告器的代码覆盖仍分次列出。跨测试代码点并集另用下述 `merge_code_coverage.sh`。两个ACE实例合计使用分子/分母加权；branch实时查询显示N/A，原始VDB应保留。

### 一次汇总全部 UVM 运行

```bash
bash uvm/sim/merge_coverage.sh
```

脚本扫描 `uvm/out/*/run.json`，跳过 `build` 目录、仿真未通过或尚未结束的运行。通过的普通测试合并到 `uvm/out/merged_coverage_summary.log`；通过的错误注入和诊断测试分别重打各自的 `coverage_summary.log`，不会并入普通覆盖。所有报告也会显示在控制台。不需要重新仿真，不调用 VCS、URG 或 Verdi。

默认目录根据脚本自身位置确定，可以从任意工作目录调用。可选参数示例：

```bash
bash uvm/sim/merge_coverage.sh --out-dir /实际路径/uvm/out --summary /实际路径/reports/uvm_coverage.log
bash uvm/sim/merge_coverage.sh --help
```

提示使用英文，避免 ASCII 终端打印中文出错。版本不一致、报告缺失/损坏、运行类别无效或没有通过的普通测试会返回非零。单列报告失败时仍尝试生成普通测试汇总，但总退出码仍非零；全部成功时显示 `MERGE_RESULT=PASS`。每个报告通过完整校验后才替换文件，失败时旧文件可能仍保留，应以本次退出码和控制台结论为准。

### 合并代码覆盖率并查看源码

```bash
bash uvm/sim/merge_code_coverage.sh
```

只读取 UVM 的普通通过运行，negative/diagnostic 不参与正常并集。每次生成 `uvm/out/code_coverage/<时间_标识>/`，控制台打印 `OPEN_HTML`。在 s206 浏览器打开对应 `index.html` 查看基本块源码着色、未覆盖清单和逐点命中测试；无需重新仿真，不调用 URG/Verdi。

当前适配 VCS V-2023.12-SP2，依赖 runtime 后端进行计数核对；s206 已用 16 次普通通过的 UVM 运行完成 v3 合并，并打开 HTML 首页及未覆盖清单，基本块并集为 404/458（88.21%）。这项证据不扩大 toggle、FSM、branch 的指标支持边界。Line/condition 与原 runtime 计数对照，toggle 原始槽位、FSM 合计和 branch 槽位单独说明口径。输入筛选、指定运行及源码颜色说明见 [代码覆盖率使用说明](code_coverage.md)，实测来源见 [检查记录](VALIDATION.md)。

所有覆盖项定义见[test_plan.md](test_plan.md)，文件和检查原理见[uvm_design.md](uvm_design.md)。先完成APB和默认smoke，再扩大测试规模；当前真实VCS/UVM和CLCI运行结果仍需你在目标服务器确认。

## 2026-10-22：缓存与 CR 定向补充

新增三个独立入口，正式顶层仍经过真实 CLCI，全部激励通过 APB 和 ACE 内部发生器产生。

| 入口 | 前置状态与必查结果 |
|---|---|
| `ace_v2_uc_rs_sc_test` | Home 关闭时单拍写建立 UC，所有主事务与 ACK 排空后，Home ReadShared 返回 CR24，缓存和目录成为 SC，数据保持；UC_RS_SC 必须命中且无冲突，最后由 MakeInvalid 清理 |
| `ace_v2_cr_unique_test` | 分阶段建立 UC，利用 Home 的 RS/MI/CI/RO 轮转，最终 UC + ReadOnce 必须返回 CR16；每个阶段检查实际 AC/CR、状态、数据和计数 |
| `ace_v2_cr_shared_test` | 单拍写建立 UC，再以单拍 RS 取得 IsShared 并成为 SC；Home ReadShared 必须返回 CR8、保持 SC 和数据，随后 MakeInvalid 清理 |

```bash
bash uvm/sim/run.sh ace_v2_uc_rs_sc_test 0 1
bash uvm/sim/run.sh ace_v2_cr_unique_test 0 1
bash uvm/sim/run.sh ace_v2_cr_shared_test 0 1

# 只运行上面三个用例，模式0，各自独立仿真
bash uvm/sim/regression.sh cache

# 六种模式smoke + 三个缓存定向 + 十六项读写burst边界，共25次
bash uvm/sim/regression.sh coverage
```

这些固定流程不接受显式 `+TX_TARGET`、`+BURST_BEATS`；DV 也不接受 `+DIRECTION`。Home 间隔固定为 255，显式其他 `+SNOOP_GAP` 会拒绝。仍可选择模式、seed、BASE、PRBS_CODE、XCODE 和超时。请求下限来自各流程，APB 停发前已经接受的额外任务也全部检查，不能把日志截成固定笔数。

每个定向阶段检查实际通道与 ACK 排空、缓存和 Home 目录的 tag/state、独立预期数据及 Home 存储。指定 CR 和缓存行为未出现、出现额外 snoop/CD、状态不符或关联冲突均失败。旧 smoke、压力和普通定向流量继续并行；这三个隔离前置状态的用例只证明具体功能可达，不证明并发竞争已经修复。

### 新旧验证版本的结果分开保存

本批改变了验证源码，旧结果的 `verification_checksums` 与新版本不同。两种合并器都继续拒绝混合验证版本；不要修改旧 run.json 校验值来强行合并。旧 VDB 和报告应保留。

建议在运行本批前，将已有 `uvm/out` 移到工程外的历史目录，再运行上面的 `coverage` 回归和合并。下面仅移动历史结果，不删除它们；从工程根目录执行一次：

```bash
stamp=$(date +%Y%m%d_%H%M%S)
if [ -d uvm/out ]; then
  mv uvm/out "../CLCI_ACE_D2D_V2_uvm_out_before_${stamp}"
fi

bash uvm/sim/regression.sh coverage
bash uvm/sim/merge_coverage.sh
bash uvm/sim/merge_code_coverage.sh
```

不要在已有仿真运行时移动输出。25 次回归沿用原覆盖判据，不保证所有安装、时序与配置都自动达到 44/44；未命中仍如实列出。新增测试的本地检查范围见 [检查记录](VALIDATION.md)，未修改的 RTL 中已复现问题见 [RTL 审核](rtl_review.md)。本批新增用例仍需 s206 的真实 VCS/CLCI 验证。
