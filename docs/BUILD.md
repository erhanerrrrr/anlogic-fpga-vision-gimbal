# 基于FPGA的双轴视觉跟踪云台

参赛成员：华尔涵、张韶珍、张梓琪  
赛道：FPGA创新设计赛道 · 安路赛道  
选题二：基于安路PH1P35的实时数字图像处理系统

本工程使用 HX1P35A 开发板与 SC500CS 摄像头，实现 MIPI 视频采集、图像处理、HDMI 显示、三色目标及形状识别、双轴舵机跟踪、运动检测、传感器自动曝光和视频链路延迟统计。运行控制在 FPGA 内完成，电脑用于配置下载及可选的串口记录。

## 目录

| 目录 | 内容 |
| --- | --- |
| `src/top` | 系统顶层与模块连接 |
| `src/video` | 帧缓存读写接口、显示坐标适配 |
| `src/vision` | 颜色分割、连通区域、形状分类、颜色标定 |
| `src/motion` | 背景学习、前景区域与运动状态判断 |
| `src/control` | 分轴控制、目标丢失保持、PWM 输出 |
| `src/exposure` | 亮度统计、曝光与增益控制 |
| `src/timing` | 帧标记、跨域时间戳、帧率与延迟统计 |
| `src/display` | 图像显示模式、Logo、文字与图表叠加 |
| `src/io`、`src/common` | 按键、外设、UART、跨时钟域与公共逻辑 |
| `platform` | 开发板配套接口、摄像头配置、厂商 IP 及生成文件 |
| `constraints`、`project` | 引脚约束、时序约束、TangDynasty 工程 |
| `tb` | 仿真用例、参考模型与输入数据 |
| `tools` | 工程准备、编译、回归与串口记录工具 |
| `release` | F3A bit、构建参数和校验值 |

模块名称与硬件接口沿用 F3A。源码按职责重新分目录，清理了过时的版本说明和未被工程引用的历史文件；识别参数、控制参数、端口及寄存器行为保持一致。

## 打开与编译

硬件器件为 **PH1P35MDG324，速度等级 -3**。发布 bit 使用 **TangDynasty 6.2.1 Engineer（6.2.168.116）**。完整硬件编译需要安路工具及相应器件支持；Python 工具需要 Python 3.10 或更高版本。

将整个 `FPGA_Gimbal` 文件夹解压到本地，建议使用短英文路径。在文件夹中打开终端：

```powershell
python tools/project.py check
python tools/project.py prepare
```

第二条命令会在 `build/prepare_日期时间/` 下准备独立工程，并打印 `.al` 文件的绝对路径。使用 TangDynasty 打开该文件，按 **Synthesis → Place & Route → Generate Bitstream** 执行。顶层为 `design_top_wrapper`。工程文件沿用 `camera_to_dsi_display.al` 名称，实际输出接口为 HDMI。

也可以直接执行命令行编译，将下列工具路径替换为本机安装位置：

```powershell
python tools/project.py build --td "C:/Anlogic/TD/bin/td_commands_prompt.exe"
```

仅检查工程加载或综合时，将 `build` 改为 `inspect` 或 `synth`。每次命令创建独立工作目录，原源码和 `release` 中的 bit 不受影响。结果与日志均位于终端打印的 `build/` 子目录内。

## 仿真

安装 Icarus Verilog，将 `iverilog` 和 `vvp` 加入 PATH：

```powershell
python tools/run_tests.py
```

默认执行 `tb/suite.json` 中的 30 项 HDL 回归，并校验 UART 数据的 Python 解码结果。可指定单项，例如：

```powershell
python tools/run_tests.py --test tb_sensor_ae tb_latency_meter
```

也可通过 `--iverilog`、`--vvp` 指定工具路径。日志写入 `sim/`。仿真覆盖算法和控制逻辑；厂商加密 IP、器件资源及完整顶层由 TangDynasty 编译检查。

## 使用与说明

- [系统结构](ARCHITECTURE.md)：数据流、模块职责、时钟域与资源组织。
- [板端操作](OPERATION.md)：按键、拨码、运动检测及曝光/延迟页面。
- [来源与依赖](../THIRD_PARTY.md)：配套代码、厂商 IP 和工具依赖。
- [核查结果](VALIDATION.md)：本次源码整理的检查范围与结果。

`release/F3A_demo_overlay.bit` 是此前发布的完整镜像，本次整理未生成替代 bit。SHA-256：

```text
bb8485f592b80be51f362e5254c6d1b841f965d23bfc843b12a9e081fae926c6
```

工程编译、仿真和板端测试分别记录。已有时序报告的覆盖率为 93.46%，摄像头配置 I²C 分频时钟及部分外部接口仍存在时序覆盖缺口；不将已约束路径通过写成全接口时序签核。
