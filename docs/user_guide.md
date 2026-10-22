# DV 运行使用说明

## 准备

将整个 CLCI_ACE_D2D_V2 目录拷贝到有授权 VCS 的服务器，进入工程根目录。需要 Python 3.6+、Bash 和能编译原 CLCI 加密模型的 VCS。不要覆盖旧 CLCI_ACE_D2D。

```bash
cd /你的存放路径/CLCI_ACE_D2D_V2
python3 dv/sim/check_project.py
CHECK_ONLY=1 bash dv/sim/run.sh smoke 0 1
```

这两条检查路径和源码校验值，不代表仿真通过。如果 vcs 不在 PATH，使用安装目录的实际路径。例如 s206 原先使用：

```bash
export VCS_BIN=/eda/synopsys/V-2023.12-SP2/amd64/bin/vcs
export VCS_INCLUDE=/eda/synopsys/V-2023.12-SP2/include
```

默认不需要设置 URG_BIN，不调用 URG/Verdi。

## 首轮运行

```bash
bash dv/sim/run.sh apb 0 1
bash dv/sim/run.sh smoke 0 1 +TX_TARGET=64
```

建议先完成这两项，再做多模式及长度回归。CLCI 硬件启动本身耗时较长，DV_PROGRESS 会显示仿真时间、阶段、链路就绪和请求/完成计数。历史约 341 us 只是旧环境启动参考，不是 V2 的已测保证。

## 常用例子

```bash
# PRBS23，至少 128 笔，burst 为 8 拍
bash dv/sim/run.sh smoke 4 1 +TX_TARGET=128 +BURST_BEATS=8

# 固定 0xA6，每拍重复 16 个字节
bash dv/sim/run.sh smoke 1 1 +XCODE=166

# 256 拍读边界：4 KB 对齐起始地址，每次独立仿真
bash dv/sim/run.sh burst_boundary 2 1 +DIRECTION=read +BURST_BEATS=256 +BASE_ADDR=20000000

# 255 拍写边界
bash dv/sim/run.sh burst_boundary 0 1 +DIRECTION=write +BURST_BEATS=255

# 增加 APB 访问打印
bash dv/sim/run.sh apb 0 1 +APB_TRACE

# 六种模式的 smoke；每项独立仿真，失败即停止
bash dv/sim/regression.sh smoke

# 2/3/4/5/8/16/255/256 拍 × 读写，模式 0
bash dv/sim/regression.sh boundary
```

256 拍禁止用于自动换起始行的无限混合轮转。即使 BASE 对齐，后续起始偏移仍可能跨界。脚本预查 boundary 的首笔，检查器持续检查每笔实际地址。

## 参数

格式：`bash dv/sim/run.sh 测试 模式 seed [附加参数...]`。位置参数不要省略中间项。

| 位置 | 取值 | 默认 | 含义 |
|---|---|---|---|
| 测试 | apb / smoke / burst_boundary | smoke | APB 寄存器、混合并行、单项 burst 边界 |
| 模式 | 0..5 | 0 | 0 PRBS31；1 固定字节；2 sequence；3 walking-one；4 PRBS23；5 PRBS10 |
| seed | 1..2147483647 | 1 | 传入仿真器。当前 DV 固定控制序列，无随机激励，改变 seed 不会改变内部发生器序列 |

| 附加参数 | 默认 | 范围与含义 |
|---|---|---|
| +TX_TARGET=N | smoke 64；boundary 1 | 1..100000，实际 AW/AR 请求下限；apb 没有主事务，不使用该目标 |
| +BURST_BEATS=N | 4 | 2..256，多拍事务长度；单拍仍为一拍 |
| +DIRECTION=write/read | write | 只决定 boundary 的主事务方向 |
| +BASE_ADDR=HEX | 20000000 | 44 位十六进制字节地址，可带 0x；必须 16 字节对齐且实际 burst 不跨 4 KB |
| +PRBS_CODE=N | 165 | 0..255，PRBS seed 混入值，两侧同时配置；不是仿真 seed |
| +XCODE=N | 90 | 0..255，固定字节模式值，两侧同时配置 |
| +SNOOP_GAP=N | 10 | 0..255，B Home 扫描间隔，A/Home 始终并行 |
| +LINK_TIMEOUT_US=N | 1000 | 1..100000，等待完整链路就绪的仿真 us |
| +RUN_TIMEOUT_US=N | 500 | 1..100000，从开始主流量到达到目标的仿真 us |
| +GLOBAL_TIMEOUT_US=N | 3000 | 1..100000，全局仿真时间保护，覆盖启动和收尾 |
| +DRAIN_TIMEOUT_CYC=N | 50000 | 16..10000000，停发后的排空 ACE 周期上限 |
| +PROGRESS_US=N | 10 | 0..1000，进度打印周期；0 关闭 |
| +APB_TRACE | 关闭 | 无值开关，打印 APB 访问 |

