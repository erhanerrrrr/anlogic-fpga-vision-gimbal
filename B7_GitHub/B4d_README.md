# B4d：1280×720 原生画面、正式 Logo 与延迟 OSD 联合仿真

沿用 B4c RTL，不改 B3g6、B4a 或 B4b 算法。测试台将画面扩大到 1280×720，两次显示同一合成来源 epoch/frame/cfg/target ID：首帧目标结果未就绪、延迟为 N/A；第二帧显示 H4E 最大区域目标框、中心十字和 8 个合成延迟样本的 RES 统计。显示内容与官方 160×160 安路 Logo 同时存在；Logo 区域逐像素以板级黄金文件核对。

复跑命令：

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b4d.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B4d native 720p Logo and latency OSD checks completed.`。本机 2026-10-19 的两帧共 1,843,200 个 RTL 输出像素与独立参考零差异，ModelSim 零错误、零警告。TB 还检查每像素 x/y、SOF/EOL/EOF、来源身份、结果快照、C 结果事件、错误标志与 FIFO 排空。实际图、参考图、差分图和源哈希在 `build/b4d_native720_latency/run_20261019_214219/`。

本阶段没有改动 RTL，组合资源仍参照 B4c 用户复跑报告：8,622 Slice、10 ERAM、0 DSP，暂定 75 MHz 独立综合通过。这里的来源 epoch 和延迟都是合成测试输入；真实 A 测量、CDC、整板布局布线、bit 和上板验证仍待接入。完整的移动/消失、配置与模式切换、容量失败恢复测试不由本两帧例子单独覆盖。

用户复跑 `run_20261019_222955` 已确认成功：两帧仍为零差异，ModelSim 零错误、零警告。摘要见 `reports/b4d_20261019/delivery_manifest.json`。
