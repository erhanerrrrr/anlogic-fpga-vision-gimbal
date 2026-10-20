# B4g 上传 GitHub 清单

按 `../../docs/tasks/B-task-guide.md` 第四节，每小阶段的 PR 要能让 A 复跑、接入并定位错误。本清单用于 B4e/B4f/B4g 尚未上传时；上传到仓库中相同的相对路径，不要把所有文件平铺在仓库根目录。

## 1. 源码与显式列表

- `rtl/osd_fps_decimal.v`
- `rtl/video_performance_text.v`
- `rtl/video_b4g_h4e_sameclk.v`
- `b4e_sources.f`、`b4f_sources.f`、`b4g_sources.f`

`b4g_sources.f` 列出 B4g 联合仿真的全部 36 个 Verilog 文件。目标分支还必须已经包含其中的 B1/B2/B3/B4c 模块、字库及 `../boards/hx1p35a/h4e/` 共同基线；缺一个就要连同依赖补上。B4g 顶层不是单独三个新 RTL 就能编译。

## 2. 可复跑仿真与独立参考

- `sim/tb_b4e_fps_decimal.v`、`sim/tb_b4f_performance_text.v`、`sim/tb_b4g_native720_performance.v`
- `run_b4e.py`、`run_b4f.py`、`run_b4g.py`
- `run_b4g.py` 使用的前置参考脚本：`run_b4d.py`、`run_b4c.py`、`run_b4b.py`、`run_b3g6.py` 及其现有 `scripts/`、`model/` 和字库 JSON 依赖；若目标分支没有，须一起补齐。

测试输入由 TB 产生，不另传巨大像素数据。Python 参考模型在运行脚本中，ModelSim 实际输出与参考图逐像素比对。

## 3. 资源与时序复跑

- `synthesis/check_b4e_fps_synthesis.py`
- `synthesis/b4f_performance_probe.v`、`synthesis/check_b4f_performance_synthesis.py`
- `synthesis/b4g_closed_loop_probe.v`、`synthesis/check_b4g_closed_loop_synthesis.py`
- 上述脚本依赖目标分支已有的 `synthesis/td_runner.py`、`synthesis/check_video_display_synthesis.py` 等辅助文件。

## 4. 说明与轻量证据

- `B4e_README.md`、`B4f_README.md`、`B4g_README.md`
- `docs/B4g_to_A_handoff.md`、`docs/B4g_GitHub_upload_checklist.md`
- `scripts/package_b4g_report.py`
- `reports/b4g_20261020/` 下的 `delivery_manifest.json`、`verification.txt`、`01_actual.png`、`01_reference.png`、`01_diff.png`

这些文件提供字段/单位表、接口 profile、局部两拍延迟、全链四拍延迟、测试命令、工具版本、PASS 摘要、资源/FIFO 数值、已知限制、A 上板观察项和异常时需回传的字段。`01_actual.png` 来自 RTL，不是只用 Python 画的示意图。`delivery_manifest.json` 标明合成输入、用户复跑确认和未上板状态。

## 5. PR 中写清楚

目标分支和起点 commit SHA 要从 GitHub 当前页面或 Git 记录填写，不能猜。说明所用 profile：已测范围为同像素时钟域的 B4g 仿真；真实 `capture-v1` 来源身份、测量包和板级适配仍由 A 完成。写明复跑命令、2 帧 1280×720 共 1,843,200 像素零差异、ModelSim 零错误零警告、FIFO 峰值 1284、独立综合 9,339 Slice/10 ERAM/0 DSP/暂定 75 MHz SWNS +1.071 ns。注明资源包含测试包装，不是整板净增量；无 bit/板测结论。

不要上传 `build/`、`test_data/`、`.venv/`、ModelSim 波形 `*.wlf`、工具目录、逐像素 CSV、映射数据库或未经整板验证的 `*.bit`。这些可由脚本重建；仓库 `.gitignore` 已覆盖主要生成物。
