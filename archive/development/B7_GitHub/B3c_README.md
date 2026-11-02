# B3c：中央16×16标定ROI显示

本小步只实现取样区域的显示及帧边界开关。C的采样、计算、配置应用状态和A的跟踪状态文字仍待后续接入；整个B3未完成。

## 复跑

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3c.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B3c checks completed.`。预计约半分钟到一分钟。`build/calibration_roi/run_时间/native_720p/actual.png`为RTL生成的完整720p图，`roi_zoom.png`是中央局部最近邻放大图。不是板卡截图。

可在命令后附加 `--synthesis --td 'D:\TD\bin\td_commands_prompt.exe'` 复跑新增ROI模块的独立综合。源列表为`b3c_sources.f`，不得递归编译仓库。

## 接口与接入位置

新增`rtl/video_calibration_roi.v`，B1/B2/B3a/B3b与H4E冻结文件不改。

该模块位于**显示分支**：已选模式RGB → ROI → `video_target_osd` → 已有文字OSD。与`video_target_osd`组合已经RTL仿真；尚未接进B3b完整视频顶层。测试采用h4e-refresh-v1显示组件及合成图像，不宣称capture-v1来源绑定。

- `clk/rst_n/stream_abort`：同像素时钟域。A负责域间事件传输、复位释放与整链清空。
- `roi_req_valid/roi_req_enable`：同拍锁存一个“显示/隐藏”请求，最后一次请求优先。它是本地显示接口，**不是标定请求或标定完成信号**。A/后续状态适配层决定显示时机，不直接把忙时可能被C忽略的按键当作标定已接受。
- `in_valid/in_sof/in_x/in_y/in_rgb`：待绘制的同拍像素。SOF仅在valid时有效。无ready。
- `out_rgb/roi_hit`：组合输出，接下一级像素寄存器。坐标、valid、SOF/EOL/EOF、mode与完整身份沿原线直连，不另延时。**增加0拍像素延迟**，仍会增加组合路径，整板时序需A验证。

请求只在下一有效显示SOF应用；请求与SOF同拍时本帧使用旧请求，后一个SOF应用新请求。这里“同拍”指下游上升沿采样时刻。帧中开关不会撕裂。复位清空请求和帧状态，默认隐藏；abort清帧状态并立即停止叠加，但保留最新请求；abort期间的新请求仍会保存，恢复SOF后使用。SOF前像素不叠加。

绘制闭区间 `x=(WIDTH-16)/2 .. (WIDTH-16)/2+15`，y同理。支持16..2048尺寸；奇数尺寸向左/上取整。720p恰为x632..647、y352..367。只画内侧1像素黄色边线，共60点；取样区域本身仍是256点，不是只采边线。框内像素保持背景，不画中心十字或256×256诊断框。

图层顺序为Logo不透明像素 > 原目标十字/目标框 > 标定ROI > 背景。ROI在正式Logo之前合成，复用原Logo ROM，不复制ROM。任何OSD输出都不得回送C的原始彩色检测/取样输入。

## 验证

- 完整1280×720、160×160 Logo重叠、最小16×16、奇数17×19，共947779个图像像素逐像素与独立Python矩形绘制参考一致。
- 每组含：SOF前像素、帧中显示/隐藏请求、无valid的假SOF、请求与SOF同拍、快速请求最后值生效、abort及恢复、abort期间请求、复位、越界坐标、行间消隐。
- 完整图帧中提交隐藏请求，整帧仍显示ROI，下一SOF才隐藏。逐周期检查下游OSD的RGB、valid、SOF/EOL/EOF、坐标及32位测试身份。
- 正式Logo参考来自冻结H4E `assets/logo_reference.hex`，不是从当前RTL ROM反解析；重叠用例43个ROI边线像素被Logo正确覆盖。
- 本步完整720p是**ROI + B1a Logo显示链**，并非重跑B3b真实C滤波四模式全链；已有视频链证据仍见B3a/B3b报告。

## 资源与边界

TD6.2、PH1P35MDG324 -3、暂定75MHz的**新增ROI模块单独综合**：3寄存器、37 LUT、估计22 Slice、0 ERAM、0 DSP、0锁存器。它不保存图像，不引入FIFO或帧缓存；不复制按键消抖或Logo ROM。不能把这个单模块数字机械相加当作整板占用。

本步只确认RTL仿真和新增模块独立综合。完整工程布局布线、板级时序、bit生成和上板均未进行。A接入时需确认显示侧SOF及abort连接，先用ROI常开请求核对中心位置，再接C接受请求/忙状态的显示策略；异常时回传请求、SOF、x/y、roi_hit和stream_abort。
