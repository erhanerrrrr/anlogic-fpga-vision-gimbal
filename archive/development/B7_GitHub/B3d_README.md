# B3d：C标定状态与活动参数显示

本阶段观察C提供的事件和活动参数，显示两行16×16等字号文字。它不发起标定、不生成参数、不替代C控制器；A的机械跟踪状态显示仍是下一步。B3尚未全部完成。

## 运行

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3d.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

最后应出现 `PASS: B3d checks completed.`。约1分钟。可追加 `--synthesis --td 'D:\TD\bin\td_commands_prompt.exe'`。图在本次`build/calibration_status/run_时间/panels/status_panels.png`，完整720p及正式Logo图为`native_720p/00_applied_new_cfg_with_logo.png`。汇总图只是各实际RTL帧的文字区域拼接，不是单帧同时显示所有状态。

## 字段含义

| 显示 | 含义 |
|---|---|
| CAL:UNKNOWN | C状态不可用或复位，活动值显示NA |
| CAL:IDLE | 已有可信C状态，目前没有标定操作 |
| CAL:WAIT SAMPLE | C已接受请求，正在等待来源帧或取样；现有C接口没有区分这两段的开始信号 |
| CAL:CALC | 采样结束，等待参数计算结果；不表示计算成功 |
| CAL:PENDING | 参数计算完成/配置待应用，活动值仍为旧配置 |
| CAL:APPLIED | 收到了C的cfg_applied，控制侧活动配置已经生效 |
| CAL:FAILED | C计算/采样校验失败；显示C原活动配置 |
| RESULT:NONE/OK/FAIL | 最近一次本轮参数计算结果；OK不等于APPLIED；手动选色没有标定计算结果 |
| WHY | C标定计算原因码，与B1目标识别REASON不同 |
| CTRL HEX CFG/COLOR/MAIN/D1/D2 | C控制侧的活动配置号、颜色和三个阈值；数值为十六进制。不是当前显示图像的cfg标签 |

C `calibration_params.v` 当前原因码：0正常、1采样无效/不足256点、2均值范围不一致、3主通道过暗/过亮、4区域不均匀、5颜色区分不足；6/7保留。字体/色值沿用已有字体：UNKNOWN橙色、APPLIED绿色、FAILED红色，其余白色。

## 局部接口与时序

`calibration_status_view.v`输出51位原子状态包：`known[50],phase[49:47],result[46:45],reason[44:42],active_cfg_id[41:26],active_color[25:24],active_main[23:16],active_diff_1[15:8],active_diff_2[7:0]`。

- 输入直接对应C9 `sample_req/sample_done/calibration_done/calibration_ok/calibration_reason/cfg_applied/pending_valid/busy/active_*`。`sample_req`必须是**C接受的请求**，不能接未经C仲裁的按键。C9控制器可导出该线；旧`rgb_calibrated_result`没有公开sample_req端口时，可用可信busy上升/状态变化降级显示WAIT SAMPLE。采样结束只是CALC，计算OK只是PENDING，cfg_applied才是APPLIED。
- `c_status_valid`是新增局部可信标记，由A在同一时钟域的整包状态有效后提供。低时清为UNKNOWN，不硬编码H4E默认值。它不是独立事件strobe；高时每拍读取稳定活动字段及事件。若跨域，A须原子传输状态/字段并可靠传递事件，不能逐位双触发同步。C局部复位必须共同清观察器或拉低可信标记。
- 状态更新优先级：cfg_applied > calibration_done > pending_valid > sample_done > accepted sample_req/busy。合法C9流程中校准失败与应用事件不同时发生；本模块是观察器，不额外建立请求队列。手动选色从终态进入busy/pending时清旧计算结果为NONE。
- `video_calibration_text.v`在有效显示SOF锁存整包，帧中不换。观察器在同一沿收到事件时，显示SOF看到的是上一拍完整包，新状态到下一SOF才显示。busy等瞬态若短于显示帧，允许跳过中间文字，但保持结果和最终状态；不伪造一个持续的“采样成功”阶段。
- 默认文字坐标：x16..975，y112..127及136..151，与B1四行文本分开，中央16×16 ROI不改变。**2级像素寄存器**，RGB/valid/SOF/EOL/EOF/x/y与in_tag一起延迟；接入时不能把模式或ID从未延迟路径旁路过来。
- 默认`TAG_WIDTH=84`建议装`{epoch[31:0],frame_id[31:0],cfg_id[15:0],target_id[1:0],mode[1:0]}`；模块不解释tag。模式名称后续必须从随像素的mode显示，不能由即时按键决定。
- 显示abort清文字流水和帧快照，直到下一个有效SOF才恢复；不会清C观察器、不会把显示中断当标定失败。模块复位清状态。`out_status`与out_valid像素同步。

建议显示顺序：四模式选定RGB → B3c ROI → B3d文字 → B1目标/正式Logo → B1原有文字。Logo最后覆盖新增图层；本次组合测试直接连接真实B1a Logo模块，像素保持一致。未把这些模块接成B3b完整四模式顶层，A集成前还需统一流身份/缓冲与显示时序。

## 验证范围

1. 53组定向观察器输入：复位、可信失效、接受请求、采样结束、计算成功/失败、0..7原因码、手动pending、同拍事件、配置最大值/回绕、参数零/最大值。
2. **真实未修改C9 calibration_control** + 观察器 + 显示快照联合：忙时忽略、标定优先选色、完成恰遇新来源SOF不立即应用、重复来源帧不应用、新来源应用、cfg FFFF→0000、应用同拍请求忽略、失败保留参数、手动选色、显示SOF和应用观察同拍/帧中稳定。
3. C测试使用合成`sample_done/params_*`，未运行真实ROI采样器或参数计算器。C当前旧默认80/40/40如实验证，不把它导入H4E链路。显示测试另注入24/16/16证明观察器不硬编码旧默认。C需先参数化并验证H4E默认，之后再接板级。
4. 10张976×160文字测试帧与1张完整1280×720图，共2483200个像素，独立Python字符串与字体JSON渲染参考逐像素比较；再检查与正式Logo组合后的同批像素。每帧中间改变输入包，当前帧输出仍为旧包，检查坐标、完整84位测试tag、帧标记与状态；包含复位/abort/假SOF恢复。
5. 本次完整720p是状态文字及B1a显示链，并非B3b真实C滤波四模式全链。正式Logo参考来自冻结H4E hex。大RGB/波形/仿真库不入报告包，由脚本重建。

## 资源与接入边界

新增模块不增加图像FIFO/帧缓存，不新增ERAM或DSP；字体仍为组合逻辑，状态用寄存器，数值用HEX避免新增十进制除法器。综合使用分组装载/读回的观测包装，所有metadata可见，报告包含观测包装寄存器与复用器；它不是板级引脚接口。最终资源与时序见`reports/b3d_20261014/synthesis/summary.json`，不能把各独立包装的资源机械相加当整板占用。

RTL和独立综合通过也不代表完整板级时序、生成bit或上板通过。A还需提供真实时钟、CDC、C可信状态和显示SOF/abort，逐步接入后回传状态事件、active_*、status_packet、显示SOF和out_status。没有真实状态源时拉低c_status_valid显示UNKNOWN。当前状态标签是**最新控制状态快照**，并不宣称当前DDR图像已经属于新配置。
