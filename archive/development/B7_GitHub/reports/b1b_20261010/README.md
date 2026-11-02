# B1b 本次运行证据

本阶段扩展B1a，增加目标状态、颜色、中心坐标、面积、结果/配置/显示编号和原因诊断文字。接口为h4e-refresh-v1；不显示未经A提供的机械跟踪状态。

本机环境：Python3.14.6、ModelSim Altera Starter10.3c、TD6.2.168116。ModelSim及TD均使用原安装。本次不生成bit、不执行完整板级布局布线；B1b仍待使用者亲自复跑/看图和A上板。B1a已获使用者图片确认。

## 验证内容

- `simulation_summary.json` / `simulation.log`：17帧1280×720有效图像、1650×750光栅，共15,667,200像素；Python独立格式化与字模参考，RTL实际输出逐像素比较。
- `decimal.log`：214组十进制转换检查，包含0、位宽最大值、9→10等进位边界和固定种子随机输入；100周期完成、忙时新SOF重启、flush、异步复位取消。
- `abort_summary.json` / `abort.log`：完整B1b链的帧中断、禁止无SOF输出、复位和恢复。
- `negative_checker.log`：故意传入错误的期望包，必须由四级延迟/字段检查器报错；这是检查器自检。
- `synthesis_summary.json` / `synthesis_area.rpt` / `synthesis_timing.rpt`：最终独立综合和相对B1a的资源增量。
- `delivery_manifest.json`：本阶段源码及小型证据清单。B1a既有47文件清单另行核对，全部保持原样。

数字转换复用一套移位加3电路；字库和Logo复用原B7资产，没有增加帧缓存。文字层增加两级寄存器，B1b总计四级。文字面板限制在Logo左侧，不需要第二份Logo ROM。字符选择索引按字宽限制，避免不被选中分支仍出现范围外切片。

资源、时序的具体数值见下列独立报告；它们包含装载寄存器/输出观察包装。综合估计的Slice增量不等于整板净增量，A集成时还应移除重复旧文字/Logo逻辑并重跑整板资源与时序。

最终源码的资源对比如下（TD6.2.168116，PH1P35MDG324 -3）：

| 资源 | B1a | B1b | 增量 |
|---|---:|---:|---:|
| 寄存器 | 1058 | 1754 | +696 |
| LUT | 3490 | 4476 | +986 |
| 估计Slice | 2852 | 3552 | +700 |
| ERAM | 0 | 0 | 0 |
| DSP | 0 | 0 | 0 |
| 锁存器 | 0 | 0 | 0 |

75MHz暂定预算：setup裕量+2.253ns、hold+1.047ns，TNS均为0。新文字的主要存储是跟随像素传递的字段寄存器、字模寻址和小型十进制状态，不是行/帧缓冲。这个增量对资源预算仍有影响；下一阶段不重复实例化本层和旧OSD，整板资源要重新评估。

工具日志保留SYN-5025（未驱动项使用0的通用提示）和126个端口未指定LOC的提示，没有具体SYN-8115未驱动错误或其他ERROR。警告原文保存在`tool_diagnostics.json`及综合日志。本次有RTL仿真与独立综合证据，未做门级回归、板级引脚约束或布线签核。

## 查看图片

图中渐变背景和结果包为合成输入，actual由RTL输出转换，reference由Python产生，diff为逐像素差分。黑色diff表示无差异。

| 场景 | 实际RTL | 参考 | 差分 |
|---|---|---|---|
| 正常坐标与帧中更新 | [actual](02_normal_mid_update_actual.png) | [reference](02_normal_mid_update_reference.png) | [diff](02_normal_mid_update_diff.png) |
| 目标无效、坐标NA | [actual](04_invalid_clear_actual.png) | [reference](04_invalid_clear_reference.png) | [diff](04_invalid_clear_diff.png) |
| 字段最大值与蓝色 | [actual](10_maximum_fields_actual.png) | [reference](10_maximum_fields_reference.png) | [diff](10_maximum_fields_diff.png) |
| 容量拒判、区域计数NA | [actual](14_reject_3_actual.png) | [reference](14_reject_3_reference.png) | [diff](14_reject_3_diff.png) |

其中最大面积1048575是20位字段压力输入，不是720p目标的真实面积。其余17帧的PNG和逐像素文件由脚本在build中生成，不上传大型RGB文件/波形/编译库。

## 复跑

从B7_GitHub目录执行：

```powershell
python run_b1b.py --modelsim D:/altera14.1/modelsim_ase/win32aloem
python synthesis/check_target_info_synthesis.py --td D:/TD/bin/td_commands_prompt.exe
```

详细字段与时序见 [B1b入口](../../B1b_README.md)。人工步骤仍是先运行、再检查实际图片；本目录的自动通过不能替代板测。
