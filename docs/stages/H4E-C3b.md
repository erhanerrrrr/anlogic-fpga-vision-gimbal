# H4E 新 C3b：判断样本并计算候选参数

前置 HEAD：`009f09b7276afbe962dff4bbcc5fa0324d432d79`；本地承接新 C1/C2a/C2b/C3a。共同板测基线 `7eb4a90` 不变。本次是开发分支的合成数据验收，未上板、未推送 GitHub。

## 做了什么

新模块 `h4e_calibration_candidate` 接收 C3a 完成统计，检查样本质量，输出候选颜色及三个阈值；新封装 `h4e_candidate_tracker` 包含原采样/检测链和候选模块。没有任何候选输出连回检测配置，原识别入口仍由 requested 配置驱动，默认红色 24/16/16 不变。

入口使用固定白平衡后的 RGB888，必须在 gamma、灰度和 OSD 之前；均值为 C3a 的整数向下取整值。阈值单位与现有 `color_classifier_runtime` 一致，比较均为大于等于：主通道强度、主通道减其余两个通道。

审查后沿用 C9 的样本质量与减裕量规则，另建可参数化开发模块，旧 `calibration_params.v`、`calibration_control.v` 不改、不接入。C9 的样本亮度下限 80 不等于当前识别阈值；本步没有恢复旧 80/40/40 检测预设。

## 规则（可配置、尚待实拍验证）

默认综合参数如下；参数均为 0..255 的无符号整数，MAIN_LOW 应不大于 MAIN_HIGH。修改参数后必须重跑测试和综合。

|参数|默认值|含义|
|---|---:|---|
|MAIN_LOW / MAIN_HIGH|80 / 224|最强通道均值允许范围，包含边界|
|MAX_SPREAD|32|每个 RGB 通道 max-min 均不得超过此值|
|MIN_DOMINANCE|40|主通道均值必须分别比另外两通道高至少此值|
|MARGIN|32|从主通道均值和两个差值各减去的裕量|

按下表优先级返回失败原因；候选计算失败时，颜色和三个候选阈值全部清零，活动配置保持原状。

|reason|条件|
|---:|---|
|6|接收 sample_done 时 source_flush 有效，或样本 epoch 已非当前 epoch|
|1|sample_ok=0 或 count 不等于 256|
|2|任一通道不满足 min ≤ mean ≤ max|
|3|最强通道均值不在 [MAIN_LOW, MAIN_HIGH]|
|4|任一通道跨度超过 MAX_SPREAD|
|5|任一个主通道优势不足 MIN_DOMINANCE|
|0|通过，生成候选参数|

最强通道作为 candidate_color：0 红、1 绿、2 蓝。并列时按红、绿、蓝的先后次序选；默认优势门槛会拒绝并列。candidate_color 可以与采样时人工选择的目标颜色不同，只是提案，不会改变正在跟踪的颜色。`calibration_target_id` 保留采样时的目标颜色，不能与候选颜色混用。

候选值为 `clamp(value - MARGIN, 0, 255)`；红色差值顺序 R-G/R-B，绿色 G-R/G-B，蓝色 B-R/B-G。运算在扩展的有符号位宽中进行，再限幅，不会发生无符号减法回绕。没有乘法、除法、帧存储或新数组。

亮度、均匀度、主色优势只是低成本的质量判断，不保证所有混色或反光都能识别。只有均值/min/max，无法恢复颜色分布。真实固定白平衡 RGB 和光照效果尚未提供，默认值保留为可验证的候选规则，不能宣称已证明现场标定有效。

## 事件与接线

- 源列表：`rtl/recognition/h4e_c3b_sources.f`；顶层 `h4e_candidate_tracker`。不要递归编译全仓库。
- 所有输入同域；上游在时钟沿提供 sample_done 及整组稳定统计/身份。C3b 在该时钟沿注册输出，整体链中 calibration_done 比 C3a 的注册 sample_done 晚一拍。
- 输出 calibration_done、calibration_ok、calibration_reason、calibration_frame_id/epoch/cfg_id/target_id，以及 candidate_color/min_main/diff_1/diff_2；没有 cfg_applied、没有 pending，也不递增 cfg。
- done 以外的输出保持到下一份样本完成；消费者要同时看 done 和 ok，不能把保持的 ok 当作新事件。相邻两个 sample_done 高电平时钟可产生两次独立事件。
- reset 清空全部输出，没有完成事件。没有 sample_done 时，flush/epoch 变化不生成新的事件；消费端应对队列中的旧 epoch 候选再次检查。
- 此封装的 busy、request_ignored 仍是 C3a 的采样请求语义，仅包括等待/采样/整帧验证，不是未来完整标定操作的 busy。C3c 才统一等待、计算和待应用阶段的请求仲裁。本模块本身每拍可处理一份样本，无忙碌队列。
- sample_done 只代表采样完成；calibration_done 只代表本次候选计算结束；calibration_ok=1 仍不等于 cfg_applied。

