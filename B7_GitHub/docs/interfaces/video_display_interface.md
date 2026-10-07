# B7 联合模块：按键、四模式和静态 OSD

## 结构与范围

新增 `video_display.v`，依次连接 `video_modes_buttons` 和 `video_static_osd`。前者处理按键与模式像素，后者仅对显示输出叠加 Logo、标题、标签、中心十字。基础 RGB 检测支路直接沿用前者输出，不经过 OSD。

当前 OSD 为两级流水。独立及联合的小图、720p 仿真和独立综合均通过。

这是内部像素流封装，不是 HDMI 输出控制器。真实识别 mask、动态目标框、主工程 ISP/DDR/HDMI 适配仍未接入。接口版本尚未由团队冻结。

## 接口、参数与延迟

外部端口与 `video_modes_buttons` 一致：RGB888、valid、SOF/EOL/EOF、11 位 x/y、32 位来源帧号、对应像素 mask、三个原始按键，以及显示输出、基础 RGB 支路、按键状态/事件、requested_mode、invalid_request、out_error。完整基础契约见 [video_modes_buttons_interface.md](video_modes_buttons_interface.md)。

WIDTH/HEIGHT 默认 1280/720，支持范围沿用基础链 3～2048；THRESHOLD 默认 128，DEBOUNCE_CYCLES 默认 750000，ACTIVE_LOW 默认 1。新增 OSD_ENABLE，1 为开启，0 为不绘制；关闭时 OSD 的两级寄存器仍保留，不能将其当作旁路零延迟。当前联合测试按键阈值使用 4，尚未证明默认阈值完整长时功能运行。

Logo/文字位置、底条与十字及优先级沿用 [video_static_osd_interface.md](video_static_osd_interface.md) 的默认布局。本封装暂不额外暴露布局参数；小分辨率按 OSD 规则裁剪，显示正式尺寸应显式设置 WIDTH/HEIGHT。

OSD 的 in_mode 接 `video_modes_buttons.out_mode`，与送入 OSD 的那一个像素匹配。禁止用 requested_mode 或输入侧当前 active_mode 代替：管线中可能仍存在前一源帧像素。标题标签只显示 RAW/GRAY/EDGE/MASK，不包括目标或跟踪动态状态。

当前所有显示数据与元数据比原按键四模式链再延迟两个时钟周期。无空白输入时整链 SOF 延迟为 3×WIDTH+8；行间空白沿用原链调度，不能把全部像素都说成固定延迟。基础 RGB detect_* 仍为原有一个寄存器级，按键事件延迟不变。out_error 是原链粘滞诊断，不因文字覆盖而清除。

复位传给两个模块，清除输出、帧状态和待切换模式；恢复前忽略没有 SOF 的片段。无效字段为零；无法撤回已经输出的半帧，下游仍需丢弃中断帧。接口无反压，合法输入行内连续。

掩膜输入仍要求与 RGB 同一坐标/源帧，本测试是棋盘掩膜。模式 2 的黑边约定属于 OSD 前的边缘图；最终 OSD 允许按指定覆盖规则绘制在任何有效区位置。

运行方法见[仓库首页](../../README.md)，本阶段证据见[验证说明](../validation.md)。
