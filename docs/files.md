# 文件清单与本批修改

整个V2为独立新工程，旧CLCI_ACE_D2D未改动。ACE/CLCI共31份来源文件保持原始字节，详情见source_manifest.json。

## 第二批UVM修改范围

相对已同步的DV第一批：

- 新建下表21份UVM代码/工具；更新原占位uvm/README.md。
- 新建docs/uvm_design.md、uvm_user_guide.md、uvm_validation_summary.json、KNOWN_ISSUES.md。
- 更新根README.md、docs/design.md、user_guide.md、test_plan.md、VALIDATION.md、source_manifest.json、validation_summary.json及本文件。
- ace/、clci/和dv/的所有文件与第一批逐字节相同。

| UVM路径 | 用途 |
|---|---|
| `uvm/ace_uvm_apb.svh` | APB item、driver、monitor、agent与sequencer连接 |
| `uvm/ace_uvm_cache_cov_pkg.sv` | 六项缓存行为证据和冲突诊断 |
| `uvm/ace_uvm_checker_pkg.sv` | 独立数据/协议/双端/ACK/CD对账与44个bin |
| `uvm/ace_uvm_env.svh` | scoreboard、coverage、env及phase结束检查 |
| `uvm/ace_uvm_if.sv` | APB主动信号与ACE被动观察virtual interface |
| `uvm/ace_uvm_model_pkg.sv` | 发生器、六种数据公式、CR与载荷FIFO模型 |
| `uvm/ace_uvm_monitor.svh` | 真实握手、缓存前后采样及状态检查 |
| `uvm/ace_uvm_pkg.sv` | 配置、类型及组件包入口 |
| `uvm/ace_uvm_runtime_cov_pkg.sv` | 两个ACE实例的原生代码覆盖率API |
| `uvm/ace_uvm_sequences.svh` | 配置、并行运行、暂停、负向、恢复和诊断控制序列 |
| `uvm/ace_uvm_tests.svh` | 九类测试、独立诊断、objection、超时与PASS |
| `uvm/observe.svh` | 两端ACE、状态、计数与缓存的被动连接 |
| `uvm/tb_top.sv` | 真实双Die与ACE顶层，零时刻run_test |
| `uvm/README.md` | UVM入口与文档链接 |
| `uvm/sim/check_project.py` | 独立依赖与源码不变检查 |
| `uvm/sim/coverage_hierarchy.cfg` | 仅两个ACE的代码覆盖范围 |
| `uvm/sim/coverage_plan.json` | 四组九点44个bin |
| `uvm/sim/filelist.f` | UVM独立编译清单 |
| `uvm/sim/regression.sh` | 四种回归入口 |
| `uvm/sim/report.py` | 严格报告、未覆盖项、普通功能并集 |
| `uvm/sim/run.py` | 参数、编译缓存、VCS/UVM运行及结果判定 |
| `uvm/sim/run.sh` | 用户运行入口 |

## 功能覆盖率说明文档

新增 `docs/functional_coverage.md`，说明四组、九个覆盖点、全部44个bin的含义、采样条件和统计边界；根README增加文档入口。本次未改变覆盖计划、测试逻辑或ACE/CLCI源码。

## 独立覆盖率汇总入口

新增 `dv/sim/merge_coverage.sh`、`dv/sim/merge_coverage.py` 和 `uvm/sim/merge_coverage.sh`、`uvm/sim/merge_coverage.py`。DV 默认只扫描本环境的 `dv/out`，UVM 默认只扫描本环境的 `uvm/out`，各自生成 `merged_coverage_summary.log`。两套入口不互相依赖。

脚本复用各自原有 `report.py` 的严格检查，自动跳过未通过或未结束的运行；UVM 错误注入和诊断结果各自单列。功能覆盖按 bin 合并，代码覆盖保持各次列出。更新两套 README 和运行说明。ACE/CLCI 源码、验证组件、覆盖计划和原报告器保持不变；临时测试与样例输出不收录。


## 2026-10-22 缓存/CR补充范围

