# B2c：接入完整画面的 Sobel 边缘检测

B2b已于2026-10-14由使用者复跑并确认原图/灰度图片正确。本阶段在已验证的真实C配对/灰度输出后接EDGE，先独立验证边缘图像，不提前声称四模式已经对齐。

## 一键复跑

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b2c.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

依次检查Sobel算术与独立边缘级故障、真实C联合链故障/复位、小图和完整6帧720p；最后应显示 `PASS: B2c checks completed.`。完整仿真可能需要十几分钟，以最终PASS为准；中途的小图PASS不是全部完成。`--small-only`可快速排查小图，不能代替完整验收。

图像在 `build/edge_stream/run_.../native_720p/`。查看同编号的 `rgb_actual.png`、`gray_actual.png`、`edge_actual.png`：色块之间出现亮边，均匀区域主要为黑，最外一圈始终黑色。`edge_reference.png`是独立参考，`diff.png`是原图/灰度/mask/EDGE的联合差分，应全黑。复杂彩色图可能有密集边缘，不等于花屏；应以参考和差分判断。

## 数据路径和资源方案

```text
RGB ── B2a真实C分类/滤波和一份RGB队列 ── B2b原图/灰度级 ── base_*（原节奏）
                                                        │ 灰度8位
                                           两行缓存 → 3×3窗口 → Sobel
                                                        │
                                              out_*（EDGE独立节奏）
```

显式源列表为 `b2c_sources.f`，新增 `video_gray_edge_stream.v` 与整合入口 `video_rgb_mask_edge.v`。原B2a/B2b模块、B7的 `window_3x3.v` 和 `sobel_core.v` 均直接复用且保持原文件不变。冻结H4E分类/滤波也保持不变。

新边缘级直接消费B2b已经算好的灰度，不重复进行RGB转灰度。复用两行8位窗口缓存，按输入下一行的位置安排上一行输出；顶部、左边、右边和最后一行的黑色边界由调度逻辑补齐。无需原B7 `edge_raster` 的额外四行1位边缘缓存，也不实例化原 `video_rgb_edge_align` 的大RGB FIFO。

新增逻辑存储为 `2×WIDTH×8` 位，720p为20480位灰度历史，实际映射2 ERAM。沿用的RGB队列仍为2048×24位、峰值1284像素，仍只保存一份。帧身份用寄存器跟随流水线及尾部冲刷，没有整帧缓存。

当前内部路径是串行验证结构。B2d统一四模式时应重新安排并行运算与共用缓存，不能简单给RAW/GRAY追加一套大RGB FIFO，也不能直接选择不同节奏的两路端口。

## 边缘算法的精确定义

- 输入灰度沿用B2b：`Y=floor((77R+150G+29B+128)/256)`，8位无符号。
- 3×3邻域按行排列p00..p22，`Gx=(p02+2p12+p22)−(p00+2p10+p20)`，`Gy=(p20+2p21+p22)−(p00+2p01+p02)`。
- Gx/Gy使用11位有符号数，各在−1020..1020范围；幅值为11位无符号 `abs(Gx)+abs(Gy)`。不求平方根、不截成8位、不作255饱和后再比较。保守上界2040可被11位完整表示；遍历二值邻域实测最大幅值1530。
- `magnitude >= THRESHOLD` 输出RGB全白，否则全黑。THRESHOLD是11位编译参数，默认128，本阶段不提供帧中改变阈值的运行时接口。
- x=0、y=0、x=WIDTH−1、y=HEIGHT−1的最外一圈强制为黑，即使阈值为0也是黑；其余位置必须使用完整邻域，不复制边界像素。
- C检测的上下四行mask屏蔽规则只作用于检测分支。EDGE使用原彩色图转换的灰度，不使用滤波mask作为Sobel输入。

## 接口与两种输出节奏

整合入口输入与B2b一致：单时钟、RGB888、11位坐标、SOF/EOL/EOF、epoch/frame/cfg/color为32/32/16/2位，以及真实C分类阈值。颜色仍指R/G/B，不是物体身份。合成标签验证不代表已完成真实采集/DDR来源绑定。

| 输出组 | 内容与规则 |
|---|---|
| base_* | 完整保留B2b的RAW/GRAY/mask及自身valid、坐标、帧标志、全部身份；不因EDGE改变检测输入 |
| out_* | EDGE RGB888及其自身valid、坐标、帧标志、全部身份；延迟多于base_* |
| out_abort | 原输入/配对/边缘故障通知，允许多拍；下游丢弃当前未完成帧 |
| error_flags[7:0] | 沿用B2a错误位定义 |
| error_flags[12:8] | 新边缘级诊断，定义见下表；复位清除 |
| fifo_used/fifo_peak | 原RGB配对队列的当前/峰值像素数，不是EDGE输出坐标 |

