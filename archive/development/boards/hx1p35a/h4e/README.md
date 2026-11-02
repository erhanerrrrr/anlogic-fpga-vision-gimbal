# H4E 冻结视觉定位基线

此目录是 2026-10-10 验收版本的独立导出。**RTL、IP、管脚约束、时序约束、原工程及已验收 bit 均未改变**。仅把测试驱动改为仓库内可运行，并增加隔离构建入口。旧目录依赖已消除。

## 已验收码流

- 文件：[H4E_row_regions.bit](H4E_row_regions.bit)，1,789,539 字节。
- SHA256：`9d5bfd2f2f3ece15f772d92406762a30fbc06db0af72c16f2b87c461ee007f79`。
- 官方 HX1P35A / PH1P35MDG324，沿用原硬件连接。下载选择 PROGRAM_SRAM、5 MHz、Run；本基线未安排 Flash 固化。
- 预期标题 `H4E ROW RECYCLE R64`。红色物体对应白区；绿框和青色十字标注滤波后最大有效区域。R/F/D 是全局诊断，T 是被选区域。`N=010000` 是 256×256 固定 ROI 的像素数，非帧率。
- 用户已确认：不再间歇消失；大小目标同场选大目标；移走大目标后有效小目标接替；清空/恢复；约一分钟连续运行。证据类别是用户现场反馈，不是本次自动测量。

## 边界

红色阈值为 24/16/16，检测输入为固定白平衡之后、Gamma/灰度/OSD 之前的 RGB888；标定未接入。原始 mask 用于屏幕显示，上下各四行屏蔽及 3×3 五票滤波只用于检测。边缘残留的上游原因仍需定位。

精确 8 邻域最大连通域，面积至少 256；中心是包围框中点向下取整，非质心。等面积先比较 ymin，再比较 xmin。不使用 75% 填充率拒判。每行最多 64 游程、128 工作记录，记录逐行回收；超容量/行处理超时必须显式拒判，后续帧可恢复。

H4E 的帧 ID 来自 HDMI 刷新，**不代表摄像头采集新帧**。摄像头停帧但显示重复旧缓存时不能据此安全控制云台。固定白平衡/Gamma 不等于自动 ISP；最大区域选择不等于跨帧身份跟踪。

## 仿真、校验及构建

从仓库根目录按首页命令运行 check、unit、pipeline。依赖为 Python + NumPy/SciPy + Icarus。`simulation/`、运行日志、vvp、`build/` 是忽略的生成物。

原独立测试 68 帧、2,506,752 像素；链路 13 帧、11,980,800 滤波像素、8,785,920 非文字显示像素、83,031 个 Logo 不透明像素。覆盖 33 分支、分离小块、区域回收、64/65 游程边界、超时、空帧、复位和恢复。参考几何来自 SciPy 8 邻域标记，不复用 RTL 内部状态作为正确性依据。

完整 TD 构建示例（自行替换工具安装位置）：

```powershell
python -X utf8 boards/hx1p35a/h4e/run.py build --td D:/Anlogic/TD_6.2.1_Engineer_6.2.168.116/bin/td_commands_prompt.exe
```

脚本复制源码到 `build/`，仅调整副本 `.al` 的工程路径。构建检查综合/布局布线完成、路由后 setup/hold、资源预算和两份输出 bit 一致性，报告写入 `build/summary.json`。若已有构建目录，先自行归档再运行。**不要直接打开冻结的原 `.al` 构建**：其 Project Path 保留历史位置以便校验。

重构建产物不覆盖本目录已验收 bit，不自动获得上板验收状态，不要求与原 bit 二进制完全一致。工具版本、放置路由与文件头可能影响输出；新产物应单独验收。

## 资源、时序与证据

原已验收版本：12,348 Slice（58.20%）、45 ERAM、8 DSP；路由后 setup 裕量 +0.235 ns，hold +0.020 ns，TNS 均为零。仅针对现有 SDC，STA 覆盖率 94.10%，不能称全路径签核。相对 H4D 减少 5,145 Slice，相对 H4C 增加 1,263 Slice、3 ERAM。

14000 Slice / 60 ERAM / 8 DSP 是本阶段项目预算，不是器件上限或赛题门槛。测试观测最大行处理 1007 周期、EOF 等待 4 周期，不是所有可能图像的最坏延迟证明。

- [已验收状态和指标](evidence/build_summary.json)、[时序摘要](evidence/final_timing-summary.rpt)、[完整原始报告压缩包](evidence/final_timing.rpt.gz)、[资源报告](evidence/camera_to_dsi_display_phy.area)。
- [原阶段说明](evidence/README.md)是历史原文，含当时绝对路径；当前命令以本文件为准。
- `source_manifest.json` 保留原始来源清单；其旧 Python 驱动哈希用于溯源。新的便携测试驱动由 `export_manifest.json` 校验，两者不要混淆。
- [本次导出验证](evidence/export-validation.json)记录仓库路径下的新运行结果，与原上板证据分开。
