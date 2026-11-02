# B4b：延迟文字面板的独立仿真

`video_latency_text.v` 在 x176..879、y208..223 和 x16..719、y232..247 画两行 16×16 字体。第一行位于模式标签右侧，第二行在目标区域上方，不遮挡 B3g6 测试目标框。它只消费 B4a 的完整统计包，不自行测量延迟。输入在有效显示 SOF 整包锁存；统计值在帧中途改变时，两行仍显示该帧起始快照。流中止或复位清空快照。其它位置的 RGB/标记保持透传；面板与正式 Logo 的 x1104..1263、y16..175 不重叠。

第一行显示测量类型、样本数、最小延迟；第二行显示平均和最大延迟。`SOF` 是采集 SOF→显示 SOF，`RES` 是采集 EOF→识别结果，`EXT` 是外部实测。数值均明确标为 **HEX US**：十六进制微秒，32 位最大值以 `FFFFFFFF` 完整显示，不发生十进制溢出。无完整窗口或保留类型显示 `LAT:N/A`；零值仍显示 `00000000`。只有 `synthetic_source=1` 才显示 `SIM`；测试台使用合成测量，正式接 A 的真实测量时应为 0。

复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b4b.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

本机 2026-10-19 更新布局后测试通过。四帧依次为 N/A、普通 `RES` 数据、`EXT` 最大值、`EXT` 零值；后两次统计更新发生在当前帧第二行面板绘制中途，用来检验整帧快照。1,032,192 个 RTL 输出像素与独立 Python 字体参考零差异，ModelSim 零错误、零警告。`build/b4b_latency_text/` 含实际图、参考图、差分图和摘要。

独立综合复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b4b_latency_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'
```

本机 TD 6.2 的 PH1P35MDG324 -3 更新布局后独立综合通过。包含测试观测包装和字体：387 寄存器、574 LUT、379 Slice、0 ERAM、0 DSP、0 锁存器；暂定 75 MHz 下 SWNS +2.955 ns、HWNS +0.502 ns。日志存在未驱动网络按 0 和测试端口未指定板级引脚告警。B4c 已将面板放入 B3g6 后级；完整闭环资源与整板时序仍需另测。B4a 统计核资源另见 `B4a_README.md`；两份独立资源不能直接相加推算整板净增量。
