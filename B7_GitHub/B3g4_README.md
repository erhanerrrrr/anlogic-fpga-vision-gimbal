# B3g4：真实 H4E 选区结果进入完整显示画面

本步不改 B3g2 RTL。在仿真测试台中，将 B3g2 内部**真实 C 分类+3×3 滤波**产生的掩膜流接到未修改的 `h4e_region_select`，再把它发布的结果端口接回 `video_b3_target_stream`。测试台使用层级引用读取内部掩膜；正式集成时必须改为明确命名的模块端口/连接，不能把 TB 层级引用作为可综合接口。

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3g4.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B3g4 real C result video checks completed.`；耗时约两分钟。实际 RTL 图、独立 Python 参考图、差分图与 ModelSim 日志位于 `build/b3g4_real_result_stream/run_时间/`；精简证据位于 `reports/b3g4_20261017/`。

仿真为两张 976×480 RAW 图，来源 ID 都是 42，epoch 在测试台固定为 9。输入为黑底 100×100 红色矩形。真实分类和 3×3 多数滤波使四个角点被滤掉，H4E 选区输出面积 9996、边界 x300..399/y250..349、中心 349/299、原因 0，峰值工作槽 1、区域数 1。第一遍显示在结果完成前，目标状态为 WAIT 且无框；第二遍重复显示同一来源时才显示 `TARGET:VALID`、面积、坐标、绿框及青色十字。TB 逐像素检查来源/模式/状态/结果整包/帧标记，936,960 像素与独立参考一致，合法帧无 abort，FIFO 峰值 980、最终归零，ModelSim 0 错误、0 警告。

本步 `calibration_status_packet` 和 `tracking_packet` 均为 0，因此画面上的 `CAL:UNKNOWN`、`TRACK:UNKNOWN` 是测试输入状态。没有正式 Logo 是因为此用例宽 976；Logo 已在 B3g2 的完整 1280×720 图片中单独验证。

此处的 `frame_id=42` 与 `epoch=9` 是测试台给定的合成身份，**不是**真实 DDR 缓存绑定的采集身份；H4E 选区模块本身没有 epoch 输出。A 仍需给 C 结果整包绑定正确 epoch，完成跨域原子传输、来源停帧/超时及重复显示调度。严格同源策略在来源帧不重复显示时可能永远不画该帧的框。此次也未做 C+B 整板综合、时序、bit 或板测；不能把 B3g2 的独立资源与 H4E 基线资源直接相加。
