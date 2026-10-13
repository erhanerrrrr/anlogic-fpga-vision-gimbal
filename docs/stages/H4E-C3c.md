# H4E 新 C3c：在新来源帧边界应用参数

前置 HEAD：`009f09b7276afbe962dff4bbcc5fa0324d432d79`，本地承接新 C1/C2a/C2b/C3a/C3b；共同板级基线 `7eb4a90`。本次只改开发模块，冻结目录及既有 bit 未修改，未推送 GitHub。

## 功能与资源设计

新增 `h4e_calibration_control` 和组合封装 `h4e_calibrated_tracker`。控制器保存一份 pending 参数和操作 epoch，复用 C2b 帧入口 guard 已有的 active 配置寄存器；不重复存 active，不增加来源帧历史表、帧缓存或参数 FIFO。

新顶层使用 `rtl/recognition/h4e_c3c_sources.f`。A 接 `calibrate_req`、`color_select_req`、`color_select`，替代 C3b 顶层外部 requested 配置与 sample_req。C3a/C3b 的统计、候选、识别结果接口继续保留；busy/request_ignored 改由完整操作控制器统一提供。

复位仍为 cfg_id=1、红色、24/16/16。人工选红/绿/蓝分别将目标颜色设为 0/1/2，恢复本步明确约定的 24/16/16 预设；非法颜色 3 拒绝。绿色/蓝色预设仅完成合成输入测试，未声称板上光照效果已验证。历史 C9 的 80/40/40 不接入。

## 应用规则

1. 空闲时接受单拍标定请求，启动 C3a，等待请求之后的下一幅新来源帧采样；标定和人工选色同拍时标定优先，选色产生 select_ignored。
2. busy 包括等待新帧、采样、整帧验证、候选计算、pending 待应用及取消后的两拍收尾。期间额外请求直接忽略，无队列。
3. 候选成功进入 pending；失败释放操作并保留 active。人工选色直接生成 pending，之后也必须等新来源帧。
4. pending 已存在，且遇到当前 epoch 下合法 `new_source_sof`，同一时钟沿将颜色和三个阈值整体送给原 guard，cfg_id 加一（16 位回绕），产生注册单拍 cfg_applied。
5. 重复 `(epoch,frame_id)` 不触发应用。人工选色请求或候选完成恰逢 SOF 时，旧 pending 不存在，该帧仍使用旧参数，下一个新来源 SOF 才应用。
6. 完成/应用同拍的新请求仍按进入该拍前的 busy 状态忽略。失败完成后下一拍可再请求；成功完成后仍需等 pending 应用。应用后的下一拍可再请求。
7. 整帧像素均使用 guard 在 SOF 锁定的同一组配置；首像素经既有两拍像素暂存与流水线复位后进入分类器，使用新配置。后续 requested 反馈变化不会在帧中生效。
8. 在途上一帧遵守 C2b 的单任务策略：新 SOF 会取消尚未发布的旧结果。已输出的旧帧结果保留旧 cfg；不会给旧结果换成新 cfg。不新增结果队列或积压处理能力。

`cfg_applied` 在应用时钟沿之后拉高，消费者读取时应同时读取 active_cfg_id/color/thresholds。`calibration_cfg_id` 是采样时使用的旧配置版本，不是将来应用后的版本；识别结果包中的 cfg_id 则表示该结果实际使用的配置。

## 取消与时序边界

- source_flush 或操作 epoch 改变，取消等待/采样/pending；operation_cancelled 通知取消。内部 operation_flush 同时送给已有采样/检测链，阻止旧样本继续进入新操作。活动配置保持原值，只有全局 reset 恢复基线。
- 取消后增加两拍 busy 收尾，排掉“采样完成→候选完成”的旧注册事件。收尾期的新请求忽略；第三个时钟沿可接收新请求。若后续更改 C3a/C3b 的流水线延迟，必须同步调整收尾长度和测试。
- C3b 的原始 calibration_done/ok/reason 仍作为计算诊断输出；取消后可能迟到一份失败诊断，控制器不会接纳它为新的 pending。B 在收到 operation_cancelled 后应以“已取消”为当前操作状态，不能把诊断事件当作已应用。
- 若 flush 持续有效，不能接受请求。source_flush 和按钮请求应为同域控制信号，按钮去抖/CDC 由 A 负责；高电平保持的请求会在以后空闲时再次被接收，调用方必须发单拍。
- 全局 reset 清除 active/pending/操作及采样候选流水线，不产生应用事件。半帧错误导致采样失败；若只是来源停在行间而未报错，A 仍须用超时 source_flush 取消，C 没有新增超时计数器。
- 没有候选参数持久化、断电保存、撤销栈或多请求排队；跨域结果/状态队列仍须验证当前 epoch。

## 与 B 共享的事件

|事件|含义|建议显示|
|---|---|---|
|busy=1|操作进行中，包含取消收尾|等待/处理中|
|request_ignored / select_ignored|该请求未进入队列|忙碌或请求被忽略|
|sample_done|统计完成，可能失败|采样状态|
|calibration_done + calibration_ok|候选计算通过，尚未应用|候选通过|
|pending_valid|正在等待下一新来源帧|等待新帧|
|cfg_applied|该新帧已整体切换配置|已应用及 active cfg|
|operation_cancelled|来源被撤销/flush 导致取消|已取消|

实例 CSV 位于 `tests/fixtures/h4e_c3c/`：configs 为各帧实际配置，controls 为忽略/取消/应用事件，candidates 为候选计算诊断，results 为识别结果。cycle 是测试时钟编号；attempt 在帧间控制事件上仍表示最近一次帧尝试，不能当作控制请求自己的帧 ID。须配合 frames.json 中的场景、epoch、来源 ID 阅读。

