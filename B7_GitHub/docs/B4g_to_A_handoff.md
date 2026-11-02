# B4g 给 A 的接入说明（2026-10-20）

## 已交付与入口

`rtl/video_b4g_h4e_sameclk.v` 是 B4c 闭环视频链后再加 B4f 性能文字的同像素时钟域顶层。它保留 RAW/GRAY/EDGE/MASK 四模式、C/H4E 区域结果、同来源帧目标框、状态文字、Logo 和延迟面板。`b4g_sources.f` 是联合仿真的完整显式源列表；`run_b4g.py`、`synthesis/check_b4g_closed_loop_synthesis.py` 是复跑入口。A 集成时从该顶层接视频流和状态输出，不能把 `out_valid` 直接当 HDMI DE 或 DDR 读请求。

B4g 与 B4c 相比只增加一个输入 `performance_packet[87:0]`；B3g6 的来源身份和单在途 H4E 约束仍按 [B3g6_to_A_handoff.md](B3g6_to_A_handoff.md) 执行。延迟统计输入 `latency_valid/us/kind/clear/synthetic` 与 B4c 相同。

## 性能包字段与单位

| 位 | 字段 | A 提供的含义 | 屏幕 |
|---|---|---|---|
| 87, 86, 85:70 | `src_valid`, `src_over`, `src_centi[15:0]` | 真实**来源完整帧**速率，单位 0.01 FPS | `SRC FPS:060.00` |
| 69, 68, 67:52 | `dsp_valid`, `dsp_over`, `dsp_centi[15:0]` | 实际显示刷新速率，单位 0.01 FPS | `DSP FPS:059.94` |
| 51, 50, 49:34 | `res_valid`, `res_over`, `res_centi[15:0]` | 新识别结果**事件**速率，单位 0.01 FPS | `RES FPS:029.97` |
| 33, 32:1 | `fault_valid`, `fault_count[31:0]` | A 定义并记录来源的异常累计次数 | `ERR HEX:1A2B3C4D` |
| 0 | `synthetic_source` | 1 表示仿真/注入数值，0 表示非合成数值 | 1 时黄色 `SIM INPUT` |

有效位为 0 时对应项显示 `N/A`；有效且溢出位为 1 时帧率显示 `OVER`。16 位 centi-FPS 最大表示 655.35 FPS。A 的测量值超过此范围须设置 `over=1` 并饱和，不能回绕成小数值。异常计数须饱和于 `FFFFFFFF`，不能回绕。`fault_count` 是十六进制显示，不能当十进制读；A 应在集成文档中列明哪些故障会增加它及清零条件。`N=010000` 和 HDMI 刷新次数不能冒充来源速率；重复显示同一来源帧也不能增加结果事件计数。

A 在同一像素时钟域提供整份测量包。跨域时用异步 FIFO 或握手邮箱整包传输，并确保显示 SOF 采样时包稳定；逐位同步 88 根线会导致字段混合。B4f 在 B4c 输出的有效 SOF 锁存整包，帧中输入变化在下一显示帧才体现。帧率的统计窗口、时基、清零/失效和溢出判断由 A 定义并交付测试。若尚无真实测量，应设置各 `valid=0`，不可填合成常数却把 `synthetic_source` 置 0。

## 时序与输出

B4g 的性能文字位于 x976..1279、y208..319；Logo 位于 x1104..1263、y16..175，两者不相交。性能面板相对 B4c 再增加两拍像素流水，合计相对 B3g6 增加四拍。`out_epoch/frame_id/cfg_id/target_id/mode` 以及 `out_calibration_status/out_tracking_status/out_snapshot_ready/out_result_packet` 与输出像素一起对齐。`region_result_strobe/packet/epoch`、`error_flags` 和 FIFO 诊断是独立事件/计数输出，不应按像素流水延迟来解释。A 须用最终板级时钟和管脚重新完成布局布线时序。

## 已验证的证据与限制

用户已复跑确认 B4g 两帧 1280×720 联合 ModelSim 仿真：1,843,200 像素对参考图零差异，编译和仿真零错误、零警告，FIFO 峰值 1284。第二帧在输入包中途清零后，显示仍保持同帧的 60.00/59.94/29.97 FPS 与异常计数。C/H4E 结果、Logo、目标框、延迟文字和像素身份同时检查。用户已复跑确认 TD 6.2 独立综合：9,339 Slice（44.02%）、10 ERAM、0 DSP；暂定 75 MHz 时 SWNS +1.071 ns。证据摘要见 `reports/b4g_20261020/delivery_manifest.json`。

这是带测试包装的独立综合，**不是**整板资源净增量、整板时序、bit 或上板结果。输入来源 epoch、帧率和延迟在测试中仍是合成数据；真实采集身份、A 的测量包、CDC、DDR/HDMI 调度和控制状态仍待 A 集成。当前统一接口 v1 尚未冻结性能包字段，A 合入前须在接口文档中确认或写适配层，不能直接假定板上已有这些 88 位。

## A 上板时请记录

1. 真实来源帧 ID/epoch 与显示帧 ID、配置 ID、目标颜色是否一致；同源重放时旧框是否只叠在同一来源图像上。
2. 四模式切换后的画面、标签、目标框、Logo 是否对应且无半帧跳变；`out_valid/sof/eol/eof` 到 HDMI 时序的缓冲/读调度。
3. 三个帧率的原始测量计数、统计窗口、有效/溢出位和屏幕值；停相机、停识别、复位后是否显示 `N/A`；真实数据时 `SIM INPUT` 是否消失。
4. 延迟种类及测量起止事件、时基、同一来源 ID；异常计数的来源与清零条件。
5. 实际像素时钟、布局布线时序、Slice/ERAM/DSP、`fifo_peak/error_flags`、源/结果超时和复位恢复日志；出现故障时回传相同字段及画面照片。
