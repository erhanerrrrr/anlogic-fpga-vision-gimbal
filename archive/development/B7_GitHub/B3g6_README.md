# B3g6：同一像素时钟域的显示与 H4E 闭环

rtl/video_b3_h4e_sameclk.v 实例化 B3 显示链与未修改的 H4E 选区模块，将正式 detect_* 滤波掩膜接入 H4E，再把结果反馈到动态框和文字。H4E 本身没有 epoch 端口；本封装在掩膜 SOF 锁存同一来源的 epoch/frame_id/cfg_id/target_id，只在 H4E 结果身份匹配时发布携带该 epoch 的结果。显示层仍只在显示 SOF 选择四项身份完全一致的结果。

复跑命令：

    & 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3g6.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'

成功标志：PASS: B3g6 same-clock closed-loop epoch checks completed. 四次显示同一个 frame_id=42，前两次 epoch=9，后两次 epoch=10；期望依次为 WAIT、VALID、WAIT、VALID。仿真输入仍是红色 100×100 矩形。第三次 WAIT 保留上一条结果的 frame/cfg 诊断文字，但不画旧框；这是 docs/B1a_interface.md 已约定的行为。独立参考图逐像素核对实际 RTL 图，并检查 H4E 结果 epoch、来源包、帧内模式和状态不变。

本机 ModelSim 四帧合计 1,873,920 像素，零差异，零错误、零警告。第一次独立参考未考虑第三帧保留旧结果的诊断身份，导致文字区 144 像素差异；RTL 自检始终通过。按已冻结的 B1a 语义修正参考后，复用同一份已完整生成且源码哈希未变的 RTL 原始输出重新比对，四帧均零差异。原始运行和差异图留在 build/b3g6_sameclk_closed_loop/。

独立综合复跑命令：

    & 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\synthesis\check_b3g6_closed_loop_synthesis.py' --td 'D:\TD\bin\td_commands_prompt.exe'

本机 TD 6.2 的 PH1P35MDG324 -3 独立综合通过。含测试观测包装，用户复跑为 6741 寄存器、11022 LUT、7751 Slice、10 ERAM、0 DSP、0 锁存器；暂定 75 MHz 的 SWNS +0.371 ns、HWNS +0.292 ns，TNS 0。此前本机一次同源综合为 7783 Slice、10 ERAM、SWNS +0.765 ns；两次映射有波动，余量都较小。与 B3g5 使用的测试包装不同，不能用 Slice 差值当作新顶层的准确净增量。日志保留未驱动网络按 0 处理和未分配板级引脚两项告警，板级集成时需核对。

此封装只适用于同一像素时钟域。A 仍须提供真实采集 epoch/ID，保证前一 H4E 结果被消费前不开始下一来源帧，处理跨域结果与超时，并安排同源帧重复显示。当前仿真身份由测试台给定，没有整板综合、布局布线、bit 或上板结论。