- DV更新`tb_top.sv`、`sim/run.py`、`sim/regression.sh`。
- UVM更新`ace_uvm_if.sv`、`observe.svh`、`ace_uvm_pkg.sv`、`ace_uvm_sequences.svh`、`ace_uvm_tests.svh`、`sim/run.py`、`sim/regression.sh`。
- 新增`docs/rtl_review.md`；更新两套运行/设计说明、测试与覆盖说明、检查记录、历史验证JSON的本批条目、两套README和根README。
- 新测试通过APB配置，新增DUT内部连接均只读。ACE/CLCI、checker、cache覆盖观察器和44bin计划不变。实验/适配代码和运行输出不收录。


## Git 追踪范围（2026-10-23）

GitHub 发布排除全部历史中的根目录 `clci/`，当前 `.gitignore` 也忽略该目录。现有 27 份 CLCI 文件仍保留在本机和开发服务器，作为仿真所需的本地外部依赖。Git 当前追踪 65 份文件；下表仍是本地完整工程的 92 份文件清单，不能将其理解为 GitHub 会提供全部 CLCI 源码。

## 全部交付文件

代码覆盖率新增独立的 `dv/sim/merge_code_coverage.py`、`dv/sim/merge_code_coverage.sh`、`uvm/sim/merge_code_coverage.py` 和 `uvm/sim/merge_code_coverage.sh`，各自只读本环境 VDB，报告保存在各自的 `out/code_coverage/`。新增 `docs/code_coverage.md`，更新两套 README、运行说明、根 README 和检查记录。源码和仿真组件不变；合成测试、样例 VDB、校准源码及日志继续留在工程外。

以下包括原始来源文件与两套环境。out运行时生成，生成结果和历史日志不收录。

