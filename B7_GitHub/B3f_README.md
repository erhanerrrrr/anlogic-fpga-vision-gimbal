# B3f：四模式、标定/跟踪状态与Logo的组合显示链

本步把已验证的B3b四模式真实C掩膜链、B3c中央ROI、B3d标定文字、B3e跟踪文字、新增的同字号模式标签和正式Logo接成一个**同像素时钟域**顶层`rtl/video_b3_status_stream.v`。保留原按键模块、RGB FIFO及各独立阶段源码。没有生成HDMI时序或DDR读请求。

## 一键复跑

```powershell
& 'C:\Users\32287\Desktop\FPGA\.venv\Scripts\python.exe' 'C:\Users\32287\Desktop\FPGA\anlogic-fpga-vision-gimbal-codex-h4e-board-baseline\B7_GitHub\run_b3f.py' --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
```

成功标志：`PASS: B3f checks completed.`。大约数分钟。可追加`--synthesis --td 'D:\TD\bin\td_commands_prompt.exe'`复跑组合链独立综合，耗时更长。精确源列表为`b3f_sources.f`，不可递归编译仓库。

## 输入与输出

图像、身份、配置、三键及输出错误/FIFO统计沿用B3b。新增两份输入整包及ROI显示控制：

- `calibration_status_packet[50:0]`由B3d `calibration_status_view`产生，内容是C控制侧最新状态及真实活动参数。**不是当前显示来源图像的cfg_id**。没有可信C状态时包的known位为0，显示UNKNOWN。A负责把C事件/参数原子送到像素域。
- `tracking_packet[37:0]`由A提供，格式`{valid,state[2:0],pan_limit,tilt_limit,pan_cmd_us[15:0],tilt_cmd_us[15:0]}`。A状态未实现时valid=0，显示UNKNOWN；不能用`target_valid`推断FOLLOW。
- `roi_req_valid/roi_req_enable`只控制标定取样框的**显示**，不代表C采样成功或配置应用。A应据已接受的C状态安排显示；B3b `calibrate_evt`只作为请求送A/C，不能直接宣传标定已生效。
- `out_mode`跟已输出像素绑定；`MODE:RAW/GRAY/EDGE/MASK`标签由这份像素模式产生，不读取按键的即时请求。`out_epoch/frame_id/cfg_id/target_id`与图像、两份`out_*_status`一起按总流水延迟对齐。

每次有效**显示SOF**锁存ROI和两份状态整包，帧中不会换文字；ROI请求与SOF同拍在下一SOF应用。四模式选择在有效**输入SOF**应用，模式信息随后一直跟像素走。像素链后新增B3d两级、B3e两级、模式标签两级、B1a Logo两级，总计新增8级；ROI为组合逻辑，不增级。异常`out_abort`共同清下游流水，外部复位清按键及全部模块。A需统一域间复位释放、CDC和显示消费时序。

显示区域：B3d y112..151，B3e y160..199，模式标签y208..223，均x16起；中央16×16 ROI在720p为x632..647、y352..367；正式Logo在右上角。使用同一16×16字体。图层顺序：四模式图像→ROI→C标定文字→A跟踪文字→随像素mode标签→官方Logo。Logo不透明像素最终优先。显示分支不修改送C的原始彩色RGB。

## 本步验证范围

ModelSim使用真实未修改H4E分类器+3×3多数滤波及原B3b三键消抖/四模式模块。四个976×480连续帧用**真实按键电平**逐帧从RAW→GRAY→EDGE→MASK；中央ROI前三帧显示，第三帧中请求关闭，第四帧才关闭。C/A状态包也在各帧中途变化，输出整帧保持SOF快照。另跑完整1280×720 RAW帧，检查正式Logo与中央ROI。图像与独立Python颜色/滤波边界/字体JSON/Logo hex参考逐像素比对；TB逐像素断言坐标、完整来源身份、mode、状态包、SOF/EOL/EOF，无合法帧abort，FIFO最终归零。实际图片/日志位于`build/b3_status_stream/run_时间/`，小型摘要位于`reports/b3f_20261016/`。

这一步输入的A跟踪状态与C标定状态是**合成整包**，C掩膜是真实RTL模块输出。验证720p活动像素及行间1拍空白，未宣称完成1650×750物理光栅/HDMI调度、DDR来源身份或跨域。动态目标框/目标信息尚未并入本组合顶层：现有B1a `video_target_osd`只启用正式Logo，因为B1a原来的`h4e-refresh-v1`结果ID规则和B3b开发链的来源ID不能静默混接。A须选择同ID匹配或带来源年龄的最新结果策略后再做该适配。

独立综合的B3f包装把所有身份/状态/诊断分组观测，资源含此测试包装。参见`reports/b3f_20261016/synthesis/summary.json`。不把独立综合等同于整板布局布线时序；没有新bit或板测。A接入时先核对原始RGB分类入口、输出有效节奏/FIFO占用、真实状态包的CDC/来源ID和显示SOF，再逐模式验证；异常请回传`out_abort/error_flags/fifo_used/fifo_peak`、坐标、mode、epoch/frame/cfg以及两份状态包。
