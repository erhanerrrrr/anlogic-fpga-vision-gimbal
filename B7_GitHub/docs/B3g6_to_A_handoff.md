# B3g6 给 A 的板级接入条件（2026-10-19）

适用范围：`video_b3_h4e_sameclk.v`，同一像素时钟域内的 B 显示链加未修改的 H4E 选区。输入身份为 `{epoch[31:0], frame_id[31:0], cfg_id[15:0], target_id[1:0]}`。显示层只有四项全匹配才绘制目标框；无匹配结果时显示 WAIT。`frame_id` 必须是完整来源图像的 ID，重复显示同一图像时保持不变。测试台目前给的是合成身份，尚未接真实采集元数据。

## A 接入时必须满足

1. 将已经提交为完整帧的真实来源图像、epoch、frame/cfg/target ID 作为一个原子包交给本顶层。`in_valid/sof/eol/eof/x/y/rgb` 同拍；检测用原始彩色流不能被显示模式改写。
2. 只允许一个尚未发布结果的 H4E 来源帧在途。开始新的**来源** SOF 前，必须已经采到前一个 `region_result_strobe`（或复位/流中止并清空）。不要把 `region_busy=0` 当作结果已经被消费。H4E 无 ready 端口，不能靠它反压上游。若超时或中止，A 必须作故障恢复，不能把旧结果重新标为新 epoch。
3. H4E 只有 frame/cfg/target ID，没有 epoch；本封装在延迟后的滤波掩膜 SOF 锁存 epoch，在 H4E 发布同 ID 结果时附上锁存的 epoch。若第 2 条被违反，两个来源恰好同 frame/cfg/target ID 而 epoch 不同，可能错误绑定；目前没有运行时协议违例检测。
4. 等结果到达后，可重放**同一完整来源帧**到显示链，使同源目标框可见。重放仍使用原 epoch/frame/cfg/target ID。下一张真实新来源帧要等上一张结果消费后再开始。A 负责缓存、读调度、DDR/HDMI 时序及来源/结果超时。
5. 跨时钟域时对整份像素元数据/结果包使用异步 FIFO 或请求应答邮箱，复位共同清空。此顶层只覆盖同一时钟域，不承担 CDC。

## 当前输出及限制

- `region_result_strobe` 是单拍事件；在该拍锁存 `region_result_epoch` 和 `region_result_packet[159:0]`。包字段顺序见 `video_b3_h4e_sameclk.v`，无效结果也应作为事件处理。
- `out_valid/sof/eol/eof/x/y/rgb` 是内部像素流，不是 HDMI HS/VS，也不提供输出 ready。A 要根据实际滤波/配对输出节奏安排显示缓存与读取；不能把 `out_valid` 反馈成 DDR 读请求。
- `error_flags`、`fifo_used`、`fifo_peak` 应纳入联合仿真和板测日志。当前独立综合 7751 Slice、10 ERAM、0 DSP，75 MHz 暂定约束 SWNS +0.371 ns；这是带测试包装的独立结果，不代表整板资源净增量或整板时序。
- 无新 bit、布局布线或上板结论。集成验收要覆盖新来源帧、同帧重放、epoch 切换、frame_id 回绕、配置切换、超时、复位/中止与输出 FIFO 异常。

独立复跑与证据见 `B3g6_README.md`、`reports/b3g6_20261019/delivery_manifest.json`。
