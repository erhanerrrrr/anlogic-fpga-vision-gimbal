# B4f：性能文字显示仿真

`rtl/video_performance_text.v` 在画面右侧显示来源帧率 `SRC FPS`、显示刷新率 `DSP FPS`、识别结果率 `RES FPS`、异常计数 `ERR HEX`。合成数据时另显示黄色 `SIM INPUT`，避免把测试数值误认为板上实时测量。三路帧率共用 B4e 的十进制转换器，没有增加除法器或字库 RAM。

本模块局部接口是 88 位整包：`{src_valid,src_over,src_centi[15:0], dsp_valid,dsp_over,dsp_centi[15:0], res_valid,res_over,res_centi[15:0], fault_valid,fault_count[31:0],synthetic_source}`。`6000` 显示为 `060.00` FPS；无效显示 `N/A`；超出 16 位 centi-FPS 表示范围时由 A 设置 `over`，显示 `OVER`，数值应饱和而不能回绕。异常计数由 A 饱和而不回绕。A 还负责实际测量、窗口统计、同一时钟域或跨时钟域整包传输；这些字段尚待 A 的统一接口适配确认。模块在有效 SOF 锁存整包，此帧中途输入变化不会改变文字。输入和输出像素相差两拍，tag、SOF、EOL、EOF 一起对齐。流中止清除当前帧与十进制转换状态。

复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b4f.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B4f performance OSD image, frame snapshot and pixel metadata checks completed.`。ModelSim 编译和仿真都要求零错误、零警告。五组测试覆盖全部无效、60.00/59.94/29.97、655.35/0/0.01、溢出、`FFFFFFFF` 异常计数、帧中改包不跳字及 `SIM INPUT`。每组裁剪面板 304×112 像素与独立 Python 参考逐像素比较，结果与差分图保存在 `build/b4f_performance_text/run_*/`。

独立综合复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b4f_performance_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'
```

本机 TD 6.2 对 PH1P35MDG324 -3 的 B4f 独立综合通过：包括紧凑 IO 观测包装、共享 B4e 转换器及字体在内，共 422 寄存器、580 LUT、399 Slice、0 ERAM、0 DSP、0 锁存器。暂定 75 MHz 下 SWNS +3.378 ns、HWNS +0.502 ns。记录在 `build/b4f_performance_synthesis/run_20261020_131142_900810/summary.json`。测试包装本身也占资源，因此 399 Slice 不能直接加到 B4c 上作为整合净增量。报告中的未驱动网络按 0、测试端口未指定板级引脚告警与独立包装有关。

此步骤完成了 B4f 独立功能仿真和独立综合；尚未接入 B4c 顶层、未测真实 A 帧率接口、未做整板时序或上板验证。
