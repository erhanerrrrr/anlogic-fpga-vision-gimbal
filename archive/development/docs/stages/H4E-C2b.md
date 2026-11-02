# H4E 新 C2b：来源身份、重复抑制与中断恢复

2026-10-10，起点 commit `009f09b7276afbe962dff4bbcc5fa0324d432d79`，分支 `codex/c-h4e-followup`。本步完成 C 端合成来源测试和独立综合；A 尚未提供真实采集身份接口，没有新增整机或上板验收。

## 本步解决的问题

同一张摄像头图像可能被 HDMI 重复显示。现在 C 将“有一份可显示结果”和“有一次新的控制观察”分开：

| 来源图像 | result_strobe | new_observation |
|---|---|---|
| epoch=7，ID=10，第一次完成 | 1 | 1 |
| epoch=7，ID=10，再次处理 | 1 | 0 |
| epoch=7，ID=11，第一次完成，即使无目标 | 1 | 1 |
| epoch=8，ID=11，来源重启后的新图像 | 1 | 1 |
| epoch=8 生效后到达的 epoch=7 旧结果 | 0 | 0 |
| 不再输入图像、结果字段仍保持 | 0 | 0 |

只比较 `(capture_epoch, frame_id)` 是否与上次已通知观察相同，不比较大小，因此 FFFFFFFF→00000000 正常。cfg 改变不把旧图像变成新观察。仅抑制连续重复，不能识别任意历史重放；A 仍须保证来源有序。

## 实现与资源选择

- [capture_frame_guard](../../rtl/recognition/capture_frame_guard.v)：SOF 锁存身份和配置，只保留一个在途帧。两个像素寄存器为处理核清空状态留出一拍，不缓存整帧。
- [capture_observation_guard](../../rtl/recognition/capture_observation_guard.v)：只保存上次通知的 64 位身份及一个有效标记，不再复制 C2a 的 192 位结果载荷。
- [h4e_capture_tracker](../../rtl/recognition/h4e_capture_tracker.v)：将上述适配器、原 RGB 分类器、3×3 滤波、H4E 最大区域核与 C2a 包连接起来。固定白平衡后的 RGB888 为入口，上下四行保护、5/9 去噪、面积≥256、8 邻域选最大和中心取整规则均保留。

已有分类、滤波、区域核和 C2a 包源码没有改动。每次接纳 SOF 或中断时，guard 发一个时钟的内部清空脉冲，仅清处理核控制/窗口状态；既有 RAM 不清空。输入先经过两拍像素寄存器，确保新首像素在处理核复位释放后进入。`processing_rst_n` 只供该同域识别分支使用，不复位来源控制器、C2a 已发布包或观察历史。

独立 TD 层级报告：

| 新模块 | seq | logic LUT | ERAM / DSP |
|---|---:|---:|---:|
| 输入/在途帧保护 | 233 | 120 | 0 / 0 |
| 观察重复抑制 | 65 | 0 | 0 / 0 |
| 两个身份模块合计 | **298** | **120** | **0 / 0** |

logic LUT 按本次工具层级归属报告，跨层优化可能移动或合并逻辑，观察模块的 0 不表示比较功能不存在。不能把这些数当成新增 Slice。两拍像素寄存器已包含在输入保护的 233 个寄存器里。

生产尺寸 1280×720、R64 的整条识别分支含原有滤波 2 ERAM、区域核 3 ERAM，共 5 ERAM；身份功能未新增 RAM，也不用 DSP。综合测试顶层估计 1,519 Slice，**包含原有识别算法、C2a 包及测试读写电路，不是本步净增量**。不要把它直接加到原整机 12,348 Slice 上。A 在新顶层替换/适配原识别分支，不能平行再放一整套识别器。完整板级 Slice 增量与时序仍待 A 集成确认。

## A 的同域接线约定

这是开发适配约定，A 集成时需对接实际 DDR 元数据及复位协议：

| 输入 | 要求 |
|---|---|
| clk / rst_n | 同一识别时钟域；低有效复位。整机复位必须共同清空来源缓存与消费者历史 |
| pixel_valid / rgb / x / y / sof / eof | 完整光栅，不删黑像素；SOF=(0,0)，EOF=(W−1,H−1)；行内连续，行间可消隐 |
| source_frame_id / source_epoch | 从实际读出的 DDR 图像元数据取得，在有效 SOF 被锁存；不得拿 HDMI 刷新号冒充采集号 |
| active_epoch | A 当前认可的来源代次，独立于读出缓存携带的 source_epoch；不能接成“当前读到的旧帧 epoch” |
| source_flush | 同域清空屏障。重启时建议至少保持一个采样沿，丢弃在途处理及当拍结果；随后 epoch 稳定，再送完整 SOF |
| requested_cfg_id / requested_color / requested_min_* | **保持型待用配置值**，在下一新来源 SOF 采样；不是按钮单拍脉冲接口 |

即使没有 source_flush，active_epoch 改变也会撤销旧在途帧，并在结果出口挡住旧 epoch。active_epoch 和 source_flush 必须经 A 同步到此时钟域，满足采样时序；C 不承担这两个外部信号的 CDC。

所有输入来源身份都必须是 A 为已完整提交图像绑定的真实值。现有冻结 H4E 仍是 `h4e-refresh-v1`；开发顶层通过合成数据验证了 capture-v1 的 C 端语义，不能据此宣布整机 capture-v1 已实现。

