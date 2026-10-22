# 跨测试代码覆盖率合并与源码查看

工程内包含两套独立入口，各自只读取本环境已经完成的运行。需要 Python 3.6+，无第三方依赖，不调用 VCS、URG 或 Verdi，不需要重新仿真。

**当前适配 VCS V-2023.12-SP2、UCAPI XML 13.1。s206 已完成独立位图方向校准，并用 16 次普通通过的 UVM 运行完成 v3 合并，生成了报告和四份源码页；首页及未覆盖清单已在目标浏览器打开。** DV 数据的目标合并验证及指标细分类校准仍分别保留其验证边界，详见 [检查记录](VALIDATION.md)。

## 运行

进入 CLCI_ACE_D2D_V2 根目录，按所需环境执行：

```bash
# 仅合并 DV 的代码覆盖率
bash dv/sim/merge_code_coverage.sh

# 仅合并 UVM 的普通通过用例代码覆盖率
bash uvm/sim/merge_code_coverage.sh
```

也可以直接运行同目录的 Python 文件，不需要额外传入 dv/uvm 参数：

```bash
python3 dv/sim/merge_code_coverage.py
python3 uvm/sim/merge_code_coverage.py
```

脚本根据自身位置确定工程根目录，可从其他工作目录通过绝对路径调用。不会因当前目录变化而读到另一套环境。

原有 `merge_coverage.sh` 用于功能覆盖 bin 的合并，并按运行列出代码覆盖计数。新增的 `merge_code_coverage.sh` 读取每个 `coverage.vdb` 的逐点位图，计算真正的跨测试代码点并集，同时生成源码视图。两个入口互不替代。

## 输入筛选与版本检查

默认扫描本环境 `out/*/run.json`。只合并 `simulation_pass=true`、退出码为 0、普通类别、`backend=runtime` 的运行，并检查日志 PASS、唯一最终事务摘要和错误标记。

- `build`、失败、未结束的运行不参与。
- UVM 的 negative 和 diagnostic 运行不参与普通并集，控制台列出剔除原因。
- collect/off 运行不参与本版工具，因为缺少所需的 runtime 计数交叉检查。
- 已选通过运行缺少 VDB 或报告损坏时直接失败，不默默忽略。

跨运行要求 ACE 提交、源码/验证文件指纹和覆盖计划相同；逐项检查 native definition checksum、shape 结构及位图长度。当前工程源码 SHA256 也必须与模拟时的来源记录一致，避免把旧数据着色到新源码。

adapter v3 将各指标的 `*.verilog.exclude.xml` 作为可选辅助文件：缺失时记录为 `absent`，不创建空文件，也不据此删减原生覆盖点；存在且没有排除条目时记录为 `present_empty`。实际排除条目仍不在本版适配范围内，会报错。控制台的 `OPTIONAL EXCLUSION XML` 分指标汇总这两种状态，JSON 在每次运行中保存其路径和校验值。此规则统一适用于 line、cond、tgl、fsm、branch；shape/data 和源码映射文件仍为必需输入。

若输出目录混有多个设计版本，可以显式选择同一版本的运行：

```bash
bash uvm/sim/merge_code_coverage.sh \
  --run uvm/out/<实际运行目录1> \
  --run uvm/out/<实际运行目录2>
```

DV 使用相同选项，但路径必须属于 DV。`--run` 可重复；相对路径相对当前工作目录。可通过 `--project-root /实际路径/CLCI_ACE_D2D_V2` 指定另一个完整工程副本。查看全部选项：

```bash
bash dv/sim/merge_code_coverage.sh --help
bash uvm/sim/merge_code_coverage.sh --help
```

## 结果位置和查看方式

默认每次新建目录，保留历史合并结果：

```text
dv/out/code_coverage/<时间_标识>/
uvm/out/code_coverage/<时间_标识>/
```

成功时控制台打印 `REPORT_DIR=...`、`OPEN_HTML=...`、`NATIVE_POINT_UNION=PASS`，退出码为 0。v3 的 `ADAPTER_TARGET_VALIDATION=PENDING` 和 HTML 页头的待验证文字是固定说明，不参与运行成功判定；它们不会因用户随后提供目标结果截图而自动变化。2026-10-22 已确认上述 16 次 UVM 数据的合并与页面生成跑通，其他支持边界以本文和检查记录为准，不能把固定提示当作本次失败。

在 s206 的图形桌面浏览器中打开打印的 `index.html`，例如把下列占位路径替换为实际输出：

```bash
firefox uvm/out/code_coverage/<时间_标识>/index.html
```

