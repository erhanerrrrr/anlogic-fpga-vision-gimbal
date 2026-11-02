# 系统结构

## 视频与控制数据流

```text
SC500CS ── MIPI RX / RAW10 / ISP ── DDR 帧缓存 ── 显示坐标适配
   ▲                                              │
   │ I²C                                          ├─ 颜色分割 / 连通区域 / 形状分类
   │                                              │       └─ 目标数据 ── 双轴控制 ── PWM
   └─ 曝光控制 ← 亮度统计                         ├─ 背景学习 / 前景 / 运动状态
                                                  └─ 显示模式 / Logo / OSD ── HDMI TX

CSI 帧起始 ── 时间戳与实际 DDR 帧绑定 ── HDMI TX 输入处取差 ── 延迟统计与图表
按键 / 拨码 ── 去抖与事件跨域 ── 模式、标定、背景采集、启停
检测与控制状态 ── 数码管 / 双色灯 / 蜂鸣器 / UART TX
```

视频分辨率为 1280×720。图像模式改变显示内容，颜色定位在后台继续运行；进入 MOTION 或执行颜色标定时，控制链路按状态保持当前命令。

## 主要模块

| 功能 | 主要文件 | 实现要点 |
| --- | --- | --- |
| 系统集成 | `src/top/design_top_wrapper.v` | 连接视频、帧缓存、跨域通道、控制和外设，设置最终舵机范围 |
| 视频缓存 | `src/video/video_in.v`、`video_out.v` | 接入 DDR 读写，传递帧信息 |
| 视觉调度 | `src/vision/f_vision.v` | 模式选择、颜色标定、运动采背景与曝光冻结协调 |
| 颜色识别 | `f_seed_color_mask.v`、`f_green_local_mask.v`、`color_classifier_runtime.v` | 通道差分阈值、局部均值与强弱种子约束 |
| 区域与形状 | `f_shape_regions.v`、`f_shape_metrics.v` | 行程段连通区域、最大合格区域、二维轮廓分类 |
| 颜色标定 | `f_calibrate.v`、`roi_color_sampler.v`、`calibration_control.v`、`calibration_params.v` | 中央区域采样，更新选定颜色的门限 |
| 运动检测 | `src/motion/f_motion_bg.v`、`f_motion_regions.v` | K3 触发背景学习，记录有限亮度范围，结合背景差与帧间差 |
| 双轴控制 | `src/control/f_control.v`、`f_axis_predictive.v` | 分轴增益、中心死区、步长限制、帧序号校验、PWM 限幅 |
| 自动曝光 | `src/exposure/f_ae_meter.v`、`f_sensor_ae.v` | 亮度与高光统计、曝光/模拟增益调节、帧间等待与总线异常锁存 |
| 延迟测量 | `src/timing/f_capture_tag.v`、`f_capture_meta.v`、`f_latency_meter.v` | 采集帧标记绑定缓存帧，统计当前/最小/最大值与趋势 |
| 显示 | `src/display/f_image.v`、`f_osd.v`、`f_system_dashboard.v`、`anlogic_logo_rom.v` | 八种模式、目标框、中心标记、文字、Logo 和统计页面 |
| 本地外设 | `src/io/f2_inputs.v`、`f2_panel.v`、`f_uart_telemetry.v` | 按键/拨码状态、复用显示扫描、事件蜂鸣、串口遥测 |

表中未写目录前缀的文件位于同一行已经标明的功能目录。`platform/hdl` 保存 MIPI、HDMI、DDR 包装层、ISP 与摄像头配置代码；`platform/ip` 保存 PLL、FIFO、RAM 和除法器等生成文件。

## 时钟与跨域

- 100 MHz 控制域：按键去抖、舵机 PWM、数码管扫描与 UART。
- 24 MHz 摄像头配置域：I²C 配置及曝光控制。
- HDMI 像素域：图像处理、识别、OSD 与显示端统计。
- CSI 接收域与 DDR 用户域：视频接收、帧缓存和源帧时间标记。

`f_cdc.v` 使用请求/应答传递稳定的数据包；帧时基采用 Gray 编码与同步处理。帧标记、结果序号与有效标志共同防止重复帧和过期目标被误用。约束入口为 `constraints/timing.sdc`，DDR IP 还带有自身约束。

## 资源组织

当前实现保留已经用于完整镜像的资源方案：形状描述按坐标位宽压缩、分类运算复用串行乘法器、Logo 使用无损跨度编码、曝光与延迟页面共享数字转换和显示逻辑。图像处理以流水线、行缓存和局部统计为主。

F3A 原构建的最终布线占用为 Slice 18716/21216、ERAM 98/108、DSP 18/40；这些是原 bit 的实现结果。本次目录整理不以修改算法或重新布线来获得新的资源数字。

## 测量边界

CARD、BALL、BLOB 表示卡片状、近圆形及不规则二维轮廓。系统没有语义物体识别或同类目标身份锁定。MOTION 用于固定视角下的前景与运动观察，改变视角后需要重采背景。延迟统计范围为 CSI 帧起始到 HDMI 发送模块输入，不包含显示器响应或舵机运动时间。