**base_*与out_*不能直接逐拍混合或用一个组合MUX选成四模式。** 它们各自的坐标/身份正确，但输出时间不同。本阶段没有模式选择、OSD叠加、HDMI时序或DDR读请求；这些不能仅靠改端口名或延迟HS/VS来完成。

边缘级 `video_gray_edge_stream` 也可单独使用，输入必须是行内连续的合法灰度流。支持WIDTH/HEIGHT 3..2048；MAX_IDLE_CYCLES至少2，默认4096。在一帧内身份稳定，不能缺像素；帧间SOF可更新身份。小图已覆盖无行/场消隐的背靠背帧，720p使用1280×720有效区、1650×750总光栅。

## 输出调度与故障

窗口和Sobel寄存器与完整坐标调度并行工作：下一输入行x=1对应上一行x=0的黑边界；x>=2时内部像素使用已算出的Sobel值；行末补右边界，EOF后补最后一行。冲刷尾部期间可以接收下一帧初始行，尾部携带旧身份，新输入携带新身份，不能提前替换。

单独边缘级从灰度EOF采样到EDGE EOF为 `WIDTH+3` 拍。在当前整合路径中，从原RGB输入EOF到EDGE EOF为 `2×WIDTH+9`，720p为2569拍；首次EDGE像素相对原输入SOF为 `2×1650+9=3309` 拍。base_*仍为B2b的1655拍首像素、1285拍EOF延迟。具体行尾/帧事件记录在 `timing.csv`，这是内部像素调度，不是完整HDMI节拍契约。

| error_flags位 | 边缘级含义 |
|---|---|
| 8 | 帧内等待输入达到MAX_IDLE_CYCLES |
| 9 | 行内缺有效像素 |
| 10 | 坐标/帧标志错误，或帧中epoch/frame/cfg/color改变 |
| 11 | 需要内部Sobel像素时，其valid、坐标或frame_id与输出槽不匹配 |
| 12 | 外部或上游配对链abort通知 |

遇错清空边缘流水线，保持一拍内部复位，随后忽略非SOF残留，等待后续合法SOF。触发错误的SOF不作为恢复帧。窗口RAM无需复位，恢复帧前两行重建历史；已输出像素不能撤回，下游必须处理out_abort。边缘级自身出错时base_*可能仍继续当前帧，不能因base_valid为1就忽略整合层abort。粘滞错误位保持便于诊断，不永久阻止恢复后的输出。

## 验证与资源

Python整幅灰度图使用SciPy Sobel算子获得带符号梯度，独立应用绝对值、阈值及黑边界。RTL逐像素同时核对原图、灰度、真实C mask和EDGE，并检查两组输出各自完整身份/坐标/帧标志。

- 算术5308向量：全部512种黑白3×3邻域、随机邻域、均匀及定向梯度，阈值0/128/2047及实际幅值−1/等于/+1；同时核对Gx/Gy/幅值/二值输出和无效清零。
- 边缘级12项故障/恢复：坐标、身份各字段、提前SOF、错EOF、缺像素、等待超时、输出活跃时abort/复位、Sobel结果缺失；恢复后以反相阶跃图检查边缘位置及旧缓存清除。
- 联合链12项小图故障恢复、真实FIFO容量不足、720p运行中复位后完整帧恢复；原图/灰度/mask和EDGE都校验。
- 完整路径：3×3和16×12零消隐、16×12带消隐、阈值0和2047，各6帧；6帧720p默认阈值128。覆盖色块、复杂彩色、灰阶、目标变化、贴边噪点、ID回绕及epoch变化。
- 检查器负例故意破坏EDGE期望像素，必须报告 `EDGE pixel mismatch`，不能只依赖程序返回码。

独立综合命令：

```powershell
python synthesis/check_edge_stream_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

本机TD6.2.168116、PH1P35MDG324 -3、75MHz暂定约束：1719寄存器、1754 LUT、估计1382 Slice、7 ERAM、0 DSP、0锁存器。相比B2b增加830寄存器、877 LUT、估计651 Slice、2 ERAM；包括两组输出全部可观察的测试包装。ERAM映射为原RGB 3+C滤波2+灰度窗口2。setup余量2.826ns、hold余量0.292ns、TNS=0；唯一综合警告为独立包装124个端口未分配板级LOC。

小型证据保存在 `reports/b2c_20261014/`；大mem、逐像素流、波形及工具库保留build，不上传。当前只有仿真和独立综合，没有新bit、完整板级时序或板测结论。B2d需在保持真实C输入和资源约束的前提下，对齐四路后再选择模式；A负责最终HDMI供数/CDC/DDR来源绑定及整板验证。