| 路径 | SHA-256 |
|---|---|
| `.gitignore` | 7c221263e100f4351b0f31091141d0a2074774e5e12ff667b6294519d8be4c91 |
| `README.md` | 6ba0bb0bfdfa1d60ef363c340b1babd351342735d8189f73a27152bed3b429f4 |
| `ace/ace_funcs.svh` | 3e3aba622f0e602b44127d56e7fafc74656de6dbb06cdb26938a8dc8970ddb58 |
| `ace/ace_pkg.sv` | f18c24bd8e73f130b67e377cf9cec5efe3b1489cd06511e0631d4344cafea71f |
| `ace/module_a.sv` | b34cff86db0aab09f287f6b1e569062ec84e8ff9cbcbc35fc3f85b46a628da29 |
| `ace/module_b.sv` | 2c1ed801b1db4bf155cca5e4517a7e5039836ebd34c7f66020a2ff2d1025bab4 |
| `clci/include/cmlib.v` | 7187a75e715313fa1e1f9fc86e8b08159bd8cd7db3c7d0d4082604755f5f873c |
| `clci/include/sram_wrapper/rom_4096x64.v` | 58d438c35200cec6eb9ba788ad7d2da862f98af190046c41da8e66a4f0d6ac77 |
| `clci/include/sram_wrapper/sdpram_256x129.v` | 761be2edb8b1dc3ee3c42cff3064ae2350846bf40d00aa4050127413562f83e4 |
| `clci/include/sram_wrapper/sdpram_256x145.v` | 1514f85f22586cbe76ec0da51bbc8d1d22d71ac192a2f7ec7d4569104f04078f |
| `clci/include/sram_wrapper/sdpram_256x149.v` | 80ae7d3f64eb10f7411c84f6c185d33bb44f58dcfa669a7e3db781a40e9d68dc |
| `clci/include/sram_wrapper/sdpram_256x18.v` | b25c76c879ebd82a907843496a248938efa9c459dbdf207316b5cc82f3c1f1f4 |
| `clci/include/sram_wrapper/sdpram_256x66.v` | 20a9d89a347768c276af4b70dc0da19f6be21e3150e74ba01d4eedeb098cbc58 |
| `clci/include/sram_wrapper/sdpram_256x97.v` | b3b18538364f6d0e167fa44c785bdf259db0f9dcffb39938b6780b3f105f20cf |
| `clci/include/sram_wrapper/sdpram_32x129.v` | 5b2f205234c61a93344cfe1c9e5bda442ab3effede36a5e7d70a87527d1a9ee2 |
| `clci/include/sram_wrapper/sdpram_32x145.v` | 4ec81f0bf95d08f30aa7861fd0fa250543a62126e89314db67e8deca5173641e |
| `clci/include/sram_wrapper/sdpram_32x149.v` | 0f1045c9d7cd85a7d2aa1f6d81e8a71086bb0f1337ad4675182f14b6e65d08b1 |
| `clci/include/sram_wrapper/sdpram_32x66.v` | a97b8f01d505604047836e78a2ef5e392a32bc3b8941579397dff7b8890f0949 |
| `clci/include/sram_wrapper/sdpram_32x97.v` | 176cf88a741d0d63a0f33ac81accc579e043c60784f27ba86305c438a6f1c56e |
| `clci/include/sram_wrapper/sdpram_64x1248.v` | fb0586e8f59fd6e2634a12bcd4649dc1d8e6eaadd32e05f8ae33d15bca665bca |
| `clci/include/sram_wrapper/sdpram_64x80.v` | 8a667c315bae21091101ed349c8c95028c5b3e9199a9091687aed32bcb1c212f |
| `clci/include/sram_wrapper/sram_4096x64.v` | 5e483334acbda2a5513cec741be6511fc76ad95595180908745d12299c9cf90d |
| `clci/include/typical_pd_nodccm/el2_param.vh` | 55b4517fa0808fd7524caa1ef5acfb734fafc628057b7c91742859646b2c73e6 |
| `clci/include/typical_pd_nodccm/pic_map_auto.h` | ddb724a2b11099a32e133927bceff311f03a5ed23e510a9a4285568a7dc8929e |
| `clci/models/clci_init_mem.sv` | 0b566b7b9909ebfbaf71d7bbbb7c19dff68f0107ef1f364cf129c7c4a770ef14 |
| `clci/models/n28_dline_coarse_4b_gray_ccs.v` | 0257f067acb7ce3ea5546edaa6645f04930f465b74f55293f92f4b40860b2609 |
| `clci/models/sideband_rx_v2.v` | b09e0dda3444fe95b944abc838b308261a9f16c5bb383715157a8e8b83815fc7 |
| `clci/models/sideband_tx_v2.v` | b52099503664fc2db75332a7bf91b5662d953121f41fb51712091ba4d5f95fd3 |
| `clci/models/ssttx_cmlrx_16lane_top.behav.v` | 9ba56a7dab3e3a575120f5c3d6adda92e11dd2c3ddddc46791ba0c6744d733f7 |
| `clci/rom/TS3N28HPCPA4096X64M16MBS.rom.v` | 3c85569b2d766a682e3b48fcffcf7df287f9bbd6867f2f17fe5271483df7eb6a |
| `clci/rtl/clci_sphy_all.v` | 003d0a3eeac13c6471c054e62b8c74d225dd3abbec8d93968e5704e922c6e0e3 |
| `clci/rtl/clci_subsys_wo_sphy.v` | 2ce3908166de6cbd340880e93c753e4d2a155a39a048530313c633c1ec8a24f2 |
| `clci/rtl/define_bmx_ace128.v` | 8decde59b16f50d60fddd55fdd05b6c102bc4f86d9e40179c3c5eeb3b9173f9a |
| `docs/KNOWN_ISSUES.md` | 17a220a1a901254fc76ccea8a859fc7353be60013ac8d6beeb6a122f9264d9f5 |
| `docs/VALIDATION.md` | 750908ec3a400e7eeccd8b4d32b84c963481cac42cc0e8feafafe999bacdd4ba |
| `docs/code_coverage.md` | 62b1b0de035a1882997d8d012296ed0b1844a00d62cb789adf27692fe590b1b3 |
| `docs/design.md` | 23e44e25ad33cb030a6bb66109e20a449552d6a46a5ad9ed43a0c1f91f80c49a |
| `docs/files.md` | 本文件不自校验 |
| `docs/functional_coverage.md` | a92d8a1682e9d95bd907da960e251734a3456e89d4204c4f9dc14c982bb60d83 |
| `docs/rtl_review.md` | a74b37f4e95b7a870f2998c41d93d1eea1d1cf30610ebd8d1ef9481e21848a09 |
| `docs/source_manifest.json` | b739ca55ab8716d928b145f4b952ef379ff8884cb5e0c99f6f13e06b03a4cd10 |
| `docs/test_plan.md` | 0e1d8a0b55a7b2358d7fad12006d6d5b4830d8aa2d6035f683f0cc3eeff8082f |
| `docs/user_guide.md` | ba319a1d7d3c8033b68da0d2f95decfc5d5782dee98f968f5ac1678653df7afa |
| `docs/uvm_design.md` | 1b628b9b25e8935e60f0ebd4813d35a6664b5c25e07f1a8b8407f8f3b7cbce4c |
| `docs/uvm_user_guide.md` | 7f1e76becf0f5849f1f03e4888a5915760b55f2dec41bec7d425795234389e80 |
| `docs/uvm_validation_summary.json` | 56be891cd38080a30232f2cbed5f238a6cb0374c5878b1338b4c393f68dacebd |
| `docs/validation_summary.json` | c89742a83c423a8116d065db3739dc74600d3bb7519c801a0cd781bf82ccd218 |
| `dv/README.md` | da9d9e83b8859886c833dde190aedc52ab7b33856b2b8f8131ae833afb19af58 |
| `dv/ace_dv_cache_cov_pkg.sv` | bab560bb29d96e95b7209dc1c4a79eba2712596cfc3683b1bc0d1a8b35cdcfc1 |
| `dv/ace_dv_checker_pkg.sv` | 763b97d82028a85c379e782b70e41e2ba41ccd0022a3fa60b4150676573d241f |
| `dv/ace_dv_model_pkg.sv` | 793a50be3fe5490194916e70442ecccbbf3aaa18ae6c69d3fcd5bb3472f258ec |
| `dv/ace_dv_runtime_cov_pkg.sv` | a0d65b4bd1d2c6478a81b7474c259ac602adef736104ee169c0734a95fd35bff |
| `dv/observe.svh` | 2733d033ae371a94a91f896b8b8379507df0b5287698bec93a4c261f8b6a127a |
| `dv/sim/check_project.py` | 985726308d7697f33c64c57bf24dc82c4ceff6058881a5a8d1fa4b1ba680b40c |
| `dv/sim/coverage_hierarchy.cfg` | 61cf194ee3cf92e7a0e40fac7d993a554763a1d27c3fbf869aa5137fd075f8a1 |
| `dv/sim/coverage_plan.json` | fe49c4d3a99cd36c36394e29c0b92ef2dfae7124485a0837bed280b87d7186e9 |
| `dv/sim/filelist.f` | f00c06285a3a3bd086504ee1ce7629f0679f29caf299b8d5f364c8c69c9e11cb |
| `dv/sim/merge_code_coverage.py` | 9dab7f8b4cdcbe3440ddd78abd5eadf5e056cf856c912f11f9fd11493a339cfc |
| `dv/sim/merge_code_coverage.sh` | 37f9474d131e71467a9b8e0ce8bf30e84a0989a8cfca36ec1a8c3d9a7b07b5af |
| `dv/sim/merge_coverage.py` | 770dad8949f79554f6331949214e18c09a78ec65e4ee1efc8c4b82549689206f |
| `dv/sim/merge_coverage.sh` | 614e6a182f466c4dd7bc475eda8cb06546d20df2039c75d22102844308c32cd1 |
| `dv/sim/regression.sh` | 0c359ef0878915ab6a786382cf44a9754b136906ebe2a583fd800017df9ae040 |
| `dv/sim/report.py` | 6b91613dfa9af500f8fb8714e114944b6f90affd6f4aeb7bf11577b60da86eb6 |
| `dv/sim/run.py` | 0e5908cd57ec2a6a2bfec8363b4108229c1694bb63e013670c92effe22a98858 |
| `dv/sim/run.sh` | 0976aea283381c74191735fd0ed50fe16cda5c8a0808405226cc04305f64e4b0 |
| `dv/tb_top.sv` | 8523b57006766bb5e50edd3968a51b36b809ffcabc00914efb24cf90fd4cb579 |
| `uvm/README.md` | 3e096881364cb97291e5a400ec3a2290cff60931a8a65290f0f57af22ca299c1 |
| `uvm/ace_uvm_apb.svh` | b2ac77a543642ab054720f82789fe15032f3ea2370b9f660b91f883526116623 |
| `uvm/ace_uvm_cache_cov_pkg.sv` | b038c3e65735d9f06d5ea3c55d0d19f4e2837dd2327e8720b8e119d4cf990e09 |
| `uvm/ace_uvm_checker_pkg.sv` | d4ee99c5ab5243df0eefc694b6d5d7e667d04d5eb6a055ccabfee9f837c3048b |
| `uvm/ace_uvm_env.svh` | 8e52d15e1aa4c3bad524fac26f26543da92735168ed327c2e4dcb60d570db26d |
| `uvm/ace_uvm_if.sv` | cbd150315bcbef52d0eea2528f9b9c96fa355de54ff3b8a0ba989a3deafe5834 |
| `uvm/ace_uvm_model_pkg.sv` | c93b988af6e5251e59a9157c6198ea0620d649f21fcec8b4bf3f0ccfb92b928c |
| `uvm/ace_uvm_monitor.svh` | e5ef626545fdb37ffd071f2d32366506b2a73a801f2dee8f8dbee0956cda72f0 |
| `uvm/ace_uvm_pkg.sv` | 5fc4daab344c7206c9910e35cca6d3c6e422cae5f1d638e40902e11f3a604c00 |
| `uvm/ace_uvm_runtime_cov_pkg.sv` | bdace1f74d6920875c84be5e4b162bf15ffa51220243d9c0ffb96a082432db0f |
| `uvm/ace_uvm_sequences.svh` | f035ed4d24d838904de35b82a23c6eae9bf6618f345fc0b916707c5ba4412987 |
| `uvm/ace_uvm_tests.svh` | e0e2613361de1fef3a0eea8390a34ca6f89cf76279e357517aea151e4d05aa84 |
| `uvm/observe.svh` | a7cf8e07a864f3d416bc4b9da19b11fab3426968fe217fb55d68fee4b2ad16b3 |
| `uvm/sim/check_project.py` | 6903ff9481b0f26dad14aebb6ebc16a8319310f831023b8d7c87e1d065af4517 |
| `uvm/sim/coverage_hierarchy.cfg` | 61cf194ee3cf92e7a0e40fac7d993a554763a1d27c3fbf869aa5137fd075f8a1 |
| `uvm/sim/coverage_plan.json` | fe49c4d3a99cd36c36394e29c0b92ef2dfae7124485a0837bed280b87d7186e9 |
| `uvm/sim/filelist.f` | 4c2e7a322ee7b2a0d3d79d531e8a08bc0ec020cc5e50a6a8eea1dc853a2c2f2b |
| `uvm/sim/merge_code_coverage.py` | 795733e9b21610040213e9dfab9409b9a3c0c8cccee4f6bbe7dbdced35534b9f |
| `uvm/sim/merge_code_coverage.sh` | 37f9474d131e71467a9b8e0ce8bf30e84a0989a8cfca36ec1a8c3d9a7b07b5af |
| `uvm/sim/merge_coverage.py` | 5b7c38c063389df512ca81991555bc221f7c3094ade5cf12a97d984bed002d26 |
| `uvm/sim/merge_coverage.sh` | 614e6a182f466c4dd7bc475eda8cb06546d20df2039c75d22102844308c32cd1 |
| `uvm/sim/regression.sh` | cc035485a6b6ef10f599412257d1bd704d68a44d1fd0b3670d70a612a31d3507 |
| `uvm/sim/report.py` | e7338b5f86b5ad1bd87021909fa11ddb3baae36aa54b7afd0d4733f62d98a10a |
| `uvm/sim/run.py` | 9a6f4e906226e85dd151169ec230c84cb4f398853c34482d65457a8df4cc158c |
| `uvm/sim/run.sh` | 0976aea283381c74191735fd0ed50fe16cda5c8a0808405226cc04305f64e4b0 |
| `uvm/tb_top.sv` | 50bc77f7e75a327e39d15ffc33cfc127ab8a7ac5d3396c16c821e5b3fe869296 |

共92份文件。

不收录：旧ACE、旧外部订单UVM、简化链路、VIP示例、历史输出/波形、旧补丁包、VCS/UVM工具安装、本地验证适配器和静态桩。厂商版权保持。
