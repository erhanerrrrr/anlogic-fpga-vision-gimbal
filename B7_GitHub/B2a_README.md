# B2a：真实 C 滤波掩膜与 RGB 配对

本阶段只完成 RGB 与真实 C 掩膜配对。B1b字体图片已由使用者确认。B2b的RAW/GRAY、B2c的EDGE、B2d的四模式整合随后分别验证。

## 先运行这一条命令

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b2a.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

最后应显示 `PASS: B2a checks completed.`。脚本先做故障/恢复检查，再做小图和6帧完整720p配对；需要几分钟。可加 `--small-only` 仅排查小图，但小图通过不能代替完整验收。新报告分别保存在 `build/rgb_mask_faults/run_...` 和 `build/rgb_mask_pair/run_...`，不覆盖旧结果。

完整图像在后一目录的 `native_720p/`，每个场景包含原图实际输出、掩膜实际输出、独立参考及差分。掩膜来自真实RTL的分类和滤波，不是棋盘测试输入。默认上下四行在检测分支屏蔽，最外一圈滤波输出置零；RGB保持原值。

## 源码与接口

新增 `rtl/video_rgb_mask_pair.v`；显式源列表 `b2a_sources.f` 直接引用冻结H4E的 `color_classifier_runtime.v` 和 `mask_majority_3x3.v`，两者未改动。必须在整合仓库中运行，保留相邻的 `boards/` 路径。不要递归编译所有RTL，也不要在已有分类/滤波链之外再并联复制本模块后机械相加资源。

本阶段使用H4E已验收分类/多数滤波算法：可选R/G/B通道，运行时三个阈值，3×3至少5点，边界输出0。调用者在SOF给出配置，整帧保持；H4E设置是红色、24/16/16、cfg=1。测试中的其它配置仅验证接口行为。

| 端口 | 规则 |
|---|---|
| clk/rst_n | 单时钟，上升沿；低有效异步复位；A负责跨域与同步释放 |
| in_valid/rgb/x/y/sof/eol/eof | RGB888；11位坐标；逐行顺序；mask为0仍输出valid像素；无ready反压 |
| in_epoch/frame_id/cfg_id/target_id | 32/32/16/2位，必须与输入RGB真实绑定并整帧稳定 |
| min_main/min_diff_1/min_diff_2 | 8位，整帧稳定；在新SOF可换配置 |
| stream_abort | 同步故障通知，清空本模块及内部C滤波的在途状态；不要接异步毛刺源 |
| out_valid/rgb/mask/x/y/sof/eol/eof | RGB和滤波mask同拍、同坐标，完整W×H输出，mask为0不丢像素 |
| out_epoch/frame_id/cfg_id/target_id | 对应配对像素所属输入帧，随像素输出 |
| out_abort | 遇错后通知下游丢弃当前未完成帧；已经输出的部分不能撤回 |
| error_flags | 8位粘滞诊断，复位清除；恢复后的正常输出不会被历史错误位永久屏蔽 |
| fifo_used/fifo_peak | 16位像素数；used遇错清零；peak保持到复位 |

这是B2a局部配对接口。H4E只有刷新号时，A可以将epoch固定为0、frame_id接刷新号，并明确仍为 `h4e-refresh-v1`。测试使用合成来源标签，含ID回绕和epoch变化；虽然本模块保留epoch，不代表A已经实现DDR缓存与真实采集来源绑定、跨域或整套 `capture-v1`。B1a/B1b的OSD仍使用原刷新快照规则，本阶段不把它改为同源帧结果叠加。

C原滤波没有epoch端口：本模块按严格像素顺序和帧描述队列保留epoch，校验C输出的frame/cfg/color以及坐标/标志；复位/异常同时清空C与队列。不能把本模块作为任意乱序结果的匹配器。

## 缓存与输出节奏

缓存只存24位RGB，坐标和标志由输入顺序检查器验证，输出再与真实C的坐标/标志核对。每帧只保存一次82位身份，两份描述允许上一帧冲刷时下一帧进入；不会为每个像素重复保存身份。

输入下一行x=1时C具备上一行首窗口，此前最多积压一行。加上分类、滤波寄存器和同步RAM读取，检查得到峰值 `WIDTH+4`，720p为1284像素。默认深度 `2^ceil(log2(WIDTH+8))`，720p取2048，逻辑容量49152位；两份帧描述为164位。没有整帧缓存。合法参数为WIDTH/HEIGHT 3..2048，MAX_IDLE_CYCLES至少2；自定义深度应至少WIDTH+5，当前默认还有额外余量。

