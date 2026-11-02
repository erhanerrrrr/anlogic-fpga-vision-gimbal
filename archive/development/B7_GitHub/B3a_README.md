# B3a：帧边界模式请求控制

B2d 完整仿真与 MASK 图片已于 2026-10-14 由使用者确认。本小步复用原 B7 `frame_mode_ctrl.v`，新增连接层 `video_frame_mode_stream.v`，把同步模式请求接到 B2d 已验证的真实 C 四模式链。

## 复跑

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3a.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

最后应显示 `PASS: B3a checks completed.`。先运行控制/恢复场景，再跑小图和六帧 720p；完整过程可能需要三十至四十分钟，以最终 PASS 为准。`--small-only` 可快速检查控制和小图，不能代替完整回归。依赖沿用 `requirements-b1a.txt`，不需要新软件。

## 已做什么，下一步是什么

本步只处理已经同步到像素时钟的一拍模式请求。原 B7 的消抖与按钮模块保留，尚未接入本链；B3 后续小步再验证真实默认消抖周期、短按/长按/释放，以及模式、标定、跟踪三种事件。A 尚未确认的实际按钮管脚、极性和时钟不能猜定。

本步没有接标定/跟踪状态 OSD，也没有进行完整板级或按键板测，不能据此宣称整个 B3 完成。

## 请求规则

| 场景 | 行为 |
|---|---|
| 外部复位 | 当前模式和待应用模式清到 0 RAW，清除非法请求记录 |
| 一拍合法请求 0..3 | 保存为待应用模式；当前帧不改变 |
| 下一个可开始新输入帧的 SOF | 应用此前保存的请求，整帧采用同一模式 |
| 请求与 SOF 同一个上升沿 | 本帧先用此前的请求/活动模式；当拍新请求留给后一 SOF |
| 下一 SOF 前多个合法请求 | 最后一个合法请求生效，不逐帧排队回放旧请求 |
| 请求 4..7 | 拒绝，输出 invalid_request 单拍，设置粘滞 invalid_request_seen；不替换合法待处理请求，不中断视频 |
| in_sof=1 但 in_valid=0 | 不视为帧边界，不消耗请求 |
| 错坐标/错标志的 SOF，或帧内提前 SOF | B2d 报视频错误；控制层不把它用作新帧模式边界 |
| 视频 abort/超时/容量失败 | 图像流水线按 B2d 清空；当前和待处理模式保留；等待后续新的合法 SOF |
| abort 与请求同拍 | 视频帧作废，但该合法请求仍保存，供后续新帧使用 |

模式值为绝对模式编号：0 RAW、1 GRAY、2 EDGE、3 MASK。后续按钮层每按一次递增“请求模式”，再交给本接口；不能用画面当前模式作为每次按键递增的唯一依据，否则一帧内多次按键会丢次数。

### SOF 同拍的例子

| 时点 | 已有待处理请求 | 当拍新请求 | 本帧输入模式 | 下一帧待处理模式 |
|---|---:|---:|---:|---:|
| SOF N | 3 MASK | 1 GRAY | 3 MASK | 1 GRAY |
| SOF N+1 | 1 GRAY | 无 | 1 GRAY | 无 |

这两帧的输出可能比输入晚一行以上。屏幕标签必须用 **out_mode**；`active_input_mode` 只描述已接收的当前输入帧，可能已领先仍在输出的旧帧尾部。

## 接口给 A

显式源列表 `b3a_sources.f` 包含 B2d 的源，再加原 `frame_mode_ctrl.v` 和新包装。原 B7、B2a/B2b/B2c/B2d 与 H4E 冻结源均未改动。

输入像素、身份、分类阈值、输出四路候选与所选像素、故障和 FIFO 统计均沿用 `B2d_README.md`；B2d 的 `in_mode` 改为以下请求接口：

| 字段 | 宽度 / 语义 |
|---|---|
| mode_req_valid | 1，与 clk 同域，一拍为一次请求 |
| mode_req | 3，0..3 合法，4..7 非法 |
| invalid_request | 1，当次非法请求采样后的一拍提示，不是视频故障 |
| invalid_request_seen | 1，非法请求历史，外部 rst_n 才清零 |
| active_input_mode | 2，当前已应用的输入帧模式；仅供控制诊断 |
| next_frame_mode | 2，下次新帧将采用的候选模式；有请求即可能在帧中改变，不能接入显示标签 |
| out_mode | 2，随 out_rgb、out_valid、坐标和完整身份传递，屏幕应显示它 |

