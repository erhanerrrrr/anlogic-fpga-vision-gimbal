# B2d：真实 MASK 与四模式统一像素流

B2c 的完整仿真及边缘图片已于 2026-10-14 由使用者验收。本阶段把 RAW、GRAY、EDGE、真实 C 滤波 MASK 汇合为同一节奏的像素流，并提供模式选择与随像素传递的模式编号。

## 一键复跑

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b2d.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

先执行故障/复位恢复，再执行小图与完整六帧 720p。最后必须出现 `PASS: B2d checks completed.`。完整仿真可能需要二十分钟左右，以最终 PASS 为准。`--small-only` 是快速排查入口，不代替完整验收。Python 依赖沿用 `requirements-b1a.txt`，不需要新软件。

图像位于 `build/four_mode/run_.../native_720p/`：`02_selected_actual.png` 是第 2 帧的真实 MASK 显示，目标区域白、其余黑。`02_rgb_actual.png` 是输入原图；`02_mask_reference.png` 是独立参考；`02_diff.png` 是四路候选联合差分，应全黑。所选输出还独立与 `selected_reference.png` 比较。

## 为什么不用 B2c 的两组输出直接切换

B2c 将 Sobel 串在 C 滤波和灰度之后，因此 EDGE 晚于 RAW/GRAY/MASK。B2d 改为并行：

```text
                   ┌→ 原 RGB 入队 → 按真实 C 坐标出队 ── RAW + MASK ─┐
原始 RGB888 ────────┤              ↑                              │
                   ├→ C 分类 → C 多数滤波 ─────────────────────────┘
                   │                                             │ 同拍检查
                   └→ 灰度 → 两行灰度窗口 → Sobel / 补黑边 ─ EDGE ─┤ 坐标、标志、身份
                                                                 ↓
                                                  公共一级寄存：RAW / GRAY / EDGE / MASK
                                                                 ↓
                                                     模式选择 + out_mode
```

复用 B2a 的真实 C 配对和唯一一份 RGB 队列；复用 B2c 边缘级，原文件均不修改。冻结的 H4E C 分类和滤波保持原样。两个分支消费同一份原彩色输入，显示模式不影响 C 的检测数据。

本版本 C 配对和并行 EDGE 的完整输出调度相同。汇合器对 valid 是否相同，以及有效像素的 x/y、SOF/EOL/EOF、epoch/frame/cfg/color 逐拍检查。不是只凭一个固定延迟猜测对齐；任何不同都发出 abort。改变 C 或窗口调度时，必须重新验证此契约，不能删掉断言或仅改常量。

输出 GRAY 在共用 RGB 出队后再以移位加法计算一遍，避免把额外 8 位灰度扩进每个 RGB FIFO 字。它增加少量 LUT，不增加 RAM 或 DSP。所有四路候选和最终 out_rgb 在同一 out_valid、坐标、身份上有效。

## 接口给 A

入口 `rtl/video_four_mode_stream.v`；编译只使用 `b2d_sources.f` 列出的源，不能递归加入其它历史同名模块。单时钟，上升沿采样，低有效异步复位，复位释放/CDC 由 A 处理。

| 字段 | 宽度和规则 |
|---|---|
| in_rgb / in_valid | RGB888 / 1，无 ready；有效像素行优先、行内连续 |
| in_x / in_y | 各 11，SOF=(0,0)，EOL=(W−1,y)，EOF=(W−1,H−1) |
| in_epoch / in_frame_id / in_cfg_id / in_target_id | 32 / 32 / 16 / 2；一帧稳定；target_id 指颜色，不是物体身份 |
| min_main / min_diff_1 / min_diff_2 | 各 8，C 活动阈值，一帧稳定 |
| in_mode | 2，**已经确定的源帧模式**，在输入 SOF 采样，至该帧 EOF 保持；帧中改变报错 |
| out_rgb / out_mode | 24 / 2，已经选好的显示像素和实际模式，同拍有效 |
| out_raw_rgb / out_gray_rgb / out_edge_rgb / out_mask_rgb | 各 24，四种同坐标候选，便于集成检查；也共享下述 metadata |
| out_valid / out_sof / out_eol / out_eof | 各 1，完整 W×H，包括黑像素；无效时全部输出像素/坐标/身份/模式/标志置零 |
| out_x/y、out_epoch/frame_id/cfg_id/target_id | 宽度与输入相同，跟随当前像素，不能拿实时输入编号替代 |
| out_abort | 当前未完成帧失效，可能多拍；下游丢弃已开始接收的该帧 |
| error_flags | 16 位粘滞错误，外部 rst_n 清除；故障恢复不会清除历史诊断 |
| fifo_used / fifo_peak | 各 16，RGB 队列当前/自外部复位以来最大像素数；故障清队列但保留峰值 |

模式：0 RAW，1 GRAY，2 EDGE，3 MASK。MASK 由真实 C 分类后上下 4 行屏蔽、3×3 至少 5 点多数滤波得到；1 显示白色、0 显示黑色，不是棋盘或占位图。GRAY 和 EDGE 的精确整数公式、阈值、黑边界沿用 B2b/B2c。THRESHOLD 默认 128，为 11 位编译参数。

`in_mode` 不是按键原始电平，也不是模式请求。B3 才负责消抖、请求排队以及“请求与 SOF 同拍留到后一 SOF”的规则。本阶段验证已确定的逐帧模式，不能将它标为按键切换验收通过。用两个 2 位帧描述符保存模式；下一输入帧已开始、上一帧仍在输出时，旧尾部仍带旧模式。

