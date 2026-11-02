# B0～B4 一次性提交说明

本次按用户要求把 B0～B4 放在**同一个 PR**。交付增量以本地 2026-10-06 的 `delivery/B7_GitHub` 旧包为对照：已在组库里的原 B7 静态显示、四模式及 H4E 冻结基线不重复提交；若目标分支缺少依赖，应在合并前补齐。PR 的实际起点 commit SHA 要以 GitHub 目标分支为准，不能用本地 ZIP 的时间代替。

| 阶段 | 交付内容 | 复跑入口和证据 |
|---|---|---|
| B0 | H4E 与旧 B7 复现、接口差异、工具版本和未板测边界 | `docs/B0_B1a_update.md`、`scripts/check_h4e_baseline.py`、`reports/baseline/index.json` |
| B1 | 结果整包快照、同帧目标框/十字、动态目标文字与无效原因 | `run_b1a.py`、`run_b1b.py`、各阶段 README 与 `reports/b1a_*`、`reports/b1b_*` 摘要 |
| B2 | 真实 C 滤波 mask 与 RGB 按坐标/身份配对，RAW/GRAY/EDGE/MASK 联合路径，FIFO/故障检查 | `run_b2a.py`～`run_b2d.py`、各自源列表/README、`reports/b2*` 摘要 |
| B3 | 按键消抖、SOF 模式切换、标定/跟踪状态、真实 H4E 结果与四字段同源框 | `run_b3a.py`～`run_b3g6.py`、`docs/B3g6_to_A_handoff.md`、`reports/b3*` 摘要 |
| B4 | 延迟窗口及文字、性能帧率/异常显示、1280×720 H4E 联合回归 | `run_b4a.py`～`run_b4g.py`、`b4g_sources.f`、`docs/B4g_to_A_handoff.md`、`reports/b4*` 摘要 |

新增/修改的功能文件保留在 `rtl/`、`sim/`、`model/`、`scripts/`、`synthesis/`、`assets/` 和根目录运行/源列表文件的**原相对路径**。`*_sources.f` 与各 `run_b*.py` 给出完整可复跑来源；不要递归编译整个仓库。同一 PR 的描述应写明目标分支和真实起点 commit、接口 profile、工具版本、一键命令及 PASS、像素差异、资源与 FIFO 峰值、已知限制、A 上板预期与故障回传字段。每阶段详细用例和数值见对应 README 与 `reports/` 的 JSON 摘要。

最后的 B4g 证据：用户已复跑确认两帧 1280×720、合计 1,843,200 像素与独立参考零差异；ModelSim 编译/仿真零错误零警告，FIFO 峰值 1284。TD 6.2 独立综合含测试包装共 9,339 Slice、10 ERAM、0 DSP，暂定 75 MHz SWNS +1.071 ns。B4g 相对 B3g6 视频像素与随像素状态增加四拍；区域结果事件、错误和 FIFO 诊断保持独立节奏。

验证仍使用合成来源身份、延迟和帧率。真实来源帧 ID/epoch、三路帧率、异常计数与跨时钟域整包由 A 接入；`capture-v1`、整板布局布线时序、bit 与上板效果**未验证**。H4E 单在途来源和同帧重放条件见 `docs/B3g6_to_A_handoff.md`，性能包位定义、单位及板测回传清单见 `docs/B4g_to_A_handoff.md`。不把 `N=010000` 或 HDMI 刷新次数当真实来源帧率。

报告只保留各阶段的 README/JSON 摘要、少量 RTL 实际图/独立参考/差分图和时序示意。大型 `build/`、`test_data/`、逐像素 CSV、ModelSim 波形、综合数据库、工具目录和未经整板验证的 bit 不入 Git。仿真及综合原始产物可由脚本重建。
