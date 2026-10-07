# B7 联合综合

```powershell
python .\run.py --synthesis-only --td 'D:\TD\bin\td_commands_prompt.exe'
```

从仓库根目录运行，或使用本目录的 `check_video_display_synthesis.py --require-timing`。TD 支持范围为比赛所用 6.2.1 系列，已验证版本 6.2.168116；目标 PH1P35MDG324，速度 -3，1280×720，OSD 开启，按键默认消抖 750000 周期。

`video_display_720p_probe_top.v` 使用 32 位可选探针保持内部输出可观测，仅用于独立综合。`video_display_synthesis.sdc` 的时钟暂定 75 MHz，输入输出延迟为 0；原始异步按键端口和复位设时序例外，内部同步器仍计时。此约束不能直接代替实际板级约束。

原 B7 已通过结果：28 ERAM20K、6 DSP、996 寄存器、4129 LUT、0 RTL 锁存器；综合后估计 setup +2.197 ns、hold +0.220 ns。FIFO/边缘/标签缓冲分别使用 23/3/2 个 ERAM；Logo/字模为组合逻辑。不同运行的映射结果可能变化，本次重排目录的结果另见 [验证记录](../reports/layout_verification.json)。

`audit_unused_nets.py` 对 SYN-5025 未驱动告警逐位核查；仅当诊断位没有引用时才允许通过。SYN-6021 无引脚位置约束仅针对本观察包装器说明；其他告警失败。默认严格入口同时检查资源布局、正式消抖计数器/同步器保留、无锁存器与非负时序裕量。

每次在 `build/video_display_synthesis/` 新建源码快照和 TD 工程。综合启动等待上限 900 秒；错误、超时、缺失报告和不满足要求均非零退出。`td_runner.py` 仅保留 TD 启动函数，不携带旧灰度工程入口。

这里的通过是综合后估计，尚未布局布线，也不代表已生成 bit 文件或上板通过。
