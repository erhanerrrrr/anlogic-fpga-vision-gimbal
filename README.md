# 安路赛题二：FPGA 双轴视觉跟踪云台

本仓库统一 A（板级集成与云台）、B（图像处理与显示）、C（颜色识别与定位）的代码和接口。当前**已上板验收的共同基线是 H4E**：MIPI/DDR/HDMI 视频链路、红色分割、3×3 去噪、最大连通区域选择、目标框/中心及安路 Logo。舵机闭环、真实采集帧身份、按键多模式、颜色标定尚未完成整机验收。

H4E 已通过用户报告的目标接替、清空恢复及约一分钟连续运行。不能据此宣称任意光照、长期无溢出、量化延迟或整项赛题全部完成。

## 所有人从这里开始

- [基线及复现命令](boards/hx1p35a/h4e/README.md)：已验收 bit、源码、测试和构建。
- [统一接口 v1](docs/interfaces/team-contract-v1.md)：明确当前实现与后续开发约定，旧模块文档作为局部接口参考。
- [赛题逐项核对与遗漏](docs/contest-review.md)：基本要求、评分重点、选做项和项目自定目标分开记录。
- [三人下一阶段任务与验收](docs/team-roadmap.md)：按小阶段交付，先仿真、再整机实现、最后上板。
- [B 同学独立任务书](docs/tasks/B-task-guide.md) / [C 同学独立任务书](docs/tasks/C-task-guide.md)：每步目标、注意事项、仿真验收和交付材料。
- [上板成果直白说明](docs/board-progress-explained.md)：我们实际做成了什么、对应哪条赛题要求、哪些还未完成。
- [协作规则](CONTRIBUTING.md)与[来源记录](docs/provenance.md)。

## 目录与维护责任

| 位置 | 内容 | 维护方式 |
|---|---|---|
| `boards/hx1p35a/h4e/` | 216 个来源文件的完整板级冻结快照、TD 工程、已验收 bit、证据、便携回归 | A 管理；不在该快照内开发新功能 |
| `rtl/recognition/`、`model/`、`scripts/`、`tests/` | C 的 S0–C10 模块及测试；新增 H4E 连通域核作为后续维护入口 | C；原 C10 是独立历史链路，不直接替换 H4E |
| `B7_GitHub/` | B 的四模式、按键、静态 OSD 与独立验证 | B；目前不是已验收的整机显示顶层 |
| `docs/interfaces/` | 团队接口、版本和兼容边界 | A/B/C 共同审查 |
| `docs/history/` | 原 C 首页、上次分工计划 | 历史快照；不作为当前项目状态 |

后续板级功能在新目录/分支集成，使用明确源文件列表。禁止递归编译全仓库，否则冻结快照和开发目录会引入同名模块。

## 共同基线快速验证

安装 Python、Icarus Verilog（`iverilog` 和 `vvp` 在 PATH）；在仓库根目录执行：

```powershell
python -m pip install -r boards/hx1p35a/h4e/requirements.txt
python -X utf8 boards/hx1p35a/h4e/run.py check
python -X utf8 boards/hx1p35a/h4e/run.py unit
python -X utf8 boards/hx1p35a/h4e/run.py pipeline
```

`check` 核对源文件、约束、工程依赖、码流和测试输入的哈希；`unit` 检查 68 个案例；`pipeline` 检查 13 帧完整 720p 数据及显示。无需开发板或 TD 即可跑仿真。B/C 每个小阶段提交一个 PR，并附可复跑的检查结果。

C 的根目录开发核回归入口及资源边界见 [H4E 新 C1](docs/stages/H4E-C1.md)，冻结版本与开发版本的证据分别保存。

[H4E 新 C2a](docs/stages/H4E-C2a.md)提供 T 主目标原子结果封装、A/B 联调序列和资源报告；已独立仿真/综合，与 C2b 来源适配配合使用，尚未进入冻结板级工程。

[H4E 新 C2b](docs/stages/H4E-C2b.md)已完成合成来源身份、重复观察抑制、旧 epoch 拦截与半帧恢复验证；新增身份保护不占 ERAM/DSP。真实来源/DDR/CDC 接入和整机上板仍待 A 集成。

本次集成以 B 分支 `5e38a969` 为父提交，其历史包含 C 基线 `acd9165b`。是否已进入默认分支，以 GitHub PR 状态为准；不要把仍在评审的分支当作已合并。

[H4E 新 C3a](docs/stages/H4E-C3a.md)完成中央 16×16 颜色统计，不改阈值；独立综合新增采样模块不占 ERAM/DSP，真实采样与整机时序待 A 集成验证。

[H4E 新 C3b](docs/stages/H4E-C3b.md)完成样本质量判断和候选阈值计算；不改变活动配置，独立综合不占 ERAM/DSP。C3c 再接新帧参数应用。

[H4E 新 C3c](docs/stages/H4E-C3c.md)完成新来源帧边界的参数整体应用、人工选色和完整 busy 仲裁；含取消后两拍收尾。独立控制模块不占 ERAM/DSP，尚待 A 整机集成上板。

[H4E 新 C4](docs/stages/H4E-C4.md)已交付 RGB888 文件校验/RTL 回放和合成场景指标；新增 FPGA 资源为 0。真实输入与人工标注待 A 提供，实拍鲁棒性尚未验收。

C 开发进度本次交付范围和 A/B 接入事项见 [2026-10-13 交付状态](docs/stages/H4E-C-delivery-status.md)；C4 实拍评估及新增功能上板尚待完成。
