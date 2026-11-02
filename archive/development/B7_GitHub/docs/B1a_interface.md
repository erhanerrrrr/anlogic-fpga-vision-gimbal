# B1a：H4E 整包快照、动态目标框和中心

适用 `team-contract-v1` 的 **h4e-refresh-v1**。任务书声明板测起点为 `7eb4a90`；本次下载的 GitHub ZIP 注释实际标记为 `009f09b7276afbe962dff4bbcc5fa0324d432d79`（包含后续文档）。ZIP 无 `.git`，没有本地提交历史；本地另用来源清单与 ZIP 逐文件比较核对内容，见复现记录。开发入口是 `rtl/video_target_osd.v`，明确源列表见 `b1a_sources.f`。未修改 `boards/hx1p35a/h4e/` 的冻结文件。

## 与旧版的区别

旧 C10 的全局框、debug_count、填充率原因码不能当作 H4E 最大区域结果。这里接 `h4e_region_select` 的 T 结果：area 为被选中区域面积，reason 使用 H4E 的 0/1/2/3/5；不重新实现选区或 75% 填充率门槛。

之前根目录 `osd_frame_snapshot.v` 是通用邮箱，仍保留为独立检查点。本模块添加 H4E 的编号/配置门控、中断清空和明确字段；并非把 C10 的 204 位包改名。B7 灰度/Sobel/按键/静态 OSD 均不改动。

## 输入、身份与原子性

全部端口同一个像素时钟域，低有效异步复位。跨域整包传输及复位同步释放由 A 提供。

`result_strobe` 同拍锁存完整结果，保持电平不重复消费。完整 160 位内部包，从 MSB 到 LSB 为：

```text
frame_id32,cfg_id16,target_id2,target_valid1,area20,
xmin11,ymin11,xmax11,ymax11,cx11,cy11,reason3,labels_used8,components12
```

外部使用命名端口，不要求 C 提供该打包总线。`labels_used` 是工作槽峰值，`components` 是区域数，不是旧 C10 debug 几何。target_id 是颜色，不是跨帧目标身份。

每个 `in_valid && in_sof`，选择此前最近一次结果事件；SOF 同拍结果只供后一个 SOF 使用。首像素与其余像素使用同一份快照。帧中结果、completed_ready、期望编号/配置变化不会改变本帧框。

适配输入如下（由 A 提供，必须与进入本模块的显示 SOF 同域）：

| 输入 | 含义及 H4E 对应 |
|---|---|
| completed_refresh_id | 完成的 F 结果刷新号，当前板级 `result_refresh_id`；不是正在绘制的刷新号 |
| completed_ready | 当前 `!region_busy`，只在显示 SOF 用于选择；内部另检查确实收到过 T 事件 |
| expected_cfg_id / expected_target_id | 本次期望配置和颜色；H4E 为 1 / 0 |
| in_refresh_id | 当前正在绘制的显示刷新 ID，原样跟随输出；与所画结果 ID 可不同 |
| stream_abort | A/上游检测到坏帧或中断时发出；优先于 SOF/结果，清空邮箱和在途输出 |

仅当已收到结果、completed_ready=1、T 的 frame/cfg/color 均匹配上述期望且颜色不为3时，`out_snapshot_ready=1`。不匹配时目标无效、公开面积/几何为0、reason=4，保留收到的 result 身份便于后续诊断。无目标的合规结果可以 ready=1、target_valid=0，两者含义不同。

有效目标还要求 area>0、reason=0、四边有序且完全在图内、中心在图内。错误几何不画假框，reason=4；这是显示层拒绝该绘制请求，非修改 C 原因码。无效输入即便几何非零，输出公开几何也清零。

复位/stream_abort 后，未到有效 SOF 不输出像素；重新收到完整结果并遇匹配 SOF 可恢复。无 abort 的新 SOF 开启一个新显示帧。**本模块不检测缺失行、重复坐标、缺 EOF 或源超时**，不能把它当作坏帧监测器；这部分在 A/B2 联合调度中验证。没有新的匹配身份要求时，同一刷新结果可保留显示，不能用于证明控制观察新鲜。

这里没有 capture_epoch，也没有真实采集帧绑定，因此没有实现 capture-v1。A 发布 capture-v1 后，必须单独添加 epoch 和选定的同源/最新结果策略及测试，禁止只重命名本接口。

## 图层与时序

保留 H4E 形状：向框内绘制 **2 像素绿边**；中心青色十字为水平17×3与竖直3×17。闭区间坐标。中心距离用扩展位宽、取非负距离计算，跨到画面外的十字仅保留图内部分，不向对侧回绕。越界包围框按 H4E 既有行为整包拒绘，不把越界几何自动改成合法目标。

Logo 复用原 B7/H4E 相同 ROM，在 (1104,16) 显示160×160；不透明像素优先于十字、框和背景。透明像素保留下层。背景 `in_rgb` 透传，颜色分类/Gamma/黄色诊断框/文字不在该模块中重做。

两级寄存器：在边沿 N 接收输入，第一级登记；边沿 N+1 后输出对应像素（从边沿前输入到输出穿过两级寄存器）。valid、坐标、SOF/EOL/EOF、显示刷新号、结果整包一起延迟。无 FIFO、无整帧缓存、无 backpressure；支持消隐，图外坐标不产生有效输出。不能直接代替 HDMI HS/VS 或控制 DDR 读请求。

这次是独立提取验证，未修改板级 mixer。A 后续在新集成目录中安排图层与同步延迟：移除旧目标框/十字/Logo 的重复绘制，把对应背景送入新模块；诊断文字由 B1b 保留/提取，并保证 Logo 最终优先。不要将本模块直接串在含旧绿框的完整 HDMI 图像后面，旧框无法被新模块清除。原 `O_video_rd_en=I_video_de` 保持原职责。

## 复跑与交付边界

在 B7_GitHub 目录运行（替换工具路径）：

```powershell
python -m pip install -r requirements-b1a.txt
python run_b1a.py --modelsim D:/altera14.1/modelsim_ase/win32aloem
python run_b1a.py --modelsim D:/altera14.1/modelsim_ase/win32aloem --baseline --synthesis --td D:/TD/bin/td_commands_prompt.exe
```

`--baseline` 使用原封不动的 H4E RTL、TB 与 SciPy 参考，在 build 副本用 ModelSim 复跑；它不是 Icarus 原命令的运行记录。原 B7 回归仍使用原 `run.py`。各次运行在唯一 build 子目录，旧报告不覆盖。

新测试包含固定种子的事件/复位/中断/配置/颜色/ID回绕/越界向量、9帧1280×720有效区和1650×750总光栅。TB逐拍检查输出延迟/标记、整包与帧内稳定；Python从实际 RTL 二进制像素生成 actual/reference/diff PNG并独立比较。故意翻转一个参考像素的负例必须失败，证明检查器能抓错。

新模块不驱动云台，不显示“正在跟踪”，没有标定/坐标文字；这些属于 B1b/B3。资源报告为含测试装载寄存器与观察端口的独立综合，不等于整板增量，也不能与 H4E 的45 ERAM直接相加。

交给 A 后先只集成此增量：正常目标框、无效清框、Logo重叠、结果不匹配等待、复位恢复逐项上板。失败时返回集成 SHA、bit哈希、时钟、显示刷新号、completed ID/ready、T 整包、SOF、abort和出现异常的位置；尚未上板的项目必须写“待 A 验证”。
