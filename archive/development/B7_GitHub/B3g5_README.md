# B3g5：正式滤波掩膜端口

`video_four_mode_stream` 将真实分类加 3×3 滤波后的掩膜、SOF/EOL/EOF、坐标和来源身份作为 `detect_*` 端口输出；`video_frame_mode_stream`、`video_button_stream` 和 `video_b3_target_stream` 只逐层透传这些端口。`detect_valid=0` 时其他 `detect_*` 值不具意义。掩膜端口位于显示模式选择之前，因此四种显示模式共用同一份检测流。接口本身没有新增寄存器、FIFO、RAM 或算法实例，具体整板资源与时序仍须在 A 集成后实测。

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3g5.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B3g5 public mask port video checks completed.`。测试台只用顶层 `detect_*` 端口连接未修改的 H4E 选区模块，已没有内部层级掩膜引用。测试与 B3g4 相同：同一合成来源帧显示两次，第一遍 WAIT，第二遍出现目标框。本机 ModelSim 两帧 936,960 像素与独立参考逐像素一致，0 errors、0 warnings；两张实际图与 B3g4 的 SHA256 完全相同。运行记录位于 `build/b3g5_formal_mask_port/run_时间/`。

这是同一像素时钟域的可综合掩膜连接。`epoch=9` 和 `frame_id=42` 仍是测试台输入；H4E 结果本身不带 epoch，A 仍须绑定真实采集身份、跨域原子传输结果、处理超时及安排同源重复显示。这里没有 C+B 整板综合、布局布线、bit 或上板验证；不能把已有 B3g2 独立综合数字视为整板资源。

资源检查可单独复跑：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b3g5_region_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'
```

本机 TD 独立综合把正式掩膜端口接到未修改的 H4E 选区模块，并同时观察显示链和选区输出。最终测试包装将观测数据分组寄存，避免大型观测 mux 直接接到输出引脚。资源为 **6850 寄存器、10918 LUT、7694 Slice、10 ERAM、0 DSP、0 锁存器**；暂定 75 MHz 的 SWNS +1.060 ns、HWNS +0.292 ns、TNS 0。最差路径从显示链的 `pair/out_abort_reg` 到 H4E 的 `root_depth_reg`。与 B3g2 的不同包装相比约多 1091 Slice、3 ERAM，不能当作整板净增量。

旧测试包装的一次复跑出现 SWNS -0.255 ns，最差路径终点是测试观测引脚 `out_probe[11]`；更早一次同包装 SWNS +0.641 ns，显示独立综合映射存在波动。改为分组寄存观测后重新综合通过，旧失败报告保留在精简证据包中。测试包装中 H4E 结果供观测，未反馈给显示链；两帧仿真单独验证了反馈显示。综合日志仍保留未驱动网络按 0 处理及未分配板级引脚告警，A 集成时应核对。精简报告在 `reports/b3g5_20261019/`。