配置首值沿用红色 cfg=1、24/16/16；第一张新来源 SOF 采样 requested 值。相同身份再次输入时，保持原阈值、颜色和 cfg，即使中间发生半帧中断后重试也一样。请求值需要由上游保持到下一新来源 SOF；C3c 后续实现标定 pending、busy、仲裁和 cfg_applied，本步没有完整实现那些交互状态。

## 单在途帧与错误恢复

不增加帧队列的代价是：若上一帧尚未交给 C2a 包就到达新 SOF，丢弃旧任务，`frame_abort` 提示一次，再开始新帧。已完整输入但尚未冲刷完的帧也可能被新 SOF 替代。正常原生视频消隐应留足冲刷时间；不能宣称任意零消隐输入都不丢观察。

中途停在行内、坐标跳变、EOF 位置错误、非法 SOF 会清理任务；已中止的数据不拼入下一帧。行间停止可保持半帧等待，但不会凭空产生结果；下次 SOF 会重新开始。没有有效 SOF 的散落像素被忽略。

`frame_abort` 和 `stream_error` 是单拍诊断，不伪造一个区域核 E 码或新观察。没有完整输入 EOF 就不会接纳区域结果；接纳时还核对帧号、cfg、颜色。已经交付给包的结果自带 epoch，再由出口资格检查屏蔽重启后的旧包。

来源停顿时，最后一张完整输入的帧可以有限冲刷后产生一次结果，之后保持 valid 不会再触发事件。C 不加时间戳或超时计数器；A 根据真实来源提交和 `new_observation` 独立维护 source_timeout/result_timeout。

## A、B 如何消费

两者使用同一份 C2a 包，包括 epoch、frame、cfg、颜色、面积、位置、E 和诊断：

- B 在 `result_strobe` 时接收整包，可接收同源重复处理结果；显示换框仍在显示帧边界完成，并按团队约定标明来源/年龄。
- A 仅在 `new_observation` 时消费新的控制观察；无目标的新图像也会通知，由 A 决定保持/重获，不丢掉无效结果事件。
- 两个资格信号由已寄存包、同域来源控制和观察历史组合产生。接收端在上升沿**同拍采样事件、fresh 标记与整包**；不能分别延迟后拼接，也不要只检测信号上升沿。
- 若跨域，用原子邮箱/异步 FIFO 一起传包和标记。C 出口之后排队的旧包由 A 在接收端再次校验 active_epoch；C 无法清理 A 的外部 FIFO。

`accepted_sof` 表示接纳一个输入任务，`new_source_sof` 表示与上次接纳来源不同，可供后续采样/配置请求使用；半帧也可能已经有 new_source_sof，但没有 new_observation。二者不能当成同一事件。

## 已完成的验证

[验收记录](../../reports/h4e-c2b/acceptance.md)保存完整证据。本轮 25 个合成场景、144,240 个时钟，15 次结果、13 次新观察；37,906 个分类像素逐项核对，另有 49 拍观察器边界测试。独立软件直接计算 RGB 分类、3×3 多数表决及 8 邻域几何，不读 RTL 内部表生成期望。

覆盖 10/10/11、帧号回绕、epoch 变化且 ID 相同、旧 epoch SOF、EOF 后换代（有/无 flush）、重复帧改阈值/颜色、帧内请求变化、半行/半帧、错误坐标、过早 EOF、缺少 SOF、全局复位、新 SOF 打断旧尾部以及停帧。被主动中止的任务没有输出假结果。测试中最后完整帧在 EOF 后 74 拍通知，随后 1,974 拍没有新事件；这是 64×32 案例的测量，不是 720p 最坏延迟保证。

运行命令（Python 标准库，无新增 Python 依赖）：

```powershell
$env:Path='C:/iverilog/bin;'+$env:Path
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c2b.py
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c2b_td.py
```

显式源列表：[h4e_c2b_sources.f](../../rtl/recognition/h4e_c2b_sources.f)。第二条需要 TD 命令工具在 PATH。大型逐像素日志在 generated 目录，不入库；[A/B 合成事件示例](../../tests/fixtures/h4e_c2b/source_events.csv)给出本轮完整结果和新观察标记，实际帧驱动由固定脚本生成。

事件示例只列有事件的周期，各行 result_strobe=1；回放时按 cycle 间隔补 strobe=0 的周期，不把相邻 CSV 行误当成相邻时钟。[场景 JSON](../../tests/fixtures/h4e_c2b/scenarios.json)还包含无输出的中止场景和待用/实际配置。

本步未重新跑冻结长视频，也没有新 bit。A 接真实来源后应检查来源 ID/epoch 与 DDR 槽绑定，重启屏障与外部 FIFO 清空、停止采集时仍显示旧图像但无新控制观察、半帧恢复和真实 720p 吞吐。还需对内部处理复位的高扇出、释放时序及完整数据通路进行约束和布局布线。失败时回传源 commit、bit 哈希、时钟、输入 SOF/EOF/坐标/身份、active_epoch/flush、活动配置、abort/error 及输出整包/两种事件。

下一步 C3a：仅采样中央 16×16 ROI，统计颜色，暂不改阈值；使用小型累加器及移位均值，继续避免 DSP 和整帧缓存。
