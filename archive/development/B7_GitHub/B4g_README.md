# B4g：性能面板接入 B4c 的 720p 联合仿真

`rtl/video_b4g_h4e_sameclk.v` 在不修改已验证的 B4c、B3g6 源码的前提下，把 B4f 性能面板接在 B4c 视频输出之后。`performance_packet[87:0]` 必须由 A 在像素时钟域提供完整、稳定的同一测量快照；帧率与异常计数的真实测量、跨时钟域整包传输及无效/溢出判定仍待 A 的接口适配。合成数值通过 `synthetic_source` 明示为 `SIM INPUT`，不能称为真实板上帧率。

B4f 又增加两拍像素流水，所以 B4g 相对 B3g6 共增加四拍。epoch、frame ID、cfg ID、target ID、mode 和每像素结果/状态快照跟随像素对齐；区域识别结果事件、错误与 FIFO 计数仍沿用 B4c 的独立事件节奏。A 接入显示时序时要考虑新增两拍，但不应据此改变 DDR 读请求。严格同源四字段匹配与单个在途 H4E 来源限制仍见 `docs/B3g6_to_A_handoff.md`。

复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b4g.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

本机 ModelSim 对两帧 1280×720 视频共 1,843,200 像素逐像素比较，零差异；编译和仿真零错误、零警告。测试保留 C 的区域结果与同源身份断言，并检查像素坐标、SOF/EOL/EOF、目标结果快照和 FIFO。两帧分别为帧率无效以及 `60.00/59.94/29.97` FPS、异常计数 `1A2B3C4D`。第二帧输入测量包在帧中被清零，显示仍保持本帧 SOF 快照。官方 Logo、目标框和延迟面板一同与独立参考图比较。实际图、参考图、差分图、源码哈希与检查摘要在 `build/b4g_native720_performance/run_20261020_132405/`。

整合顶层独立综合复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b4g_closed_loop_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'
```

本机 TD 6.2 对 PH1P35MDG324 -3 独立综合通过：含与 B4c 可比的测试包装，共 8,904 寄存器、13,694 LUT、9,339 Slice（器件 21,216 的 44.02%）、10 ERAM、0 DSP、0 锁存器；暂定 75 MHz 时 SWNS +1.071 ns、HWNS +0.292 ns。相对已确认的 B4c 独立综合报告约增加 717 Slice、ERAM 不变。这里的差值包括测试包装中新接入的 88 位寄存器和逻辑映射变化，不能当作整板净增量；两次 SWNS 的大小变化也不能解释为 OSD 改善了时序。报告见 `build/b4g_closed_loop_synthesis/run_20261020_141614_211663/summary.json`。独立测试包装仍有未驱动网络按 0、测试端口未指定板级引脚告警。

这一步证明合成输入下的同钟域联合仿真和组合顶层独立综合；不能代表真实 A 帧率、整板布局布线时序、bit 或上板验证。

给 A 的字段、时序和板测检查见 `docs/B4g_to_A_handoff.md`；完整显式源列表见 `b4g_sources.f`。便于上传仓库的轻量证据包在 `reports/b4g_20261020/`，只保留 RTL 实际图、独立参考图、差分图、验证摘要和源码哈希；大型仿真/综合产物由上面的命令重建。
