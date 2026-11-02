# B0 / B1a 本机复现证据

日期：2026-10-10。此目录是本次运行的小型记录，区别于 H4E 已验收板测及原 B7 历史报告。

## 可核对记录

- [下载包与本地对比](baseline_comparison.json)：ZIP提交标记009f09b7276afbe962dff4bbcc5fa0324d432d79；577个原文件中576个不变，仅B7首页新增入口。254个H4E冻结文件完全相同。
- [基线汇总](baseline_summary.json)、[来源校验](baseline_check.log)、[68例日志](baseline_unit.log)、[13帧日志](baseline_pipeline.log)：ModelSim本机复现；返回码0。summary中的`git_sha_verified=false`指无本地Git历史，归档标记另见上述对比文件。
- [新增RTL汇总](b1a_summary.json)、[场景序列](b1a_cases.json)、[自动断言](b1a_simulation.log)、[编译日志](b1a_compile.log)：734个定向/随机向量、9帧8,294,400像素、11,138,255拍检查，返回码0。
- [检查器负例](negative_checker.log)：有意翻转一个参考像素，期望并得到仿真错误；不是交付RTL失败。
- `b7_assets_summary.json`、`b7_static_summary.json`、`b7_display_summary.json`：本次原B7重跑摘要；原42文件哈希一致。
- `synthesis_summary.json`、`synthesis_area.rpt`、`synthesis_timing.rpt`：最终源码独立综合，包含观察包装，结果及范围按报告读取。
- `delivery_manifest.json`：本次新增/修改文件及运行证据的SHA256，不替代原B7的source_manifest。

最终独立综合通过：75MHz暂定预算下setup裕量+2.370ns、hold+1.047ns，TNS均为0；1058寄存器、3490 LUT、估计2852 Slice、0 ERAM、0 DSP、0锁存器。含测试装载与观察包装，不是纯模块净增量。126个端口未分配板级引脚的警告保留在`synthesis_console.log`与`synthesis_run.log`，因为本次没有做板级约束或布局布线。

## 图像

以下图像的背景与结果包都是明确的合成测试输入，并非摄像头实拍。actual 图像由 RTL 输出的 RGB 二进制文件转换，reference 来自独立Python模型，diff为逐像素差异；黑色差分图表示无差异。

| 场景 | 实际RTL图 | 参考图 | 差分 |
|---|---|---|---|
| 正常100..199 / 200..299框，帧中更新仍不换框 | [actual](02_normal_mid_update_actual.png) | [reference](02_normal_mid_update_reference.png) | [diff](02_normal_mid_update_diff.png) |
| 框/十字经过Logo，保留不透明Logo | [actual](03_logo_overlap_actual.png) | [reference](03_logo_overlap_reference.png) | [diff](03_logo_overlap_diff.png) |
| 无效目标清除动态图层 | [actual](04_invalid_clear_actual.png) | [reference](04_invalid_clear_reference.png) | [diff](04_invalid_clear_diff.png) |
| 四边框与左上角十字，不回绕 | [actual](05_edge_and_sof_event_actual.png) | [reference](05_edge_and_sof_event_reference.png) | [diff](05_edge_and_sof_event_diff.png) |

其余帧可由脚本再生成，包括右下角、编号不匹配、busy等待及恢复。帧1无事件、帧2中途事件、帧5同SOF事件、帧6应用、帧7编号错误、帧8未就绪、帧9恢复，具体整包见cases JSON。

## 命令与环境

本次使用工作区`.venv`的Python3.14.6，NumPy2.5.3/SciPy1.18.1/Pillow；ModelSim10.3c路径`D:/altera14.1/modelsim_ase/win32aloem`，TD6.2.168116路径`D:/TD/bin/td_commands_prompt.exe`。从B7_GitHub目录运行：

```powershell
python -X utf8 scripts/check_h4e_baseline.py --modelsim D:/altera14.1/modelsim_ase/win32aloem
python -X utf8 run.py --modelsim D:/altera14.1/modelsim_ase/win32aloem
python -X utf8 run_b1a.py --modelsim D:/altera14.1/modelsim_ase/win32aloem
python -X utf8 synthesis/check_target_osd_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

首次综合发现Logo地址计算与ROM路径在75MHz下setup=-1.901ns，随后把地址登记移至第一级；图像延迟维持两级，重新执行全部B1a像素测试。首次失败报告仍在本地build历史目录，当前目录只收录最终源的仿真/综合证据，不能拿首次仿真配修正后未测试的RTL。

未完成整板布局布线、bit生成或本次上板；也未接入capture-v1、C真实mask配对、云台闭环或动态文字。这些不属于本次通过结论。