这是离线报告，源码已嵌入页面。没有图形桌面时，先在 s206 终端读取 `summary.txt` 和 `line_points.csv`；本地电脑浏览器不能直接访问 s206 的文件路径。数据和报告可以始终留在 s206。

| 输出文件 | 内容 |
|---|---|
| `summary.txt` | 各 native 指标的 master、slave、ACE pair 并集统计与统计口径 |
| `index.html` | 汇总、未覆盖基本块清单和源码链接 |
| `source_*.html` | 按 scope、文件分开的源码着色页，含公共函数；Details 展示命中测试 |
| `line_points.csv` | 全部基本块的索引、状态、位置、命中测试和 VCS 签名 |
| `merged_points.json` | 各运行及合并后的原始位图、来源和源码哈希 |

源码页提供“只看未覆盖/部分覆盖行”的筛选按钮，颜色含义如下：

| 颜色 | 含义 |
|---|---|
| 绿 | 该行全部已映射基本块命中 |
| 红 | 该行已映射基本块全部未命中 |
| 黄 | 该行只有部分已映射基本块命中 |
| 灰 | 没有已映射覆盖点，不能据此判为未覆盖 |

一个源码行可能对应多个基本块；一个基本块也可能对应多个语句。公共 `ace_funcs.svh` 在 A/B 内分别统计，不把两个实例混为同一份数据。VDB 索引存在空位时明确列为 unmapped，并保留在原生分母内，不猜测源码行号。

adapter v2 支持有效基本块内带 `line_ignore` 非零标记的子语句：仅抑制该子语句的源码锚点，不删除父基本块、不改变位图或统计分母。控制台的 `ignored_child_statement_annotations` 给出数量，JSON/CSV 与源码 Details 保存原始语句属性供核对。颜色表达已映射基本块的命中状态，不代表同一行每条语句都被执行；父基本块自身仍可具有有效源码锚点。

未覆盖表列的是基本块，不是互不重复的物理源码行。一个行号出现在表中，只能说明它关联的某个基本块未命中；同一行还可能关联已命中的基本块。签名为空或位置落在 `end` 附近时，应点开链接查看附近控制流，不能据此把整行或整个功能判为从未运行。被抑制的子语句锚点数量也不是额外的未覆盖基本块数。

需要自定义报告位置时，可指定尚不存在的目录：

```bash
bash dv/sim/merge_code_coverage.sh --output dv/out/code_coverage/review_01
bash uvm/sim/merge_code_coverage.sh --output /tmp/ace_uvm_native_review_01
```

工程内部的自定义路径必须位于本环境的 `out/code_coverage/`；也可以放到工程外。工具不改写原始 VDB、运行日志和已有报告目录。失败时不打印成功结论，不应把上一次生成的页面误认为本次结果。

## 指标含义与支持边界

每个原生覆盖点在跨测试合并时做 OR，同一个点多次命中只计一次。master/slave 是两个独立实例，ACE pair 按命中数与总数相加。不同指标没有统一分母，不取平均得到一个“总体代码覆盖率”。

| 指标 | 本版含义与校验 | 源码定位 |
|---|---|---|
| Line basic blocks | VCS 基本块；各运行位图命中数/总数必须与 runtime line 一致 | 支持基本块、语句位置及逐点命中测试 |
| Condition vectors | 原生条件向量槽位；与 runtime condition 计数一致 | 暂不展示具体表达式 |
| Toggle native slots | 原始槽位并集；已确认槽位数为 runtime bit 数两倍，配对含义尚未独立校准 | 暂不展示信号/方向；该百分比不能直接当旧表的 toggle 百分比 |
| FSM states+transitions | 状态和转移合在一起的并集；每次与 runtime 两项计数之和一致 | 尚未确定分类槽位位置，不声称已分别得到合并后的 state/transition |
| Branch native slots | 原生槽位并集；旧 runtime API 无 branch 查询可交叉核对 | 暂不生成分支源码着色 |

Line 百分比是基本块比例，不是物理源码行比例。原始槽位的展示与原 runtime 指标明确区分，不通过猜测重新定义其分子/分母。遇到未知 XML 版本、非二进制位图、多个候选数据文件、非空 exclusion、基本块级忽略标记或无法定位的有效源码锚点时拒绝合并。子语句级非零忽略标记按上述规则仅停止其源码映射，保留诊断信息。

工具保存独立的 JSON/CSV/HTML 报告，**不会生成可交给 URG/Verdi 的合并 coverage.vdb**。所有原始 `coverage.vdb` 仍应保留。
