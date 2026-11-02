# B3g1：同源帧目标结果门控（仿真接入前置步）

本步只新增 `rtl/capture_target_gate.v`，把团队已选定的“同一来源帧 ID 才画框”规则变成明确电路。它与已验证的 `b1_target_snapshot` 一起进行小规模 ModelSim 检查；**尚未接进 B3f 四模式顶层**，也未把 H4E 显示刷新号冒充真实采集帧号。

## 一键复跑

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3g1.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志为 `PASS: B3g1 same-source gate checks completed.`；日志在 `build/capture_target_gate/run_时间/`。

## 接口和时机

仅在有效显示 SOF，最新完成的 C 结果的 `{epoch,frame_id,cfg_id,target_id}` 与当前像素所属来源的四项身份全部相等，且 A 的 `source_timeout/result_timeout` 都为 0，才允许 B1a 选取这份整包。`target_valid=0` 的同源结果也要接收，用于清除旧框；不能只接有效目标。结果恰好与 SOF 同拍到达时，当前帧仍选旧结果，新结果最早在后一个 SOF 生效。帧中结果和超时变化在下一 SOF 更新显示，避免半帧换框。

真实 A/C 联合接入时，结果 epoch 和 C 整包必须随 `result_strobe` 原子送到同一个像素域。A 负责真实来源帧 ID、epoch、CDC、超时及显示消费；B3g1 的合成 ID 测试不证明这些板级功能已实现。当前 C/H4E 结果端口尚无 `result_epoch`，不能把它接常数后声称已完成 capture-v1。

## 验证和资源范围

TB 覆盖无结果、同源有效/无效结果、帧中结果、SOF 同拍结果、epoch/帧号/配置/颜色不匹配、来源/结果超时、中断复位及 32 位帧号回绕。适配层只保存一次 83 位结果身份；没有 FIFO、帧缓存、RAM 或 DSP 实例。此次仅是 ModelSim 单元验证；综合资源、B3f 整链结合、整板时序、bit 和上板验证均未完成。
