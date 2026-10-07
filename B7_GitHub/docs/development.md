# 运行与维护

所有命令均从仓库根目录执行，Python 环境应安装 requirements.txt 中的依赖。工具路径是参数或环境变量；运行脚本不会下载工具。

## 统一入口

| 参数 | 内容 |
|---|---|
| 默认 | 校验源码，素材读回，独立 OSD 与联合显示小图，含故意错误检查 |
| `--720p` | 素材读回、独立五背景 720p、联合十帧 720p |
| `--synthesis` | 仿真后追加严格 75 MHz 综合 |
| `--synthesis-only` | 校验源码并综合，不需要 ModelSim |
| `--hash-only` | 仅检查源码/运行资产清单，不能算仿真或综合通过 |

`--modelsim` 指向同时含 vlib.exe、vlog.exe、vsim.exe 的目录；`--td` 指向 td_commands_prompt.exe。未传参数时可以使用 MODELSIM_BIN、TD_EXECUTABLE 或 PATH。

## 分别运行

```powershell
python .\scripts\check_osd_assets.py --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
python .\scripts\check_video_static_osd.py --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
python .\scripts\check_video_display.py --modelsim 'D:\altera14.1\modelsim_ase\win32aloem'
python .\synthesis\check_video_display_synthesis.py --td 'D:\TD\bin\td_commands_prompt.exe' --require-timing
```

两个视频脚本支持 `--720p`。这些分项入口不强制校验历史源码哈希，适合修改代码后的开发；统一入口默认校验交付基线，以防误把改过的文件当作已验证版本。

每次运行在 `build/<测试类型>/run_<时间>/` 新建目录，保留源码快照、日志、实际像素 CSV、图片与结果 JSON。成功判据是本次进程退出 0 且末尾出现通过标记。故意错误用例的日志含 FAIL，只有脚本确认恰好检出预设错误后，整个检查器自检才算通过。

`test_data/` 保存最近的预览；720p 原始像素数据较大，不入 Git。需要调试时在本机保留。`.gitignore` 会忽略运行产物和缓存，但不会忽略 `reports/` 内精选证据。

## 修改源码后

先运行受影响的分项入口，通过后补做相应小图/720p/综合回归。更新 `reports/source_manifest.json` 中改动文件的 SHA256，记录新的验证证据，再提交 Git。不要仅更新哈希就宣称测试通过。清单只用于版本核对，不是数字签名，也不代替测试。

参考模型在 `model/`，运行时会复制到测试快照，与实际 RTL 输出逐像素对照。输入由固定公式生成；不得使用 DUT 的实际输出生成预期结果。