## 延迟、缓存和输出节奏

当前支持 WIDTH/HEIGHT 3..2048，行内连续。默认 WIDTH=1280、HEIGHT=720、GUARD_ROWS=4、MAX_IDLE_CYCLES=4096。正常输入在行间可空闲，但一帧进行中不能等待达到 MAX_IDLE_CYCLES。当前完整联合验收采用 1650×750 总光栅；小图还验证零消隐连续帧。

- 四种模式共用首像素延迟 `HT+5` 拍，当前为 **1655** 拍。
- 输入 EOF 到输出 EOF 共 `WIDTH+5` 拍，当前为 **1285** 拍。
- 输出最末行通过尾部冲刷补齐；它可能与前一输出行连续，不能假设输出始终保持 370 拍行消隐。换模式不会改变这个节奏。
- RGB FIFO 正常峰值为 `WIDTH+4`，720p 实测 **1284** 像素。默认深度 `2^ceil(log2(WIDTH+8))`，720p 为 **2048×24 位**，保留余量并拒绝满队列时继续写入。
- RGB 帧身份采用两份 82 位描述符，模式再用两份 2 位描述符；不把身份附到每个 FIFO 像素。
- 灰度窗口为两行 8 位，即 `2×WIDTH×8` 位；C 窗口沿用两行 1 位。没有第二份 RGB FIFO，没有整帧缓存。

`timing.csv` 保存 RTL 实际输出的 SOF/每行 EOL/EOF 事件。报告中的 `frame_timing.csv`、时序图把这些实际事件与 TB 的已知输入光栅相对照。不能把滤波后 out_valid 接回 DDR 读请求；这仍是内部像素流，A 负责 HDMI 固定光栅供数、跨时钟、DDR 与来源绑定，并与本模块联合验证容量和欠读。

## 故障与恢复

发生输入协议错误、行内缺像素、容量不足、超时、两路错配或外部 abort 时，两条计算流水线、RGB 队列和模式描述符一起清空。灰度/C RAM 不复位，后续新 SOF 会重建有效窗口。非 SOF 残留忽略；故障当拍的 SOF 不视为恢复帧，须等待 out_abort 结束后发送新合法 SOF。不能撤回已输出像素，因此 A 必须处理 out_abort。

| error_flags 位 | 含义 |
|---|---|
| 0 | B2a 输入坐标、标志、身份或阈值不一致 |
| 1 | B2a 行内缺像素 |
| 2 | RGB FIFO 容量不足 |
| 3 | C 要求 RGB 配对时队列空 |
| 4 | C mask 坐标、标志或身份不匹配 |
| 5 | B2a 流等待超时 |
| 6 | 外部 abort |
| 7 | B2a 帧描述符容量不足 |
| 8..12 | 被保留的 B2c 边缘级诊断：超时、缺像素、协议、内部 Sobel 对齐、外部 abort；本包装不向边缘级单独发送 abort，故 bit12 通常为0 |
| 13 | RAW/MASK 和 EDGE 的 valid、坐标、标志或身份不同 |
| 14 | in_mode 在同一输入帧中改变 |
| 15 | 模式描述符不足/溢出 |

错误位表示已捕获的检测结果，并非承诺只置一个根因位。例如内部 Sobel 缺结果会先抑制 EDGE valid，汇合器可能先记录 bit13 并共同复位，内部 bit11 不一定来得及保留。整体仍须报错并完整恢复。

## 验证与综合记录

- 小图 3×3、16×12，零消隐/有消隐，阈值 0/128/2047。三组额外模式轮转保证每个小图场景都在四种选择下执行。
- 六帧 720p：四路候选与所选画面逐像素核对独立模型，坐标、全部身份、模式、SOF/EOL/EOF 逐像素断言；包含目标移位/选色变化、消失、贴边、ID/cfg 回绕、epoch 变化。
- 联合链 16 个小图异常/恢复案例、FIFO 容量不足、完整 720p 帧中复位恢复。涵盖帧中改模式、丢 EDGE 输出、身份错配和内部 Sobel 输出异常。
- 故意破坏参考 EDGE 首像素，要求检查器确实报告错；最终 PASS 必须同时满足退出码、PASS 标记和无模拟器错误。
- B2c 的 5308 个算术向量和独立边缘级故障测试对应复用且未改的 RTL；本阶段保留其证据，不冒称重复运行。

独立综合：

```powershell
python synthesis/check_four_mode_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

本机 TD 6.2.168116，PH1P35MDG324 -3，暂定 75 MHz：**1879 寄存器、2210 LUT、估计 1648 Slice、7 ERAM、0 DSP、0 锁存器**。含所有候选、所选像素和身份均可观察的测试包装。相对 B2c 增加 160 寄存器、456 LUT、估计 266 Slice，ERAM/DSP 不变；RAM 映射仍为 RGB 3+C 2+灰度窗口 2。

setup/hold 余量为 +0.288/+0.292 ns，TNS=0。setup 余量较小，独立通过不代表整板时序通过，A 集成后须重新约束和检查。唯一工具警告是独立包装 124 个端口没有板级 LOC。整板原有模块可能被替代/复用，不能把独立报告的 7 ERAM 机械叠加到整板报告。

小型日志、图片和哈希见 `reports/b2d_20261014/`。本交付没有新 bit、没有上板结论；身份是仿真合成标签，真实 capture-v1 DDR 来源绑定仍由 A 实现。完成使用者复跑与看图之后，再推进 B3 按键/模式请求层。
