# B4a：延迟窗口统计（独立模块）

`latency_window_stats.v` 接收 A 的单拍 `sample_valid`、`sample_us[31:0]`、`sample_kind[1:0]`。kind=0 为采集 SOF 到显示 SOF，1 为采集 EOF 到识别结果，2 为外部实测展示，3 保留且忽略。A 必须保证时间基准和同源身份正确；本模块不制造测量值。输入数值单位为微秒。

默认每 8 个同类样本组成一个不重叠窗口，输出最小值、平均值（整数向下取整）、最大值、样本数 8 和类型。累积窗口不足 8 个时，`stats_valid=0` 代表 N/A；已有完整窗口的统计保持到下一完整窗口。切换类型或 `clear` 会清除旧窗口；长时间无样本的超时/清除须由 A 给 `clear`。零微秒是有效值，不等于 N/A。寄存器累加 40 位，平均只移位，无硬件除法或乘法；没有样本 FIFO。

这一步仅验证数据统计，**未接画面 OSD，也没有合入 B3g6 顶层**。之后需做帧 SOF 快照、数字字体和 Logo 优先级，并测独立/整板资源。测试输入均为合成值。

复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b4a.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B4a latency window checks completed.`。覆盖 N/A、0、最大 32 位值、整数平均、类型切换、无样本空闲、保留类型、清除。源列表见 `b4a_sources.f`；日志在 `build/b4a_latency_window/`。

本机 2026-10-19 首次复跑已 PASS，ModelSim 零错误、零警告。

独立综合复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b4a_latency_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'
```

本机 TD 6.2 对 PH1P35MDG324 -3 的独立综合通过：204 寄存器、277 LUT、181 Slice、0 ERAM、0 DSP、0 锁存器；暂定 75 MHz 约束 SWNS +7.957 ns、HWNS +1.077 ns。报告仍有 146 个测试顶层端口未分配板级管脚的告警。这是**单独统计核**的资源，不是合入 B3g6 后的准确净增量，也不是整板布局布线时序。
