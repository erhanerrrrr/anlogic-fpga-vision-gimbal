# 安路赛题二：FPGA 双轴视觉跟踪云台

本仓库统一 A（板级集成与云台）、B（图像处理与显示）、C（颜色识别与定位）的代码和接口。当前**已上板验收的共同基线是 H4E**：MIPI/DDR/HDMI 视频链路、红色分割、3×3 去噪、最大连通区域选择、目标框/中心及安路 Logo。舵机闭环、真实采集帧身份、按键多模式、颜色标定尚未完成整机验收。

H4E 已通过用户报告的目标接替、清空恢复及约一分钟连续运行。不能据此宣称任意光照、长期无溢出、量化延迟或整项赛题全部完成。

## 所有人从这里开始

- [基线及复现命令](boards/hx1p35a/h4e/README.md)：已验收 bit、源码、测试和构建。
- [统一接口 v1](docs/interfaces/team-contract-v1.md)：明确当前实现与后续开发约定，旧模块文档作为局部接口参考。
- [赛题逐项核对与遗漏](docs/contest-review.md)：基本要求、评分重点、选做项和项目自定目标分开记录。
- [三人下一阶段任务与验收](docs/team-roadmap.md)：按小阶段交付，先仿真、再整机实现、最后上板。
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

本次集成以 B 分支 `5e38a969` 为父提交，其历史包含 C 基线 `acd9165b`。是否已进入默认分支，以 GitHub PR 状态为准；不要把仍在评审的分支当作已合并。
