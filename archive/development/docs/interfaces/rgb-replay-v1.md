# H4E 检测入口 RGB 回放格式 v1

本接口用于 C4 离线回放，不是板级数据总线。先使用合成数据验收；真实数据必须由 A 从固定白平衡后的 RGB888、gamma/灰度/OSD 之前导出。

## 文件

每份数据集一个 UTF-8 `manifest.json`；所有 RGB/标注文件使用相对于该 manifest 所在目录的路径。工具拒绝目录外路径、错误长度/哈希和错误配置。名字可以是中文，进入仿真前会复制到 ASCII 临时目录。

RGB 文件按从上到下、从左到右的顺序，每像素依次写 R、G、B 三个无符号字节，不带文件头、不带行填充。720p 精确为 1280×720×3 = **2,764,800 字节**。JPEG、PNG、RGB565、BGR、BMP 行填充均不能直接改扩展名冒充；校验无法从任意合法字节自动辨认错误的 RGB/BGR 顺序，A 必须确认导出入口及通道。

可选像素标注文件每像素 1 字节，取值只能是 0/1，720p 为 921,600 字节。1 表示人工标注的指定颜色目标像素，可包含多个同色目标；主目标框单独给出。没有标注时使用 `annotation: null`，只能比较软件/RTL，不计算识别效果。当前合成集 mask 是生成时的几何形状，包括已知反光/遮挡位置，属于合成形状标注，不是实拍人工标注。

## Manifest 字段

|字段|要求|
|---|---|
|schema|固定 `h4e-rgb-replay-v1`|
|source_kind|`synthetic` 或 `camera`，禁止把生成图写成 camera|
|width / height|camera 必须 1280/720；合成小图宽高至少 18，最大 1280/720|
|entry|固定 `fixed_wb_rgb888_before_gamma_gray_osd`|
|identity_profile|固定 `capture-v1`，不接受 HDMI 刷新 ID|
|bit_sha256|camera 必填真实 bit 文件的 64 位小写十六进制 SHA256；synthetic 可 null|
|exposure / lighting|非空说明；确实未知时明确写 unknown，不能推测填写|
|frames|非空、有序的帧元数据列表，整组共享宽高|

每个 frames 元素：

|字段|要求|
|---|---|
|name|可选场景名|
|rgb_file / rgb_sha256|RGB 文件相对路径及完整 SHA256|
|frame_id / epoch|32 位无符号真实来源身份；同一帧重复播放保持相同身份|
|cfg_id|16 位实际活动配置编号|
|target_id|0 红、1 绿、2 蓝|
|thresholds|三个整数 `[min_main, diff_1, diff_2]`，每项 0..255|
|hblank_cycles|每行有效像素之间插入的空闲时钟，0..65535；必须说明是实测还是回放试验设置|
|annotation|对象或 null|

`hblank_cycles` 决定回放中的行处理时间预算。工具在帧末等待结果并额外留出空闲周期，并未保持原相机帧率；即使行间隔取自实测，也不能称为整机时序验收。若入口在行内有 valid 间断，应先找 A 修正导出/接口，当前回放模型按 H4E 要求连续输入一行。

相邻重复 `(epoch,frame_id)` 必须使用相同 RGB 哈希、cfg 和阈值。参数改变必须使用新 cfg_id；连续相同 cfg 的阈值不允许偷偷变化。每次独立运行从 reset 开始，首帧算新观察；去重只针对相邻同身份，不是全数据集全局查重。

annotation 包含：

- `origin`：真实数据为 `human`，合成数据为 `synthetic_geometry`。
- `target_present`：JSON 布尔值，画面是否存在指定颜色目标。
- `primary_bbox`：有目标时为 `[xmin,ymin,xmax,ymax]`，首尾坐标均包含；无目标为 null。多个目标需人工指定本次评估的主目标，不能用 RTL 预测框充当真值。
- `mask_file`、`mask_sha256`：可选像素标注路径与哈希。有框无 mask 时，只计算帧级/定位指标。

只允许合成压力案例使用 `expected_structural_reason: 3` 或 `5`。这表示明确预期触发容量/行处理期限拒绝，不是伪造正常检测结果。真实数据不能指定这个字段来掩盖故障。

## A 导出顺序

1. 确认 bit/commit、RGB 入口位置、曝光/光照，并记录实际 active cfg/颜色/阈值；不要用尚未应用的候选参数。
2. 保存完整 RGB888 帧，核对 2,764,800 字节，分别计算 RGB 和 bit 文件 SHA256。
3. 记录真实来源 frame_id/epoch；重复缓冲区读出保持同 ID，不能用显示刷新计数代替。
4. 标注有无目标、主目标框；需要像素指标时再添加 0/1 mask。不清楚的样本先不标注，不能自动拿参考算法输出作人工答案。
5. 保存 manifest，先运行 `replay_h4e_rgb.py <manifest路径> --validate-only`。完整生成示例可执行 `scripts/generate_h4e_c4.py`，生成目录中的 manifest 是可运行样例，真实数据需更换 source_kind、尺寸、来源信息及标注。

本机 SHA256 可用 PowerShell `Get-FileHash -Algorithm SHA256 -LiteralPath '文件绝对路径'`。工具默认每条命令最多 300 秒，可用 `--timeout-seconds` 明确调整；超时或检查失败均非 PASS。C4 尚未运行真实 720p RTL 回放，第一次真实回放需记录仿真用时和失败证据。
