# H4E 新 C2a：统一主目标结果包

对应 2026-10-10 任务书 C2a，起点 commit `009f09b7276afbe962dff4bbcc5fa0324d432d79`，开发分支 `codex/c-h4e-followup`。本步在已复现的 H4E 基线上增加独立封装模块，不修改冻结目录或最大连通区域算法。

## 做成了什么

新增 [h4e_target_packet.v](../../rtl/recognition/h4e_target_packet.v)。区域核发布一次 T 主目标结果时，本模块把身份、配置、几何、有效性、原因和诊断一起锁存。A 控制端与 B 显示端使用同一份包，避免有人继续读取 F 全局框。

- 区域核在第 N 个上升沿产生结果，本模块在第 N+1 个上升沿更新完整输出，增加 1 个时钟的寄存器延迟。之前从像素到区域结果的可变延迟不变。
- `result_strobe=1` 的每个时钟都是一次事件。两个相邻周期都有结果时，strobe 可连续为高，两拍各消费一次；不能用上升沿检测代替逐拍使能。
- `target_valid=0` 仍有结果事件和正确身份，公开面积、中心、四边坐标统一清零；拒判原因和诊断保留。小目标、空帧、容量、期限错误都能通知下游。
- 没有事件时，除 strobe 回零外，其余输出保持。保持的 valid 不是新结果，也不能用于刷新来源超时计时器。
- 低有效异步复位清空所有输出。模块没有 ready、排队、跨时钟传输或去重，也不重新算中心、面积和拒判码。

生产者必须提供合法 T 结果：有效对应 E=0；无效对应 E=1/2/3/5。此模块清理无效几何，但不替生产者检查非法字段组合或修复来源身份。

## 接线与字段表

同一个像素/检测时钟域中，按下表一对一连接。所有 `t_*` 输入必须在 `t_result_strobe` 同拍属于同一个结果。**不要连接来自按钮、摄像头当前计数或其他实时寄存器的配置/身份。**

| 区域核输出/来源 | 封装输入 | 统一输出 | 位宽 |
|---|---|---|---|
| result_strobe | t_result_strobe | result_strobe | 1 |
| target_valid | t_target_valid | target_valid | 1 |
| result_frame_id | t_frame_id | frame_id | 32 |
| 当前 H4E 固定 0；后续为已与结果绑定的 epoch | t_capture_epoch | capture_epoch | 32 |
| result_cfg_id | t_cfg_id | cfg_id | 16 |
| result_target_id | t_target_id | target_id | 2 |
| area | t_area | area | 20 |
| cx / cy | t_cx / t_cy | cx / cy | 各 11 |
| xmin / xmax / ymin / ymax | 同名加 t_ 前缀 | 同名 | 各 11 |
| reason | t_reason | reject_reason | 3 |
| labels_used | t_peak_slots | peak_slots | 8 |
| components | t_component_count | component_count | 12 |

颜色 ID 仍是 0 红、1 绿、2 蓝，不是物体身份。中心为上游包围框中点；这里直接传递。错误 E=4 属于显示适配，区域核不产生。E3/E5 的区域数量诊断无效，不能据此声称场景为空。

包的有效载荷为 192 位，加 strobe 共 193 位寄存器。公开接口采用上表独立端口；测试中的拼接顺序为：valid、frame_id、epoch、cfg、color、area、cx、cy、xmin、xmax、ymin、ymax、reason、peak_slots、component_count。该测试拼接不是新增串口/网络传输协议。

当前接法仍使用 `h4e-refresh-v1` 的刷新号，epoch 接 `32'd0`。虽然封装已验证能保留任意 32 位 epoch，**这不等于实现 capture-v1**。真实 SOF 到结果的身份绑定、epoch 切换保护、重复来源抑制属于 C2b；A 的来源提交/DDR/CDC 和超时责任不变。

实际连接示例是可运行的 [选区核→封装 TB](../../sim/h4e_c2a/tb_h4e_target_chain.v)。A 只需在新板级工程显式增加本模块并接入 T 输出；不能递归导入整个仓库，也不在冻结 H4E 顶层直接改线。

## 验证和资源

