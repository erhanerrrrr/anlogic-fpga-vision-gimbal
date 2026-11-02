# 按键驱动四模式视频：小图联合验证

2026-10-05，将独立按键模块接到既有四模式视频链。已完成模拟按键与 16×12 小图联合仿真、10 帧 720p 验证及 TD 独立综合；尚未上板。

## 结构与接口

`buttons_async → button_events → button_mode_request → video_modes`。

新增 `button_mode_request.v` 累计用户请求，`video_modes_buttons.v` 封装按键与视频链。原有 `button_events.v`、`frame_mode_ctrl.v`、`video_modes.v` 和图像算法不变。视频接口、基础 RGB 观察接口和诊断信号沿用 [video_modes_interface.md](video_modes_interface.md)，封装增加以下接口：

| 信号 | 含义 |
|---|---|
| buttons_async[2:0] | 原始按键引脚电平；位 0/1/2 为模式、标定、跟踪 |
| pressed[2:0] | 已确认按住状态 |
| press_event[2:0] | 每次确认按下一拍事件 |
| requested_mode[1:0] | 已消费按键事件累计得到的目标模式，复位为 0 |

三个键在视频 `clk` 内完成同步及去抖。原始引脚允许异步变化，但本封装没有第二个按键采样时钟，也没有跨时钟事件传递。没有外部模式请求接口或多来源仲裁；若后续加入其他控制源，需统一目标模式状态。

模式顺序为 0 原图 → 1 灰度 → 2 边缘 → 3 掩膜 → 0 原图。每次模式事件对 requested_mode 加一，而不是对当前帧 active_mode 加一。因此同一帧内从目标 0 连按三次，目标依次为 1、2、3，下一帧显示 3，当前帧保持原模式。

按键模块在确认边沿更新 press_event；下一上升沿适配器更新 requested_mode，同时帧控制器消费请求。在请求被消费的边沿若也出现有效 SOF，新请求按既有规则留到再下一个有效 SOF，当前 SOF 使用此前的 pending。事件日志记录确认后的 press_event，因此该行 requested_mode 仍可能是消费前的值；下一拍才更新。

视频封装没有新增像素流水级，输出仍携带对应源帧的模式标签，延迟沿用四模式链；无空白时 SOF 延迟为 3×WIDTH+6。检测观察支路始终输出基础 RGB。标定、跟踪只提供事件，本步测试接收端计数，没有实现标定或跟踪动作。

`DEBOUNCE_CYCLES` 默认 750000、`ACTIVE_LOW` 默认 1。若 clk 为 75 MHz，默认去抖时间约 10 ms；实际板级时钟、引脚和极性未冻结。本步联合仿真用 N=4 加快测试，不代表已验证默认阈值的完整长时运行。同步器的数字验证范围见 [button_events_interface.md](button_events_interface.md)。

运行方法见[仓库首页](../../README.md)，本阶段证据见[验证说明](../validation.md)。
