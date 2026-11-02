# B1b：动态坐标、目标状态与诊断文字

前置：B1a已完成本机仿真、独立综合，并由使用者确认输出图片正确。B1b是新的检查点，需要使用者重新运行并确认图片，不能把B1a的确认当成本阶段确认。

本阶段新增入口为 `rtl/video_target_info.v`，复用原封不动的B1a核心及同一份Logo ROM，再加 `video_result_text.v` 和共享十进制转换器 `osd_decimal_fields.v`。明确编译源列表为 `b1b_sources.f`；不能递归编译全仓库。

## 现在先做什么

在原FPGA工作区PowerShell终端运行：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b1b.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

脚本先检查字库全部4096种字符/行组合，再检查中断/复位恢复、十进制转换和完整17帧720p图像，最后应显示 `PASS: B1b target text checks completed.`。本阶段完整仿真比B1a慢，需要几分钟。输出在新的 `build/target_info/run_.../`，旧结果不覆盖。

通过后查看 `02_normal_mid_update_actual.png`、`04_invalid_clear_actual.png`、`10_maximum_fields_actual.png`。正常场景应显示X:0149、Y:0249、AREA:0010000；无效场景显示INVALID、X/Y/AREA为NA；最大值测试显示AREA:1048575、SLOTS:255、COMPONENTS:4095。最大值是字段位宽压力测试输入，不代表720p真实区域面积可以超过921600。

## 字段与含义

| 行 | 内容 | 显示规则 |
|---|---|---|
| 1 | TARGET、COLOR | READY且目标有效为VALID；READY但目标无效为INVALID；结果未就绪/编号或配置不匹配为WAIT；颜色是RED/GREEN/BLUE，不是物体身份 |
| 2 | X、Y、AREA | 十进制，分别4/4/7位，带前导零；无效时显示NA，防止把零坐标看成左上角目标 |
| 3 | RESULT HEX、CFG HEX、DISPLAY HEX | 完整8/4/8位十六进制；RESULT是识别结果所属显示刷新号，DISPLAY是当前显示刷新号 |
| 4 | REASON、SLOTS、COMPONENTS | 原因码0..7及文字解释；工作槽峰值3位十进制，区域数4位十进制 |

REASON表示识别结果有效或被拒绝的原因，不是云台状态：

| 原因码 | 含义 |
|---|---|
| 0 OK | 检测结果有效 |
| 1 EMPTY | 没有候选目标 |
| 2 SMALL | 最大区域面积不足256像素 |
| 3 CAPACITY | 识别处理容量超限 |
| 4 WAIT | 显示结果未就绪、编号/配置/颜色不匹配，或有效包几何不合法等适配保护 |
| 5 TIMEOUT | 行处理超时或内部保护触发，不是云台超时 |
| 6/7 RESERVED | 保留码 |

容量/超时拒判时COMPONENTS显示NA，因为此时计数无效，不能把C=0解释为没有前景；未就绪时同样显示NA。SLOTS仍为包中诊断值，未匹配时继承B1a的清零值。

WAIT时RESULT/CFG字段仅为B1a输出保留的包身份或复位值；编号0不证明收到了有效结果。以上“VALID”只表示检测结果有效，**不是云台跟随状态**。机械状态、标定状态和性能测量接口仍由A/C后续提供，不根据目标有效性推断。

## 原子性和延迟

沿用 `h4e-refresh-v1`：在有效显示SOF使用此前完整T结果，SOF同拍事件留到下个SOF。所有文字字段均从B1a的 `out_packet/out_snapshot_ready/out_refresh_id` 读取，与框使用同一份快照。新增层不重新接收原始C结果，也不改动C算法。

总计四级像素寄存器：B1a两级，文字层两级。边沿N接收像素，边沿N+3后得到对应输出；valid、坐标、SOF/EOL/EOF、身份和包一起延迟。A接入时需要同步调整对应视频控制延迟，不能直接作为HDMI定时或DDR读请求。

十进制转换只有一套20位移位加3硬件，轮流处理X、Y、AREA、SLOTS、COMPONENTS，帧开始后100个时钟完成。转换输入在开始时保存，新的SOF会取消旧转换并重新开始，abort/复位立即取消。字段更新期间整块文字隐藏，完成后才允许绘字；合法720p光栅从(0,0)到首文字行y=16已有充足周期，正常画面不会显示半份数字。没有除法器、乘法器或帧缓存。

本阶段布局固定为1280×720、Logo位于(1104,16)，文字在x16..975、y16..31/40..55/64..79/88..103。字体修正版使用 `assets/osd/target_text_font.v`：5×7字形放大2倍，数字和大写字母统一14像素高，放在16×16字符格中。标点保留自然尺寸；I和1等字形自然较窄。字形源为 `assets/osd/target_font_5x7.json`，修改后运行 `scripts/build_target_font.py` 生成RTL，可加 `--check` 检查一致性。原B7字库保持不变。这些位置与Logo不重叠，因此不需要第二份Logo ROM。目标框仍可穿过Logo，B1a的不透明Logo优先规则继续生效。文字面板优先于其所在位置的背景和目标框。

虽然核心保留WIDTH/HEIGHT参数，本次文字布局和验证仅覆盖720p固定profile；改变分辨率或Logo位置需要另行设计布局和测试。原H4E的R/F全局诊断、黄色大ROI、标题、实时性能并未整体移入该层；本次只交付T结果文字。A后续在新的集成目录里组织最终布局，不能把它当作完整原mixer的直接替换。

## 自动验证与资源

独立Python模型用普通十进制/十六进制字符串格式化，再用统一字形JSON逐像素绘图；它没有复用RTL的字形位拼接、移位加3算法或字符选择电路。实际图像来自RTL输出的RGB字节流。逐拍检查四级延迟及字段，逐像素比对图形和文字，覆盖帧中到达、SOF同拍、失效清框、编号不匹配、busy、恢复、Logo、计数最大值、颜色与ID回绕、容量/超时及保留原因码。另用错误的期望包验证检查器确实能报错。

额外中断测试覆盖输出正忙时abort、没有新SOF时禁止输出、数字计算中途取消、异步复位以及恢复。新代码不自动检测物理坏行/坏帧；stream_abort仍由上游监测提供。

独立综合命令：

```powershell
python synthesis/check_target_info_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

脚本自动与B1a同类装载/观察包装比较寄存器、LUT、Slice、ERAM及DSP，要求75MHz暂定时序通过、0锁存器、0 ERAM和0 DSP。字体修正前证据保留在 `reports/b1b_20261010/`，修正后证据见 `reports/b1b_font_20261010/`；这是独立综合估算，不是整板净增量。整板集成应替换重叠的旧文字/Logo功能后重新综合，不能简单把独立模块数字相加。

本次没有新bit，没有capture_epoch/真实采集帧匹配，没有B2真实mask/RGB配对；上板时序和现场效果仍待A验证。用户完成这一步及图片确认后，再按任务书进入下一小步。