## 本次验证

- 2,542 拍控制协议测试（42 条定向时序及固定种子 2,500 条随机输入），独立 Python 状态参考逐字段对比。
- 定向验证标定优先、非法选色、完成/应用同拍请求忽略、候选与 SOF 同拍、flush/epoch 优先取消、两拍收尾、旧完成隔离、复位。cfg 回绕在控制单元的真实反馈寄存器测试为 65534→65535→0；完整封装的复位值仍为 1。
- 19 组完整/中断 RGB 场景，142,635 时钟、37,507 个实际分类像素检查，逐像素配置和分类结果均符合独立参考；16 份识别包的几何、身份、cfg、有效性与重复观察标志一致。
- 3 次应用：红色候选 cfg2、绿色候选 cfg3、人工蓝色 24/16/16 cfg4。3 次来源撤销/flush 取消；4 次标定请求忽略、3 次选色请求忽略。
- 5 个候选诊断：2 次成功、灰色失败、epoch 取消后的迟到失败、半帧失败；SOF 同拍候选在后续帧才应用。
- 红色基线 24/16/16 首帧及复位后均得到原规则结果。加入变严的红色阈值后，原暗红目标变空；绿色候选应用后绿色目标被识别；人工切蓝恢复预设后蓝色目标被识别。
- 2 个 EOF 后仍在处理的旧帧被新 SOF 取消（其中一个发生在参数应用时），1 个半帧失败；不会冒充完成结果。其余 16 帧均完整检查；部分帧结果为“无目标”，同样检查 cfg。
- 故意篡改结果 cfg，比较器能检出。冻结源/bit 哈希校验、显式源列表 Icarus -Wall 编译均通过。

联合测试采用 64×32 合成光栅及合法行间空隙，方便快速覆盖时序；没有重复跑整套 720p 检测仿真。未变更的 C3a 720p 采样、C3b 参数规则及冻结基线证据继续保留，并验证源哈希未变。测试不是实拍识别效果或板级时序签核。

## 资源与时序边界

TD 6.2.168116 / PH1P35MDG324，新增控制模块独立综合：**65 seq、57 logic LUT、16 ripple、0 ERAM、0 DSP、0 distributed RAM**。所有参数均为小寄存器，cfg 增量使用加法进位；无乘除、帧缓存或候选队列。

含输入暂存与输出读取夹具的测试顶层估计 146 Slice，不是新增模块净 Slice。C3a 的 373 seq/211 LUT 和 C3b 的 113 seq/127 LUT 是先前分别综合的模块数据，不能相加当整机 Slice。整机基线仍为 12,348 Slice / 45 ERAM / 8 DSP；预算剩余 1,652 Slice / 15 ERAM / 0 DSP 由团队共享。

独立综合保留 75 个测试端口未绑定管脚告警，尚无新顶层布局布线结果。新增 pending→requested→guard 的组合路径需由 A 在整机时钟约束下验证；未宣称该路径已达到像素时钟。原检测行处理/区域容量不变，沿用 C1/C2b 的证据与限制。

## 复跑

仓库根目录，Python 3.12、Icarus/TD 在 PATH，无额外 Python 数值库：

```powershell
$env:Path='C:/iverilog/bin;'+$env:Path
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3c.py
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3c_td.py
./tmp/h4e-env/Scripts/python.exe -X utf8 boards/hx1p35a/h4e/run.py check
iverilog -g2012 -Wall -s h4e_calibrated_tracker -o tmp/c3c_lint.vvp -c rtl/recognition/h4e_c3c_sources.f
```

队友可替换成本机 Python 路径。大逐像素 CSV、vvp 与向量进入 ignored 的 `reports/h4e-c3c/generated/`，小型结果、时序样例、版本/退出码/哈希、原始资源表和告警存入 `reports/h4e-c3c/evidence/2026-10-10/`。

## A 的集成和人工验证

1. 在新开发工程使用 C3c 明确源列表和顶层，不修改冻结板级快照；连接固定白平衡 RGB888、连续坐标/SOF/EOF、真实来源 ID/epoch、当前 active_epoch、flush。
2. 替换外部 requested 配置驱动为本步的单拍标定/人工选色请求，保持 C 的 active 配置反馈内部闭合；按钮去抖、跨域、源超时仍由 A 负责。
3. 先关闭用户请求，确认复位 red/cfg1/24/16/16 及检测包与共同基线一致，再进行整机资源、布局布线、像素时钟时序和 bit 构建。
4. 色卡完整覆盖中央 16×16，发标定请求；检查 sample_count=256，候选完成时 active 尚未变，在下一真实新帧 cfg_applied 后才整组变化。
5. 重复来源帧应一直等待；标定中按选色/再次标定应忽略；人工选色到下一新帧才生效。以灰色/暗色触发失败，验证旧配置保持。
6. 在等待/pending 阶段切 epoch 或 flush，验证取消与两拍收尾；恢复后新请求能工作，旧结果不能应用。检查 cfg 包、frame ID 和 active 配置一致。

失败回传 commit/bit 哈希、入口 RGB、源 epoch/ID、cfg/颜色/阈值、请求/样本/候选/pending/cfg_applied/cancel 时序、综合/时序报告。真实来源接口和实拍数据尚未提供，本步不生成新 bit，不宣称上板通过。

下一步 C4：准备真实检测入口 RGB 回放和鲁棒性验证；如果 A 仍无实拍数据，先完成格式校验、回放工具和合成样本测试。