输入/输出为单一 clk；多位 mode_req 不能靠逐位双触发器跨时钟。若请求来自另一时钟域，A 必须用事件握手或 FIFO 原子传输。在没有 ready 的接口上，valid 连续为高被视为每拍一次请求。

控制层认定新帧入口需同时满足：外部复位已释放、不在 abort、当前未处于输入帧、valid/sof 为 1、x=y=0、eol=eof=0（支持尺寸至少 3×3）。真正开始的帧若后来因像素/容量/超时错误作废，已经应用的模式不回滚；下次仍使用它，或应用随后保存的新请求。故障期间应等待 out_abort 结束再送新的 SOF。

没有新增像素寄存级和 RGB FIFO：四种模式的有效节奏仍相同。720p、1650×750 总光栅下首像素延迟 **1655 拍**，输入 EOF 到输出 EOF **1285 拍**，RGB FIFO 峰值 **1284**、深度 **2048×24**。仍是内部流，不产生 HDMI HS/VS，也不能把 out_valid 反馈成 DDR 请求。

## 验证

`tb_frame_mode_control.v` 通过真实 C+B2d 链验证 9 个完整恢复/显示帧，覆盖：SOF前请求、无效SOF、多个合法请求、全部非法值4..7、请求与SOF同拍、帧中请求、abort同拍请求、残留像素、错SOF、提前SOF、超时、外部复位。每个完整帧逐像素核对模式、像素、坐标、标志和身份。`control_timing.csv` 是 RTL 实际事件记录。

画面回归覆盖 3×3、16×12 零消隐、16×12 带消隐、阈值0/128/2047，以及六帧 1280×720。零消隐用例检查上一帧尾部与下一输入帧同时在途时，输出仍带正确的旧模式。完整 720p 四路候选和所选画面均与独立模型逐像素核对。

六帧使用以下有意安排的请求序列；序号从1开始：

| 输入帧 | 关键请求 | 该帧实际模式 |
|---|---|---|
| 1 | SOF同拍请求GRAY | 0 RAW |
| 2 | SOF请求EDGE，后一像素请求MASK，再后一像素非法7 | 1 GRAY |
| 3 | SOF请求EDGE，后一像素非法4 | 3 MASK |
| 4 | 帧中请求RAW | 2 EDGE |
| 5 | SOF同拍请求GRAY | 0 RAW |
| 6 | SOF同拍非法7 | 1 GRAY |

图像位于 `build/frame_mode/run_.../native_720p/`，所选图为 `NN_selected_actual.png`；与 `selected_reference.png` 相同。`diff.png` 为四路候选联合差分，应全黑。还会故意破坏 EDGE 参考首像素，确认检查器能报错。

B2d 的完整容量/故障和 720p 帧中复位证据仍保留；本步新加入的模式请求与故障联动使用小图专门验证，不冒称本步重新执行了 B2d 的所有底层测试。

## 资源和交付范围

独立综合命令：

```powershell
python synthesis/check_frame_mode_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

TD 6.2.168116、PH1P35MDG324 -3、暂定75MHz，含可观测包装：**1888寄存器、2266 LUT、估计1687 Slice、7 ERAM、0 DSP、0锁存器**。相比B2d增加 **9寄存器、56 LUT、估计39 Slice**，RAM/DSP均不增加；RAM仍为RGB队列3+C滤波2+灰度窗口2。

setup/hold余量为+0.835/+0.292ns，TNS=0。唯一综合警告为独立包装125个端口未指定板级LOC；独立时序不代表整板时序。小型证据见 `reports/b3a_20261014/`，不上传大mem/像素流/工具库。

当前为 RTL 仿真和独立综合交付，没有 bit、按键实物验证或板测结论；真实 capture-v1 来源绑定、DDR/CDC、HDMI消费时序由 A 集成验证。使用者复跑本小步后，再进入按钮消抖与事件接入。
