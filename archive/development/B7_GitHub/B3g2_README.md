# B3g2：四模式画面接入同源目标框与坐标

本步在 B3f 的已验证像素链后接 B1b 目标框、中心、目标状态与十进制坐标文字。原 `video_b3_status_stream.v` 保留；新顶层为 `rtl/video_b3_target_stream.v`，精确源列表是 `b3g2_sources.f`。真实 C 分类和 3×3 掩膜滤波继续参与四模式视频，目标结果包在本步视频仿真中由测试台合成。

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3g2.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B3g2 checks completed.`。追加 `--synthesis --td 'D:\TD\bin\td_commands_prompt.exe'` 可复跑独立综合；耗时较长。

## 结果匹配规则

在有效显示 SOF，只选择此前已完成、`{epoch,frame_id,cfg_id,target_id}` 与该显示帧完全一致且没有来源/结果超时的结果包。结果与 SOF 同拍到达时留到后一个 SOF；帧中发布不会改动已选框。无效目标仍作为新结果接收并清框，原因码与诊断文字由 B1b 显示。`target_id` 表示颜色，不是跨帧物体身份。超时输入由 A 提供，不能由保持的 `target_valid` 推断。

新增的 B1b 层带来两级像素寄存延迟；来源身份、模式、C 标定状态和 A 跟踪状态也多延迟两级后与输出像素对齐。目标文字占 y16..103；C 标定文字从 y112 开始、A 状态从 y160 开始、模式标签在 y208；正式 Logo 最后绘制。一个共享的十进制转换器负责坐标/面积等字段，没有另加五套除法器。

## 验证边界

ModelSim 跑四帧 976×480 连续按键 RAW/GRAY/EDGE/MASK 和一帧完整 1280×720，逐像素对照独立 Python 图像参考；测试台还逐像素检查坐标、帧标记、来源身份、模式、状态快照及结果整包。连续帧的结果在帧中先行更新，当前画面仍维持 SOF 快照；第四帧的无效结果清框。完整分辨率帧检查 Logo、中央 ROI 和目标信息。

本步尚未把真实 C 结果端口及 epoch 原子跨域送入像素域；C/H4E 现有端口也不直接提供 epoch。A 负责真实来源帧绑定、跨域整包、超时和 HDMI/DDR 显示消费。独立综合包含分组观测包装，其资源和暂定 75 MHz 时序不等于整板净增量或上板验收；没有新 bit。

本机验证为 5 帧、2,795,520 像素、0 差异；独立综合为 6,596 Slice、7 ERAM、0 DSP、0 latch，暂定 75 MHz 的 SWNS +1.461 ns、HWNS +0.292 ns。TD 仍报告未分配位置约束，并有一条“undriven pins and nets 使用 0”警告；集成时需要核实该警告所指信号。与 B3f 包装的 Slice 数不能机械相减得出整板净增量。精简证据见 `reports/b3g2_20261017/`。
