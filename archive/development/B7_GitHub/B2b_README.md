# B2b：接入原图 RAW 与灰度 GRAY

前置B2a已由使用者于2026-10-12复跑通过，6帧720p配对与故障/恢复日志及源码哈希已核对。本阶段在同一份真实C配对流后提供RAW和GRAY两路候选图像；同一组valid、坐标、帧标志、身份及mask供两路共用。先证明原图透传、再证明灰度准确，后续B2c接EDGE，B2d汇合四模式，B3验证实际按键。这里没有提前接入模式请求或按键。

## 现在运行

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b2b.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

完成提示：`PASS: B2b checks completed.`。依次执行独立灰度级、故障恢复、小图及6帧720p检查，需要几分钟。不要把中间小图PASS当全部完成。`--small-only` 可用于排错，不能代替完整验收。

图像在 `build/raw_gray/run_.../native_720p/`：

- `01_rgb_actual.png` 与 `01_gray_actual.png`：色块转灰度，红/绿/蓝分别应为77/149/29。
- `04_rgb_actual.png` 与 `04_gray_actual.png`：复杂彩色图的灰度结果。
- `05_rgb_actual.png` 与 `05_gray_actual.png`：0..255灰阶渐变，转换前后应一致。
- 同编号 `mask_actual.png`：仍是从彩色输入得到的真实C滤波结果。
- `gray_reference.png`、`mask_reference.png` 和 `diff.png`：独立参考与联合差分；全部差分应全黑。

## 实现和接口

明确源列表 `b2b_sources.f`。`video_rgb_mask_raw_gray.v` 只实例化一份已验证的 `video_rgb_mask_pair`，再接 `video_raw_gray_stage`；原B2a、B1a、B1b、B7及冻结H4E文件保持不变。

```text
彩色RGB ── B2a（同一份RGB FIFO + C分类/滤波）── 配对RGB/mask
                                                    │
                                     B2b 一拍寄存器/灰度运算
                                                    │
                          同拍RAW + GRAY + mask + 完整身份/坐标
```

`video_raw_gray_stage.v` 是可单独接入的显示级，输入必须是经过配对的合法流，不自行接收新帧或重建坐标。整合入口 `video_rgb_mask_raw_gray.v` 与B2a的输入及错误/占用接口一致，输出 `out_rgb` 替换为同拍 `out_raw_rgb` 和 `out_gray_rgb`。没有两份视频缓存，只有一组共同的输出控制信号。

| 输出 | 含义 |
|---|---|
| out_valid | 同拍RAW/GRAY/mask及身份有效；掩膜为0不会丢像素 |
| out_raw_rgb | 原始RGB888，逐位不改变 |
| out_gray_rgb | 同像素的 `{Y,Y,Y}` |
| out_mask | 来自彩色检测分支的真实C滤波掩膜，再延迟一拍 |
| out_x/y、sof/eol/eof | 与两路RGB共同延迟一拍，保留整幅W×H顺序 |
| out_epoch/frame_id/cfg_id/target_id | 完整32/32/16/2位身份，与像素保持一致 |
| out_abort | 外部/配对故障及灰度级冲刷完成前持续通知，允许连续多拍；下游丢弃未完成帧 |
| error_flags、fifo_used/fifo_peak | 直接保留B2a诊断含义，不当作输出像素metadata |

B2a的合法输入范围、超时、epoch含义和恢复条件保持不变，详见 `B2a_README.md`。输出valid为0时两路RGB、mask、坐标和身份均清零。复位为异步低有效；外部abort是同步事件，整合层立即禁止后级输出并清空在途状态。错误前已经输出的像素不可撤回，下游需处理abort；没有新增整帧事务缓存。

## 灰度数值与延迟

沿用B7数值定义：`Y = floor((77R + 150G + 29B + 128) / 256)`。加128后向下取整，不另作截断或饱和；最大和65408，16位无符号数可容纳。黑为0、白为255，所有R=G=B的灰阶保持原值。

本阶段新增 `rgb_to_gray_lut.v`，将常数系数写为移位/加法：77=64+8+4+1，150=128+16+4+2，29=16+8+4+1。这样保持旧灰度算法的逐位数值和一拍寄存器延迟，避免常数乘法被映射为DSP；原B7 `rgb_to_gray.v` 未修改。

原图和灰度各输出端口共用一拍延迟。因此相对B2a配对输出增加1拍；720p输入SOF到首像素输出为1655拍，输入EOF到输出EOF为1285拍。连续有效像素吞吐仍为每拍1像素；行内无停顿，消隐按C滤波实际调度输出。小图无行/场消隐时上一帧尾部和下一帧输入可重叠，身份不会混合。

这里仍是内部像素流，不产生HDMI HS/VS或DDR读请求。A需要继续安排显示供数和同步；不能把新增一拍解释为已经实现整板显示时序。RAW/GRAY结果不反馈给C的彩色检测入口。OSD尚未接到本阶段，原B1b结果快照规则未改变。

## 仿真证据

- 独立显示级：5853组向量，包含全部灰阶、三原色各256档、4096随机颜色、舍入余数0/127/128/129/255附近的定向颜色、插空、abort和复位；数据/metadata同拍核对。
- 联合真实C：3×3及16×12零消隐、16×12带消隐，6帧1280×720有效区/1650×750总光栅。逐像素同时核对RAW、GRAY、真实mask、坐标、三个帧标志与全部身份。参考为Python整幅数组整数加权/卷积，不调用RTL运算。
- 包含黑白/阈值色块、复杂彩色图、灰阶、目标移动/消失、贴边与噪点、色彩/config/ID回绕、epoch变化、跨帧尾部。
- 12个小图故障场景、容量不足场景及720p运行中复位后完整恢复。恢复帧同时核对RAW/GRAY/mask，不仅检查valid或PASS字符串。
- 故意翻转期望mask的负例应触发像素错误，确认检查器有效。

实际图来自RTL输出RGB/灰度字节流。源码哈希、日志、图片、时序事件及资源报告整理在 `reports/b2b_20261012/`；用户复跑后再确认结果。build目录的大型mem、RGB流、波形及编译库不上传。

## 资源和A接入注意

RGB缓存仍为2048×24位，C仍复用两行1位mask缓存；本阶段不增加FIFO、ERAM或帧缓存。两份帧身份描述沿用B2a，FIFO峰值应仍为1284像素。额外开销来自灰度移位加法、RAW及metadata的一拍寄存器。

```powershell
python synthesis/check_raw_gray_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

综合脚本对比B2a同类观察包装，要求仍为5 ERAM（RGB 3+C 2）、0 DSP、0锁存器，75MHz暂定约束通过。本机TD6.2.168116、PH1P35MDG324 -3结果：889寄存器、877 LUT、估计731 Slice；相比B2a增加142寄存器、193 LUT、142估计Slice，ERAM和DSP增量均为0。新增寄存器正好对应108位metadata、24位RAW、8位灰度、valid和abort各1位。setup余量2.847ns、hold余量0.457ns、TNS=0；唯一警告为独立包装123个端口未指定板级LOC约束。

独立模块资源不是整板净增量，A接入时复用/替换原有分类、滤波及显示路径后再完整综合。没有新bit、没有板测，也未声称capture-v1的真实DDR来源绑定已完成。
