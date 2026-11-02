# 来源、改动归属与已测试范围

仓库保持私有团队协作。此文件记录来源，不授予新的第三方再分发许可。官方例程、加密IP、Logo等保留原版权/头部；需要公开发布时应依据各来源实际许可决定分发范围，不能给整个工程套一个自创的统一许可。

| 来源 | 本次使用与改动 | 验证范围 |
|---|---|---|
| C `acd9165be556e6c732325e220fab72effae6c05b` | H4E使用6个逐字节相同模块：color_classifier_runtime、mask_frame_stats、mask_target_result、target_result_pack、mask_majority_3x3、mask_denoised_result | 前端分类、滤波和全局统计在H4E链路中使用；C10的完整标定/拒判/新帧顶层不等于已上板 |
| B `5e38a9698d7bbcedb1c06457e275c1d95d36b119` | 早期H1/H2采用rgb_bypass、rgb_to_gray；H4E沿用B提供的官方Logo ROM | H1/H2阶段板测，不代表B7四模式/按键/静态OSD联合顶层已上板 |
| A本地集成 / H4E | 显示光栅适配、动态诊断mixer、区域选择逐行回收/资源优化、显示快照及Logo覆盖优先级、TD约束/测试集成 | H4E阶段仿真/整板构建与用户板测，具体范围见基线说明 |
| 官方板卡例程及IP | MIPI/ISP/DDR/HDMI/PLL/器件依赖随216文件冻结清单保存，含历史未启用模块 | 是否实际编译以`.al`源列表为准，不是目录有文件即实现对应功能 |

本次仓库导出修改了Python驱动以消除H4D目录依赖，保留原Verilog测试台、夹具定义及独立SciPy参考语义。H4E区域核同时加入根目录`rtl/recognition/h4e_region_select.v`作为C后续维护入口；冻结快照为复现副本，不是另一个自由修改的开发源。

哈希证据见[来源核对](../boards/hx1p35a/h4e/evidence/provenance-check.json)、[原来源清单](../boards/hx1p35a/h4e/source_manifest.json)和[便携测试清单](../boards/hx1p35a/h4e/export_manifest.json)。保留原作者Git提交历史，本次提交不把B/C既有实现署为A新写。

历史独立复核（2026-10-08）：B7完整720p显示10帧/静态OSD5帧，C1–C9及C10十二帧/恢复测试通过；本次不重新声称这些是新跑出的结果。新导出测试记录另存`evidence/export-validation.json`。
