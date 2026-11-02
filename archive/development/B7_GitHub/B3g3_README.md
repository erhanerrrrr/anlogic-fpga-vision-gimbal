# B3g3：真实 H4E 选区结果与同源显示快照联动

本小步在独立小图仿真中使用**未修改的** `h4e_region_select.v` 生成目标结果，经 B3g1 `capture_target_gate` 进入 B1a `b1_target_snapshot`。它验证真实结果包的字段和结果到达时机；尚未把 C 选区模块接进 B3g2 的完整视频顶层。

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3g3.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志是 `PASS: B3g3 H4E result handshake checks completed.`，日志在 `build/b3g3_h4e_result/run_时间/`。

测试先显示来源 42，C 结果尚未完成时输出 WAIT。输入 32×32 掩膜，中央 20×20 共 400 个有效像素；真实 H4E 选区模块发布来源 42、面积 400、边界 5..24、中心 14/14、原因 0。重复显示来源 42 后快照才允许画框。改为来源 43 或改 epoch 时不能使用旧框。随后输入来源 43 的空掩膜，C 发布原因 1、无效目标，下一次来源 43 的显示快照清框。TB 检查两个真实 C 结果事件，ModelSim 0 错误、0 警告。

掩膜图由 TB 合成，未经过完整 C 分类/滤波链。`h4e_region_select` 只有 frame_id，没有 capture_epoch；测试把 epoch 固定为 9，仅证明 B 端门控在已提供正确 epoch 时的行为，不证明 A 的真实采集帧绑定、C 结果 epoch 关联、跨时钟整包或 HDMI 供数。H4E 基线中的 frame_id 曾是显示刷新号，不能仅凭本测试称其已变为真实采集来源。完整画面仍见 B3g2 的合成目标结果仿真；没有本步新 bit、整板时序或板测。

严格同源规则有实际限制：若某来源帧只显示一次，且 C 结果在该帧显示之后才完成，该来源的框不会出现。A 需要让已完成结果对应的来源帧能够再次显示，或日后明确改用带来源年龄的最新结果策略并重新验收；此选择会影响真实画面的可见性。
