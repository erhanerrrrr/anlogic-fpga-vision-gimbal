# B4e：三个帧率的低资源十进制转换

任务书要求 B 显示 A 提供的真实来源帧率、显示刷新率和识别结果率，但统一接口 v1 尚未冻结这三个字段的位宽及更新节奏。B4e 先采用**待 A 适配确认**的局部表示：三个无符号 16 位 centi-FPS 值（每单位 0.01 帧/秒），例如 6000→60.00 FPS、2997→29.97 FPS。测量、时间窗口和跨域传输仍由 A 负责；B4e 只做格式转换，不把显示刷新次数伪装成来源帧率。

`rtl/osd_fps_decimal.v` 用一个 double-dabble 转换器依次处理三个字段，每字段 16 拍，共 48 拍；不使用硬件除法、乘法或 RAM。每个输出是五位 BCD，后续 OSD 在末两位前加小数点。输入最大 65535 可完整显示 655.35 FPS；超出此可表示范围的测量值须由 A 的适配层显式报告溢出并饱和，不能回绕。无效标志和异常计数将在后续性能面板一起处理。有效显示 SOF 可重新启动转换，流中止会清空输出。

复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b4e.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B4e centi-FPS decimal conversion checks completed.`。本机 ModelSim 零错误、零警告；覆盖 0、60.00、29.97、最大 655.35、转换中重新开始及 flush 后无旧数字。此步还未接性能 OSD 或 B4c 顶层，测试输入为合成值，无板测/bit 结论。

独立综合复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b4e_fps_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'
```

本机 TD 6.2 对 PH1P35MDG324 -3 独立综合通过：136 寄存器、119 LUT、79 Slice、0 ERAM、0 DSP、0 锁存器；暂定 75 MHz 下 SWNS +7.861 ns、HWNS +1.077 ns。113 个测试顶层端口未分配板级管脚；这是单独转换核的资源，不是合入 B4c 后的净增量或整板时序。