输入行内必须连续，行间允许消隐；默认连续无输入/滤波进展达到4096周期会超时。已测720p的370周期行消隐/30行场消隐，以及小图零行/场消隐。大消隐超过约束、错误输入必须显式处理，不能默认为任意节奏都支持。空闲场间没有在途像素时不触发看门狗。

| 事件 | 本模块输出节奏 |
|---|---|
| 第一输入SOF | 接收RGB并保存本帧身份 |
| 下一行x=1进入 | 经过后续3拍得到配对的上一行x=0；720p首输出相对输入SOF为1654拍 |
| 普通行 | 输出W个连续有效像素，保持行序；中间消隐跟随真实C调度 |
| 输入EOF | 继续冲刷上一行右边界及最后一行；输出EOF在WIDTH+4拍后，720p为1284拍 |
| 下一帧紧接进入 | 上一帧剩余输出仍用旧描述，新帧身份独立保存 |

逐行事件记录见仿真的 `timing.csv`。输出valid不是原生HDMI DE；不能反馈为DDR读请求，不能将HS/VS简单延迟1654拍就声称完成显示定时。A需按已完成输出行/缓冲状态组织最终HDMI供数；后续模式链可能增加自己的行缓冲，届时重新联合计算。已有C定位可消费这份配对mask及其身份，但会比直接C输出多一拍，A/C整合时需要复验结果时序，避免重复实例化同一滤波器。

## 故障与恢复

| error_flags位 | 含义 |
|---|---|
| 0 | RGB坐标/帧标志顺序错误，或帧中身份/阈值改变 |
| 1 | 行内缺少有效像素 |
| 2 | RGB FIFO溢出；满时即便同时读也拒绝，避免同地址RAM行为依赖 |
| 3 | C输出到达但RGB FIFO为空 |
| 4 | C输出坐标/标志/身份与队首不符，或没有对应帧描述 |
| 5 | 在途帧无进展超时 |
| 6 | 外部stream_abort |
| 7 | 两份帧描述都占用时又要求新帧 |

任何故障使队列、顺序状态和C内部流水线共同清空，输出abort，下一拍保留内部复位，然后等待后续合法SOF恢复。若故障恰由新SOF触发，该SOF被丢弃，不能当恢复帧；A应丢弃该未完成帧。恢复前残留的非SOF像素忽略。历史error_flags保持便于诊断。没有整帧缓存，因此无法撤回故障前已送出的像素，下游必须响应abort；这些诊断尚未接入OSD文字。

故障检查含行内缺失、跳坐标、cfg/epoch/阈值改变、提前SOF、错EOL、停顿超时、显式abort、C端错坐标/无对应RGB、运行中复位及恢复；另用不足深度触发实际溢出。强制C端异常只用于TB，不改变生产RTL。

## 证据与资源

独立Python以整幅数组分类、卷积计算多数表决；ModelSim逐像素核对RGB、mask、坐标、全部标志及完整身份。包含黑白与阈值色块、目标移动/消失、贴边/噪点、三颜色、非法颜色、cfg与帧号回绕、epoch变化及跨帧尾部重叠。故意翻转期望mask验证检查器确实报错。另做720p运行中复位及完整帧恢复。

独立综合：

```powershell
python synthesis/check_rgb_mask_pair_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

本机TD6.2.168116、PH1P35MDG324 -3、75MHz暂定约束：747寄存器、684 LUT、估计589 Slice、5 ERAM、0 DSP、0锁存器。5块ERAM中RGB FIFO为3块，C行缓存为2块；setup余量3.332ns，hold余量0.457ns。唯一综合警告是独立观察包装123个端口没有板级LOC约束。资源包含装载/观察包装，与最终整板净增量不同；尤其C滤波已有的两块应共享或替换。

小型证据保存在 `reports/b2a_20261010/`。不上传build中的RGB流、mem、波形和工具库。B7/B1a/B1b/H4E历史代码和证据保持不变；没有新bit，未做整板时序或板测。使用者复跑通过后，下一步进入B2b，仅接RAW再接GRAY。