## 样例

来自真实 RTL 的合成 ROI 输出，完整事件文件在 `tests/fixtures/h4e_c3b/candidate_events.csv`：

|ROI 样本|结果|候选 main/diff1/diff2|
|---|---|---|
|均匀 RGB (220,30,10)|红色候选|188 / 158 / 178|
|均匀 RGB (20,200,40)|绿色候选|168 / 148 / 128|
|均匀 RGB (15,25,210)|蓝色候选|178 / 163 / 153|
|均匀 RGB (255,255,255)|reason=3，过亮|0 / 0 / 0|
|C3a 渐变/双色 ROI|reason=4，跨度太大|0 / 0 / 0|
|采样中断|reason=1；epoch 撤销时优先 reason=6|0 / 0 / 0|

## 本次验证

- 独立 Python 整数参考：每配置 3,110 拍，共 3 配置 / 9,330 拍逐字段对比，包含 110 条定向/时序向量和固定种子 3,000 条随机向量。检查默认规则、全范围且裕量为 0、全范围且裕量为 255。
- 覆盖红绿蓝、灰色/双色并列、亮度 79/80/81 和 223/224/225、通道跨度 31/32/33、优势 39/40/41、count 255/256/257、非法 min/max、错误优先级、身份大值、连续事件、无事件保持和复位。
- 对 RTL 实际减裕量函数穷举有符号输入 -512..511，3 种裕量共 3,072 组限幅检查；正常 RGB 输入无法触达的高端限幅也有覆盖。
- C3a sampler + 真实 guard + 候选模块联合仿真：14 个采样事件，6 个可用候选；失败和身份逐字段对比参考。样本 TB 采用 32×32 完整光栅，不声称本步重跑了 720p。C3a 的 720p 证据保留有效，原模块未改。
- 候选模块接入完整开发检测封装后的回归：25 场景、144,240 拍、15 份检测结果/13 次新观察、37,906 个分类像素与独立 C2b 参考一致。配置探针确认采样/候选计算未混入检测参数。
- 故意损坏候选差值，比较器能检出；check PASS 与 frozen bit 哈希另存。测试只说明模型/RTL一致，不证明真实环境效果。

## 资源与延迟

TD 6.2.168116，PH1P35MDG324：候选模块 **113 seq、127 logic LUT、33 ripple、0 ERAM、0 DSP、0 distributed RAM**。包含全部身份和结果保持寄存器；比较、差值和减裕量为组合逻辑。输入事件到注册结果 1 个时钟级，不增加区域检测流水线延迟。

综合测试顶层含输入暂存及输出读选择，估计 244 Slice；它不是候选模块净 Slice，也不能直接加到整机资源。团队板级基线仍为 12,348 Slice / 45 ERAM / 8 DSP；1,652 Slice / 15 ERAM / 0 DSP 的剩余预算由各组共享。本模块不占 ERAM/DSP，但 A 必须合入后重新验证整机资源和时序。

综合保留 75 个测试端口未绑定管脚的告警，没有板级时钟/管脚签核，也未做门级等价验证。

## 复跑与交付

在仓库根目录，Python 3.12、Icarus/TD 在 PATH：

```powershell
$env:Path='C:/iverilog/bin;'+$env:Path
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3b.py
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3b_chain.py
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3b_td.py
./tmp/h4e-env/Scripts/python.exe -X utf8 boards/hx1p35a/h4e/run.py check
```

队友可将 Python 路径换成本机环境；不需要第三方 Python 数值库。生成目录 `reports/h4e-c3b/generated/` 被忽略，定向向量、原始候选样例、版本/退出码/哈希和综合报告见 `reports/h4e-c3b/evidence/2026-10-10/`。大逐拍向量和结果由脚本重生成，不进入证据目录。

A 可在新开发工程读取候选输出，保持现有配置不变；B 如显示标定状态，应显示“候选通过/失败原因”，不能显示“已应用”。当前不要求队友立即改动。上板时需先核对入口 RGB、source identity、样本统计，再检查候选结果和活动配置不变；失败回传 bit/commit 哈希、入口 RGB、采样统计、请求/完成/flush、epoch/ID/cfg 和候选事件。

下一步 C3c：新来源帧开始时整体应用 pending 参数，并统一忙碌、人工选色和标定请求仲裁。
