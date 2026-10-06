# C端固定验收证据：2026-10-06

这是首次C端交付时从本机生成结果中保留的小型快照，便于直接在GitHub审阅。后续运行脚本仍将结果写入`reports/c10/generated/`，不会自动改动本快照。

- `summary.json`：12帧720p和中断恢复的实际计数、像素/结果/时序检查结果。
- `regression.log`、`regression_summary.json`：C1–C9重新执行及最终TD综合的退出码。
- `clean_directory.log`：独立目录重新编译运行通过；故意将中心120改为121后正确失败；RGB分析工具自检通过。
- `sequence_720p/expected_frames.csv`与`actual.csv`：独立期望和实际结果；`configs.csv`、`calibrations.csv`、`timing.csv`记录参数与时序。
- `sequence_720p/mask_*.png`：选取的实际RTL掩膜，分别展示单块、分散两块、标定ROI、新阈值拒绝和整帧目标。
- `recovery/`：停帧、半帧复位及完整恢复的实际结果。
- `td/c10_gate.area`：综合资源报告；未布局布线、未板级时序签核。
- `source_manifest.json`：此次被验证的RTL原文件SHA256；`artifact_sha256.json`：本快照数据文件的SHA256。

12帧共11,059,200像素，11次新观察，8有效/3拒判，重复来源帧不发新通知。C端本机验收通过不代表B显示联调或H3/H4实物验收通过。

完整复现方式见[根目录说明](../../../../README.md)及[A/B交接说明](../../../../docs/handoff/C端交接.md)。大型掩膜二进制、完整波形和工具中间文件不纳入Git，运行脚本即可重建。
