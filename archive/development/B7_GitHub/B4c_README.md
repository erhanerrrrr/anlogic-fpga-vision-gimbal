# B4c：B3g6 闭环加延迟统计/OSD

`rtl/video_b4_h4e_sameclk.v` 保留 B3g6 源码不变，在其内部像素输出后加入 B4a 八样本统计和 B4b 两行文字面板。来自 A 的 `latency_valid` 是同一像素时钟域中的**单拍测量事件**，`latency_us[31:0]` 单位微秒，`latency_kind[1:0]` 的 0/1/2 分别为采集 SOF→显示 SOF、采集 EOF→识别结果、外部实测。`latency_synthetic=1` 才显示 `SIM`。A 应在测量失效、来源超时或时基重置时拉 `latency_clear`；流中止也清空统计。跨域时仍需整包 CDC，不能直接把多位测量值接到像素域。

新增 OSD 比 B3g6 多两拍像素流水。`epoch/frame/cfg/target/mode` 和标定、跟踪、目标结果显示快照随像素一起延迟两拍；区域结果单拍事件、错误和 FIFO 诊断维持 B3g6 原节奏。A 接最终显示时序时需考虑新增两拍，不得据此改变 DDR 读请求。严格同源四字段匹配和单个在途 H4E 来源限制仍见 `docs/B3g6_to_A_handoff.md`。

两行分别位于 x176..879/y208..223 和 x16..719/y232..247；当前 976×480 测试中的绿色框不被面板盖住，正式 Logo 区域与面板不相交。显示数值为明确标注的 HEX US，不需要 32 位十进制除法。无完整八样本窗口显示 `LAT:N/A`。

复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b4c.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

本机 ModelSim 四帧、共 1,873,920 像素零差异，零错误、零警告；C 区域结果事件、epoch 绑定、画面来源字段、帧标记和结果快照均由 TB 自动断言。四帧依次显示 N/A、RES 普通数据、EXT 最大 32 位值、EXT 零值，叠加 B3g6 的 WAIT/VALID/WAIT/VALID。实际 RTL 图、参考图、差分图和源哈希在 `build/b4c_sameclk_latency/run_20261019_205411/`。

显式源列表为 `b3g2_sources.f` 的 27 个文件，另加 H4E `h4e_region_select.v`、`rtl/video_b3_h4e_sameclk.v`、`rtl/latency_window_stats.v`、`rtl/video_latency_text.v`、`rtl/video_b4_h4e_sameclk.v` 和 `sim/tb_b4c_sameclk_latency.v`；`run_b4c.py` 使用并记录了完整清单。当前测试使用合成来源 epoch 和合成延迟，尚无真实 A 测量、整板资源/时序、bit 或上板结论。资源以组合顶层报告为参考，不能把 B4a/B4b 两份独立 Slice 数机械相加。

组合顶层独立综合复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b4c_closed_loop_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'
```

本机 TD 6.2 的 PH1P35MDG324 -3 独立综合通过：含测试观测包装共 7,858 寄存器、12,487 LUT、8,603 Slice（器件 21,216 的 40.55%）、10 ERAM、0 DSP、0 锁存器；暂定 75 MHz 时 SWNS +0.925 ns、HWNS +0.292 ns。与 B3g6 上一次不同测试包装/映射结果相比约多 852 Slice、ERAM 不变；该差值只是粗略参考，不能当整板净增量或证明板级布局布线通过。B3g6 与 B4c 的时序余量有映射波动，不能因本次 SWNS 较大就推断加入 OSD 改善了时序。报告仍有未驱动网络按 0、测试端口未指定板级引脚告警。

首次组合综合的临时测试包装把延迟测量拆成独立输入端口，造成 164 个 IO 超过器件最大 160，停在 Map IO；改为与 B3g6 一致的寄存器装载包装后重新综合通过。此问题仅属于独立资源测试包装，不影响已通过的 B4c 视频仿真。

用户复跑仿真与综合均确认成功。最新用户综合记录为 8,622 Slice、10 ERAM、0 DSP、SWNS +0.841 ns、HWNS +0.292 ns；与前一次同源码本机综合有 19 Slice 的映射差异。证据摘要见 `reports/b4c_20261019/delivery_manifest.json`。
