# B3e：A云台状态显示

本小步只显示A发布的控制状态和舵机**命令脉宽**，不参与识别或机械控制。前面的B3d显示C标定状态；两者来源不同。A尚未提供真实板级状态，此处以明确标记的合成状态仿真。

## 一键复跑

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3e.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

最终标志：`PASS: B3e checks completed.`。图片在新生成的`build/tracking_text/run_时间/panels/tracking_panels.png`及`native_720p/00_follow_with_logo.png`。可以追加`--synthesis --td 'D:\TD\bin\td_commands_prompt.exe'`复跑独立综合。

## A→B接口

`video_tracking_text.v`输入38位同拍整包 `{status_valid,tracking_state[2:0],pan_limit,tilt_limit,pan_cmd_us[15:0],tilt_cmd_us[15:0]}`。`status_valid=0`显示UNKNOWN、限位和命令值显示NA，不借目标有效信号推测FOLLOW。A负责控制状态机、真实脉宽命令、跨域整包传输与可信标记。B只在有效**显示SOF**锁存整包，帧中不更换；与A同拍更新时，下游看到A寄存器的前一份稳定值。源图像配置/身份与控制快照是不同概念。

| tracking_state | 显示 | 含义 |
|---|---|---|
| 0 | OFF | 控制关闭 |
| 1 | REACQUIRE | 等待重获确认 |
| 2 | FOLLOW | A已进入跟随 |
| 3 | LOST HOLD | 目标丢失保持 |
| 4 | TIMEOUT HLD | 来源/结果超时保持 |
| 5 | FAULT | A报告故障 |
| 6/7 | RESERVED | 保留码，不按成功解释 |

PAN LIM/TILT LIM为各轴限位`Y/N`；两个命令字段以**十六进制微秒**显示为`PAN CMD US HEX`、`TILT CMD US HEX`，例如`05DC`=1500微秒。明确标为CMD，因为无编码器时不能声称实测角度或位置。选择HEX是为了避免增加十进制除法逻辑；给评委展示十进制数值可在后续统一OSD布局中评估资源后替换。

状态文字使用已有16×16统一字体，位置x16..975，第一行y160..175，第二行y184..199。B1文字y16..103、B3d文字y112..151、中央ROI y352..367均不重叠。组合顺序建议：选定模式RGB→B3c ROI→B3d标定文字→B3e云台文字→B1目标/Logo→现有结果文字。官方Logo在最后，保留不透明像素。

`in_tag/out_tag`默认为84位，同RGB、坐标、帧标志一起经过2级寄存器，避免模式/身份旁路错位。`out_tracking_packet`跟对应输出像素同步。显示abort清帧快照与像素流水，下一个有效SOF恢复；它不清A控制器，不能把视频中断自动当机械故障。复位隐藏直到有效SOF。

## 验证边界

使用合成A状态测试0..7全部码、未知、0/最大脉宽、两轴限位和同时限位、帧中状态变更、SOF/无效SOF、abort/复位。每帧逐拍检查84位tag、RGB、x/y、valid、SOF/EOL/EOF和原子状态包；画面与独立Python字符串及字体JSON逐像素比较，并与真实B1a Logo模块级联。完整720p仍是状态文字/Logo图层验证，不代表四模式/C滤波/A云台板级全链。

不新增图像FIFO/帧缓存、ERAM或DSP；数值HEX，不使用十进制转换器。独立综合使用分组读写测试包装，资源数字含测试包装，不可与别的模块数字机械相加作为整板占用。A接入时确认状态位编码、限制标志/脉宽语义、同域或CDC、显示SOF/abort、完整布线时序，再逐状态上板观察。无板时的验证等级为RTL仿真/独立综合；没有生成新bit或板测。