附加参数名称拼错、重复或数值越界会直接拒绝。boundary 要求 TX_TARGET=1，普通 smoke 允许目标下限带来的额外事务；两者都核对所有真实活动。

| 环境变量 | 默认 | 含义 |
|---|---|---|
| VCS_BIN | PATH 中 vcs | 编译器可执行文件路径，不是带参数的命令串 |
| VCS_INCLUDE | 自动查找 | 所选 VCS 的 include，包含 CoverMeter.vh |
| PYTHON_BIN | python3 | Python 解释器 |
| CHECK_ONLY | 0 | 1 只检查参数、文件与校验值 |
| COVERAGE | 1 | 0 关闭代码插桩和代码覆盖，仍生成实际功能覆盖与仿真检查 |
| COV_BACKEND | runtime | runtime：实时原生计数；collect：只采集 VDB，不请求实时百分比 |

```bash
# 暂时只做功能仿真；明确关闭代码覆盖
COVERAGE=0 bash dv/sim/run.sh smoke 0 1

# 保留 VDB，暂时不调用原生实时查询
COV_BACKEND=collect bash dv/sim/run.sh smoke 0 1
```

这些选项不能把真实检查失败转成 PASS。超时参数均指仿真时间，不是实际等待分钟数。内部 256 周期超时阈值不随脚本变化。

## 运行结果与保存

每次会打印完整 `RUN_DIR=...`。结果进入 `dv/out/测试_mode模式_burst长度_seed种子_时间_标识/`，重复运行不覆盖。匹配的编译版本缓存在 `dv/out/build/`，有编译锁防止同时写入；源码或编译配置变化自动使用新 build。

| 文件 | 用途 |
|---|---|
| run.log / console.log | 仿真器日志 / 控制台记录 |
| run.json | 实际参数、源码/验证环境校验值、工具与仿真结论 |
| functional_coverage.txt | 44 个命名 bin 的原始命中、缓存证据和 CD 闭合 |
| runtime_code_coverage.txt | runtime 后端的真实原生分子/分母及 N/A 原因 |
| coverage_summary.log | 一次性汇总表、未覆盖项、代码覆盖表 |
| coverage.vdb/ | 开启代码覆盖时保留的原始数据库 |

成功时必须有 `ACE_V2_DV_PASS`、`SIMULATION_RESULT=PASS`、`REPORT_RESULT=PASS`，脚本退出 0。仿真通过但报告失败会分别显示，脚本仍退出非零。错误报告中的 PARTIAL 不是完整覆盖结果。

```bash
# 紧接运行命令之后查看退出码
 echo $?
```

覆盖率低不直接表示功能错误，覆盖率高也不能证明数据正确。branch 在旧实时 API 中无入口，显示 N/A；line 是 VCS 基本块度量。统计只包含 u_master/module_a 与 u_slave/module_b；两个实例按分子分母加权，不能平均百分比。

## 重打报告与功能覆盖合并

全部 DV 测试运行完成后，在工程根目录执行：

```bash
bash dv/sim/merge_coverage.sh
```

脚本自动扫描本环境 `dv/out/*/run.json`，跳过 `build` 目录、仿真未通过或尚未结束的运行；只把通过的运行交给原有严格报告器。汇总显示在控制台，同时保存为 `dv/out/merged_coverage_summary.log`。不需要重新仿真，也不调用 VCS、URG 或 Verdi。

脚本按自身位置定位默认输出目录，也可以从其他目录调用。需要处理另一批输出或更改报告路径时：

```bash
bash dv/sim/merge_coverage.sh --out-dir /实际路径/dv/out --summary /实际路径/reports/dv_coverage.log
bash dv/sim/merge_coverage.sh --help
```

脚本提示使用英文，避免服务器 ASCII 终端打印中文出错。没有通过的运行、报告损坏/缺失或源码版本不一致会返回非零；成功时显示 `MERGE_RESULT=PASS`。报告文件仅在本次完整校验通过后替换，失败时原有文件可能仍是上一次结果，应以本次退出码和控制台结论为准。

不需要重新跑耗时仿真。将下面路径替换为实际 RUN_DIR，可以拖入终端或从 RUN_DIR 输出完整复制。

```bash
python3 dv/sim/report.py dv/out/实际运行目录

python3 dv/sim/report.py dv/out/实际目录1 dv/out/实际目录2 --summary dv/out/merged_functional_summary.log
```

合并器要求运行 PASS，ACE/CLCI 校验值、验证模型和覆盖计划一致。功能覆盖按逐 bin 命中并集统计，不能平均各次百分比。此入口的代码覆盖仍分次列出；跨测试代码点并集使用下述独立入口。

