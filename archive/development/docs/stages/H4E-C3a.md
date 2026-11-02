# H4E 新 C3a：中央 ROI 采样（开发版本）

前置 HEAD：`009f09b7276afbe962dff4bbcc5fa0324d432d79`，本地承接新 C1/C2a/C2b；板级基线 `7eb4a90`。本步只采样，不计算候选阈值、不应用新配置。冻结目录、已验收 bit、最大区域算法均未改动。

## 实现与资源选择

`h4e_sampling_tracker` 包含一份原有 `h4e_capture_tracker` 和一份 `h4e_roi_sampler`。后者旁路读取相同的固定白平衡 RGB888（gamma/灰度/OSD 之前），复用前者已有的 `accepted_sof/new_source_sof/frame_abort`；不复制帧检查器、来源历史或检测链。必须使用 `rtl/recognition/h4e_c3a_sources.f`，不要递归编译全仓库。

720p 采样区域为 x=632..647、y=352..367，首尾都包含，256 个像素。32×32 测试区域为 x/y=8..23。参数化尺寸要求 WIDTH、HEIGHT 至少 18，坐标能由 11 位表示。不是图像缩放模块。

计数器为 9 位，总和每通道 16 位（最大 65280）；min/max 为 8 位。均值向下取整，成功时取总和的高 8 位，无除法器、乘法器或整帧缓存。保留累加器及上一份完成结果，使忙碌期间读取旧结果仍保持稳定。

## 请求、身份与时序

- `sample_req` 是同一时钟域内的单拍请求。空闲时接收，等待请求之后的下一次 `new_source_sof`。请求恰逢 SOF 时跳过该帧；等待、采集、验证均属于 busy。
- 同一 `(source_epoch, source_frame_id)` 连续重放不会启动采样。新 epoch 的同号帧可启动。新来源判定直接复用 C2b，不维护第二份 ID 表。
- 开始时锁定该 SOF 的 source ID/epoch 和 requested cfg/color；这些值也是 C2b 在该新 SOF 应用的配置。采样器没有任何检测配置写接口。
- busy 内请求（包括完成/取消同拍）只产生 `request_ignored` 单拍，不排队、不累计计数。下一拍才可再接收。请求若保持高电平会在下一次空闲时再次被接收，上游应提供脉冲。
- 在原始输入 EOF 后多等一拍，接收现有帧检查器的注册 abort，再发布结果。中央窗口结束后仍继续保持 busy，直到整帧完成或取消。
- 新 SOF 打断当前采样、epoch 撤销、flush、坐标/行内连续性/EOF 错误均取消采样。guard 对旧检测任务的 SOF 取消脉冲不会误杀刚启动的新采样。
- 中断返回 done=1、ok=0、reason=2，所有统计清零；需要重新请求，且同身份重试仍不能作为新的采样帧。等待期间 flush 也返回 reason=2，身份字段为零。
- 完整但不足 256 个样本时 reason=1；正常受 guard 保护的合法参数光栅不应触发。成功 reason=0，count=256。
- 全局复位清空等待、采集和结果，不产生 done。不要连接检测流水线的 `processing_rst_n` 到采样器复位。
- `sample_done` 是注册单拍，结果保持到下次完成/取消；消费者在时钟沿同时读取 done 与全部字段。`sample_ok` 描述最后一次完成，不能单独作为新事件，也不代表标定成功或 cfg_applied。
- 行间停流可能无限等待：超时仍由 A 检测并发出 `source_flush`，本模块没有额外定时器或 CDC。已发布结果若经过跨域队列，A/B 消费者仍需检查当前 epoch。

## 验证和示例

独立 Python 参考对 256 个 RGB 三元组直接求 sum/min/max/整数均值，不照抄 RTL 状态机。32×32 状态测试检查重复帧、SOF 同拍请求、busy、完成同拍请求、中断、flush、epoch、早 EOF、等待/采样复位。另跑 8 幅完整 1280×720 光栅：2 幅用于同拍请求/重复跳过，6 幅成功样本覆盖均匀红绿蓝、255 最大值、渐变、双色。

ROI 外使用不同颜色，逐个遍历所有边界，统计与独立参考比较；没有省略非 ROI 像素来冒充完整光栅。无波形、无大逐像素文件落盘。

|输入|count|RGB sum|RGB mean（向下取整）|
|---|---:|---|---|
|均匀 (220,30,10)|256|56320,7680,2560|220,30,10|
|均匀 (255,255,255)|256|65280,65280,65280|255,255,255|
|梯度 r=16x+y,g=255-r,b=r//2|256|32640,32640,16256|127,127,63|
|各半 (20,50,230)/(201,100,3)|256|28288,19200,29824|110,75,116|

联合测试在新封装中保持采样请求活动，重用 C2b 独立参考检查 25 场景、15 份检测结果、13 次新观察、37,906 个分类像素；确保采样不会改变阈值、分类及最大区域结果。完整 720p 测试针对采样器及真实 guard；本步没有重跑整套 720p 区域检测长仿真。

## 资源与限制

TD 6.2.168116 / PH1P35MDG324 独立综合采样模块：373 个 seq、211 个 logic LUT、48 个 ripple、0 ERAM、0 DSP、0 distributed RAM。包含可观察输入寄存器和读出多路器的整个测试顶层估计 386 Slice，这不是采样模块净 Slice 增量，也不是整机资源。计数/累加采用加法进位逻辑。

当前板级基线为 12,348 Slice / 45 ERAM / 8 DSP；相对团队预算仍有 1,652 Slice / 15 ERAM / 0 DSP 供各方共同使用。本次新增采样不使用 ERAM/DSP，实际 Slice 余量必须由 A 合入整机后布局布线确认，不能将 LUT/寄存器数直接相加当 Slice。

独立综合 75 个测试端口未分配管脚的告警保留在日志；不是板级管脚、时序或门级等价验收。本步没有新 bit，也没有真实摄像头输入验收。

## 复跑

仓库根目录，Python 3.12，Icarus/TD 在 PATH：

```powershell
$env:Path='C:/iverilog/bin;'+$env:Path
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3a.py
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3a_chain.py
./tmp/h4e-env/Scripts/python.exe -X utf8 scripts/run_h4e_c3a_td.py
./tmp/h4e-env/Scripts/python.exe -X utf8 boards/hx1p35a/h4e/run.py check
```

`tmp/h4e-env` 是本机环境路径，队友可替换成自己的 Python 3.12。生成文件进入 ignored 的 `reports/h4e-c3a/generated/`；摘要、小型结果、哈希、退出码和综合原始报告存于 `reports/h4e-c3a/evidence/2026-10-10/`。

## A/B 后续工作

A 使用新封装接真实来源 ID/epoch、同域 RGB/坐标、flush 与采样请求，保持现有检测默认红色 24/16/16；仅在独立开发工程集成，重新做整机资源/时序/上板检查。B 如需显示采样状态，可读 busy、request_ignored、sample_done/sample_ok/reason 与整组统计；本步不要求改显示模块，尚未实现中央框 OSD。

实物时将色卡完整覆盖中央 16×16 区域，发一次请求，检查 count=256、颜色均值及帧身份；重放旧帧不得完成新采样，断流/切 epoch 不得发布混合统计。失败回传 bit 哈希、source ID/epoch、cfg/阈值、请求/SOF/EOF/abort 事件和检测入口 RGB。没有真实样本前，不能证明照明/反光下标定有效。

下一步为 C3b：审查样本质量、计算候选颜色与阈值；仍不自动应用参数。
