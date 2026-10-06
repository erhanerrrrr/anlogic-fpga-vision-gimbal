# FPGA 云台：C 颜色识别与定位

当前完成 S0 软件测试基础及 C1–C10 的C端独立链路：颜色分类、整帧掩膜、面积/框统计、中心结果包、3×3去噪、有效性拒判、来源帧去重、标定采样和阈值按帧生效。最终12帧720p测试及TD综合通过；B显示联调和真实上板验收待完成。人工指定红/绿/蓝之一；多张同色卡的可靠区分仍留作后续增强。

队友接入请先阅读 [A/B交接说明](docs/handoff/C端交接.md)。最终顶层是 `rtl/recognition/rgb_calibrated_result.v`，源文件列表是 `rtl/recognition/c10_sources.f`。首次复现可运行 `python scripts/run_c10.py`；完整阶段回归使用 `python scripts/run_c_acceptance.py --td`。

可直接浏览 [C10验收记录](reports/c10/acceptance.md)及 [2026-10-06固定验收证据](reports/c10/evidence/2026-10-06/README.md)。`generated/`下的大型数据由脚本重建，不纳入Git。

运行：

```powershell
python scripts/run_s0.py
python scripts/run_c1.py
python scripts/run_c2.py
python scripts/run_c2_td.py
python scripts/run_c3.py
python scripts/run_c4.py
python scripts/run_c4_td.py
python scripts/run_c5.py
python scripts/run_c5_td.py
python scripts/run_c6.py
python scripts/run_c6_td.py
python scripts/run_c7.py
python scripts/run_c7_td.py
python scripts/run_c8.py
python scripts/run_c8_td.py
python scripts/run_c9.py
python scripts/run_c9_td.py
python scripts/run_c10.py
python scripts/run_c10_td.py
```

需要 Python 3.7 或更高版本，无第三方 Python 依赖；C1 另需 ModelSim 的 vlib/vlog/vsim 在 PATH。生成物分别在 `reports/s0/generated/` 和 `reports/c1/generated/`，可重建，不提交大型生成物。

阶段说明及待确认接口见 [S0](docs/stages/S0.md)。正常测试应退出 0；故意错误自检 `python scripts/run_s0.py --inject-error marker` 应退出 1。

S0 软件测试通过不等于 RTL 仿真通过；本地阶段测试不等于 A/B 已确认公共接口或上板通过。

C1 的接口、延迟、参数与实际 RTL 仿真结果见 [C1 说明](docs/stages/C1.md)。C1 仿真通过不等于 TD 综合或上板通过。

C2 的完整流接口、RTL 掩膜图和 TD 检查说明见 [C2 说明](docs/stages/C2.md)，生成物在 `reports/c2/generated/`。TD 早期综合不等于板级时序、布局布线或上板通过。

C3 的原始面积/框、末像素锁存时序和接口说明见 [C3 说明](docs/stages/C3.md)，生成物在 `reports/c3/generated/`。本阶段还没有中心坐标或目标可信度判断。

C4 新增中心坐标和完整结果包，详见 [C4 说明](docs/stages/C4.md)，生成物在 `reports/c4/generated/`。该阶段隔离模块的有效性仅为 count>0。

C5 新增3×3多数滤波和完整边界输出，详见 [C5 说明](docs/stages/C5.md)。生成物在 `reports/c5/generated/`；滤波后的面积使用新的独立期望，该阶段隔离模块不含 C6 干扰拒判。

C6 新增面积/尺寸/填充率门槛、拒判原因与原始调试字段，详见 [C6 说明](docs/stages/C6.md)，生成物在 `reports/c6/generated/`。近距离同色块仍可能被接受，不能当作通用多目标选择。

C7 验证移动、消失/重现、停帧和复位，抑制连续重复来源帧号的新通知，详见 [C7 说明](docs/stages/C7.md)。生成物在 `reports/c7/generated/`；A需根据新通知判断结果是否新鲜，不能只看保持的有效位。

C8 新增16×16区域的RGB采样与统计，收到请求后在下一新来源帧采集；忙碌请求记录后忽略，不修改识别阈值。详见 [C8 说明](docs/stages/C8.md)，生成物在 `reports/c8/generated/`。样本是否适合标定及参数应用留到C9。

C9 新增标定有效性、阈值生成、pending/活动参数及新来源帧边界应用；失败保留旧值，人工选色恢复对应默认规则。详见 [C9 说明](docs/stages/C9.md)，生成物在 `reports/c9/generated/`。新顶层自行管理颜色和cfg_id，A/B接入前需按新接口对齐。

C10 用连续12帧720p及中断恢复序列验收最终C端链路，提供实际掩膜图、独立期望、结果与延迟CSV、全阶段回归入口、实物RGB软件分析工具和便携交付包。见 [C10说明](docs/stages/C10.md)及 [A/B交接说明](docs/handoff/C端交接.md)。B显示联调、实物回放及H3/H4上板验收仍待完成。

全部阶段重跑：`python scripts/run_c_acceptance.py --td`。数据分析工具自检：`python scripts/test_c_capture_analysis.py`。最终验收通过后打包：`python scripts/package_c_delivery.py`。