## 代码覆盖率合并与源码查看

```bash
bash dv/sim/merge_code_coverage.sh
```

仅扫描 DV 的普通通过运行，读取各自的 `coverage.vdb`，每次生成 `dv/out/code_coverage/<时间_标识>/`。控制台显示统计及 `OPEN_HTML`；在 s206 浏览器打开该 `index.html`，可查看已覆盖、未覆盖、部分覆盖和没有映射信息的源码行，以及命中基本块的测试。无需重新仿真，不调用 URG/Verdi。

当前适配 VCS V-2023.12-SP2，要求 runtime 后端结果参与计数核对；DV 真实工程 VDB 的合并仍待本环境的目标实测验证。UVM 的 16 次普通通过运行已在 s206 完成合并，不能据此替代 DV 验证。Line/condition 可与原 runtime 指标核对；toggle 原始槽位、FSM 合计和 branch 槽位有各自的统计边界。详细含义、参数和输出文件见 [代码覆盖率说明](code_coverage.md)。保留每次原始 VDB；脚本不会改写数据库。

## 独立 UVM 环境

UVM 九类、暂停恢复、错误注入及跨 burst 拍位置诊断已另行实现，见 [UVM运行说明](uvm_user_guide.md)。不要用旧工程脚本运行V2。两套环境都需要在目标VCS上首轮验证，本地自检不替代这一步。

## 2026-10-22：缓存与 CR 定向补充

新增三个独立入口，正式顶层仍经过真实 CLCI，全部激励通过 APB 和 ACE 内部发生器产生。

| 入口 | 前置状态与必查结果 |
|---|---|
| `uc_rs_sc` | Home 关闭时单拍写建立 UC，所有主事务与 ACK 排空后，Home ReadShared 返回 CR24，缓存和目录成为 SC，数据保持；UC_RS_SC 必须命中且无冲突，最后由 MakeInvalid 清理 |
| `cr_unique` | 分阶段建立 UC，利用 Home 的 RS/MI/CI/RO 轮转，最终 UC + ReadOnce 必须返回 CR16；每个阶段检查实际 AC/CR、状态、数据和计数 |
| `cr_shared` | 单拍写建立 UC，再以单拍 RS 取得 IsShared 并成为 SC；Home ReadShared 必须返回 CR8、保持 SC 和数据，随后 MakeInvalid 清理 |

```bash
bash dv/sim/run.sh uc_rs_sc 0 1
bash dv/sim/run.sh cr_unique 0 1
bash dv/sim/run.sh cr_shared 0 1

# 只运行上面三个用例，模式0，各自独立仿真
bash dv/sim/regression.sh cache

# 六种模式smoke + 三个缓存定向 + 十六项读写burst边界，共25次
bash dv/sim/regression.sh coverage
```

这些固定流程不接受显式 `+TX_TARGET`、`+BURST_BEATS`；DV 也不接受 `+DIRECTION`。Home 间隔固定为 255，显式其他 `+SNOOP_GAP` 会拒绝。仍可选择模式、seed、BASE、PRBS_CODE、XCODE 和超时。请求下限来自各流程，APB 停发前已经接受的额外任务也全部检查，不能把日志截成固定笔数。

每个定向阶段检查实际通道与 ACK 排空、缓存和 Home 目录的 tag/state、独立预期数据及 Home 存储。指定 CR 和缓存行为未出现、出现额外 snoop/CD、状态不符或关联冲突均失败。旧 smoke、压力和普通定向流量继续并行；这三个隔离前置状态的用例只证明具体功能可达，不证明并发竞争已经修复。

### 新旧验证版本的结果分开保存

本批改变了验证源码，旧结果的 `verification_checksums` 与新版本不同。两种合并器都继续拒绝混合验证版本；不要修改旧 run.json 校验值来强行合并。旧 VDB 和报告应保留。

建议在运行本批前，将已有 `dv/out` 移到工程外的历史目录，再运行上面的 `coverage` 回归和合并。下面仅移动历史结果，不删除它们；从工程根目录执行一次：

```bash
stamp=$(date +%Y%m%d_%H%M%S)
if [ -d dv/out ]; then
  mv dv/out "../CLCI_ACE_D2D_V2_dv_out_before_${stamp}"
fi

bash dv/sim/regression.sh coverage
bash dv/sim/merge_coverage.sh
bash dv/sim/merge_code_coverage.sh
```

不要在已有仿真运行时移动输出。25 次回归沿用原覆盖判据，不保证所有安装、时序与配置都自动达到 44/44；未命中仍如实列出。新增测试的本地检查范围见 [检查记录](VALIDATION.md)，未修改的 RTL 中已复现问题见 [RTL 审核](rtl_review.md)。本批新增用例仍需 s206 的真实 VCS/CLCI 验证。
