# H4E 新 C1：基线接管与资源边界

本阶段对应 2026-10-10 任务书 C1，不是历史 S0–C10 中的 C1。起点为 `009f09b7276afbe962dff4bbcc5fa0324d432d79`，共同板测基线来自 `7eb4a90`；开发分支为 `codex/c-h4e-followup`。接口仍为 `h4e-refresh-v1`。

## 本步做什么

复现冻结 H4E，再用相同测试明确编译根目录开发核，建立以后修改算法时的回归入口。本步只增加脚本、说明和小型证据，不修改生产 RTL、约束或 bit。实际结果见 [验收记录](../../reports/h4e-c1/acceptance.md)。

`scripts/run_h4e_c1.py` 的 development 模式把测试和依赖复制到临时目录，仅用 `rtl/recognition/h4e_region_select.v` 替换其中的区域核。区域测试的显式源列表是该核和 `tb_regions.v`；视频链路沿用冻结 `run_pipeline_test.py` 的明确列表，其他模块保持冻结版本。不会递归编译仓库，也不会写入冻结源码。`source_selection.json` 记录实际替换文件及哈希。

参考结果来自 SciPy 的独立 8 邻域连通域标记；RTL 的内部寄存器不参与计算期望几何。生成器、TB 和参考保留在冻结基线，封装脚本只负责选择源码、运行、收集证据。

## 必须保留的行为

- 检测读取固定白平衡后、Gamma/灰度/OSD 前的 RGB888。当前板级固定红色阈值 24/16/16、cfg_id=1；不能误恢复旧默认 80/40/40。绿、蓝的板级切换仍属后续工作。
- 上下各 4 行仅屏蔽检测前景，不删除 valid 或改变光栅位置；3×3 至少 5 票去噪。显示 raw mask，检测 filtered mask。
- 选最大 8 邻域连通区域，面积至少 256；同面积先 ymin、再 xmin。中心为包围框中点向下取整。同色区域相接可能合并，不提供物体身份跟踪。
- 区域核直接输入 255 像素拒绝、256 接受；RGB 输入的 16×16 实心块经过滤波可变为 252，必须拒绝。不能混淆两个入口。
- 空帧 E=1、过小 E=2、容量 E=3、处理期限/保护 E=5；有效 E=0。无效时公开几何归零。E=4 属于显示快照适配，不是区域核错误。
- 大区域移走后选剩余合格区域；清空、容量错误、期限错误之后，合法帧必须恢复。保留复位、新 SOF 打断、valid 间隙测试。
- 斜向接触、孔洞、L 形、分叉合并按独立参考判断，不用全局 75% 填充率拒判，也不以旧 C10 的全局框替换主区域 T。

## 容量、延迟和资源

每行最多 64 游程、128 工作记录，记录逐行回收；不是整帧只能检测 128 个区域。64/65 游程边界、多分支、已结束小块回收与期限不足都有测试。`labels_used` 为 8 位峰值记录数，`components` 为 12 位饱和计数。遇到容量不足应显式拒判，不发布截断后的假有效结果。

行处理和帧尾等待分别记录于逐例指标与链路日志。测试观测值不是对所有图像的最坏延迟证明；H4E 结果延迟可变，不能套用旧 C10 的 W+7。

本次 68 个区域案例观测最大单行处理 1,343 周期（`64_frontier_branches_merge_to_one`），帧尾等待最大 21 周期，峰值记录数最大 64；不能据此宣称穷尽 128 记录空间的所有边界。区域单测使用人为设置的行周期，和完整 720p 链路的观测必须分别解读。

历史已验收整机：12,348 Slice、45 ERAM、8 DSP；项目预算 14,000/60/8，团队共享剩余 1,652 Slice、15 ERAM、0 DSP。历史区域核层级报告：logic LUT 959、ripple 104、seq 923、ERAM 3、DSP 0、distributed RAM LUT 96；这些分类不能直接当成 Slice 相加。

历史整机 setup +0.235 ns、hold +0.020 ns，STA 覆盖率 94.1%，不是全路径签核。导出工程重构建的 12,253 Slice、setup +0.415 ns 是另一份未板测产物，不替代已验收指标。原始证据见 [冻结说明](../../boards/hx1p35a/h4e/README.md)。

本步生产 RTL 不变，预期硬件增量为 0；没有重新综合或上板。后续先采用小型字段寄存器、RAM 和共享运算，不扩整帧缓存、不简单放大寄存器阵列。完整工程资源和时序仍由 A 集成后确认。

## 如何复跑

安装 Python 3.12 和 Icarus，确保 `iverilog`、`vvp` 在 PATH。在仓库根目录执行（本机 Icarus 路径为 `C:/iverilog/bin`，队友按自己的路径调整）：

```powershell
py -3.12 -m venv tmp/h4e-env
./tmp/h4e-env/Scripts/python.exe -m pip install -r boards/hx1p35a/h4e/requirements.txt
$env:Path='C:/iverilog/bin;'+$env:Path
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c1.py --mode frozen
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c1.py --mode development
```

已经建立环境时无需重建。建议两种模式顺序执行，避免视频仿真同时占用 CPU。生成物在 `reports/h4e-c1/generated/`，不提交大型像素文件、vvp 或波形。每种模式必须得到 summary.json 的 PASS，并检查实际源码哈希。冻结源校验每次自动执行。

本机 Icarus 视频仿真较慢，原脚本每个进程限时 1,800 秒；本轮中止了两份未完成的 Icarus 视频运行，改用已有 ModelSim 10.3c。可用以下命令运行相同 TB、输入和显式源列表（区域单测仍为 Icarus）。ModelSim 单次允许 7,200 秒，属于电脑仿真时间限制，不是 FPGA 延迟：

```powershell
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c1.py --mode development --pipeline-simulator modelsim --work-root C:/Windows/Temp
```

旧 ModelSim 不支持本机带中文的工作目录，故在可写的纯英文临时目录运行，队友可自行指定其他目录。`--mode frozen --pipeline-simulator modelsim` 也在隔离目录运行。此次视频测试只完成一次开发源码运行，并用逐文件哈希证明其输入源码与冻结版相同；不宣称完成两次独立视频运行。实际工具、通过数量和未完成尝试均以验收记录为准。

`--mode frozen --collect-existing` 只归档已有日志，不重跑测试；仅适用于刚刚完成官方 check/unit/pipeline 的情况，不能拿旧日志声称新代码通过。

## 队友和人工验证

本步无需 A/B 改接线或下载新 bit。已有板测结论仅引用历史现场反馈，本轮未产生新板测。需要人工重查时由 A 使用冻结已验收 bit，观察最大目标选择、移走后的接替、清空/恢复；回传 bit 哈希、阈值/cfg、T 的面积/框/中心、E、区域数/峰值记录、场景及原始检测入口 RGB，避免只给拍屏颜色。

下一步 C2a：把 T 主区域的有效性、身份、配置、颜色、面积、几何、拒判原因和诊断一次性锁存为结果包，并给 A/B 固定的假结果序列。先不接标定、不改选区算法。真实采集 ID/epoch 及去重在 C2b 对接；当前 HDMI 刷新 ID 不能代表摄像头新观察。