详细结果见 [验收记录](../../reports/h4e-c2a/acceptance.md)。本轮：

- 282 拍封装测试，201 次事件：覆盖无效脏几何清零、无事件保持、连续事件、身份/配置/epoch 位宽、重复 ID 不去重、复位优先和异步清零。固定随机种子 20261010。
- 8 帧真实开发区域核→封装联合测试，12,288 个掩膜像素：有效→空→有效、最大区域选择、容量错误→恢复、重复 ID、贴原点及面积 255。SOF 之后故意改变输入实时身份，结果仍保留该帧 SOF 身份。
- 联合测试用 64×24 小光栅、R4 容量来快速触发错误；不改变生产 R64。几何来自独立 Python 8 邻域 flood fill；逐周期还检查完整 T 包至输出的 1 拍延迟、诊断传递和无事件保持。
- TD 6.2.168116 独立综合通过。封装层级为 **43 logic LUT、193 seq、0 ERAM、0 DSP**。不是 43 Slice；报告没有给本模块最终布局布线后的 Slice 增量。

综合测试顶层包含额外的 192 位输入暂存及读出选择器，总估计 166 Slice，这些测试电路不应导入板级工程，不能将 166 当作封装模块净增量。预期整机新增的是这份小型寄存器/逻辑，ERAM/DSP 增量为 0；精确 Slice 和时序须由 A 在完整工程确认。当前整机预算共享余量为 1,652 Slice、15 ERAM、0 DSP，不在本步更新为虚构的整机测量值。

这次未重新跑 19 分钟的冻结完整视频测试：选区核及冻结文件未改，C1 的完整视频结论仍保留，新增接口以实际核心的短联合测试验证。新板级顶层尚未集成或上板，也没有新增真实颜色效果结论。

## 复跑

在仓库根目录、已有 Python 3.12 环境下运行（脚本仅使用标准库）：

```powershell
$env:Path='C:/iverilog/bin;'+$env:Path
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c2a.py
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c2a_td.py
```

第二条需要 `td_commands_prompt` 在 PATH。两条脚本各自检查退出码、完成标志并生成 summary；输出在 `reports/h4e-c2a/generated/`。仿真显式源列表为 [h4e_c2a_sources.f](../../rtl/recognition/h4e_c2a_sources.f)，综合脚本只复制封装模块、综合测试顶层和 Tcl。当前没有生成 bit 或上板时序结论。

## 给 A、B 的假结果序列

[JSON 输入与期望](../../tests/fixtures/h4e_c2a/ab_demo.json) / [CSV 全字段输出](../../tests/fixtures/h4e_c2a/ab_demo_cycles.csv)。25 个采样周期应有 **13 次事件：9 次有效、4 次无效**。复位会清空输出但不产生事件。CSV 包含无事件保持的周期，便于发现重复消费。

用于接收端测试时，下降沿设置一整行 CSV 输出，随后上升沿按 `result_strobe` 锁存全部字段，每行持续一拍；不要只给有效事件，也不要只数 0→1 跳变。JSON 同时提供封装输入和期望输出；其 cycle 是封装 TB 上升沿后的采样序号，不是摄像头帧号。例中的红绿蓝、epoch 变化是接口测试，不是实拍。

| A | B |
|---|---|
| 检查 13 次事件及无效通知；包跨域时整体传输。真实控制新观察仍等 C2b 与真实来源接口。 | 检查同样 13 次事件，缓存完整 T 包；显示帧边界整体换框，不能逐字段更新，也不能画 F 全局框。 |

本步用户不需要手动操作开发板。A 集成新顶层后需确认：沿用原阈值和选区规则，T 框/中心与原 H4E 一致，空目标和超限不保留旧有效几何，新增一拍可正确进入显示快照，再重跑整机资源/时序并上板。若失败，回传源 commit、bit 哈希、时钟、同拍 strobe/身份/cfg/color/T 几何/E/诊断和场景；不要只回传独立 X/Y 数值。

下一步 C2b：沿像素到结果保存真实来源身份，用 `(capture_epoch, frame_id)` 抑制连续重复观察，并防止在途旧结果进入新 epoch。A 尚无实际来源接口时先用合成身份测试。
