# OSD 样例资产来源

这些文件取自本机开发板资料中的 `HX1P35A_Contest_202606/7_lab_ex_2026_nosoft/lab_ex3_osd_SC500_720P.zip`，不是新绘制的 Logo 或字体。ZIP 内部完整路径和原始字节 SHA256 见 provenance.json；保留原文件字节，不修改内容或换行。

- anlogic_logo_rom.v：样例 Logo 的组合查表模块。
- osd_char_lib.v：样例 16×16 字模组合查表模块。
- hdmi_mixer.v：仅保留用于追溯尺寸、地址顺序和像素解释的原样例代码，不接入当前视频链、不参与本步编译。
- reference.json：从原文件中的常量表解析并冻结的素材规格；不是从仿真输出反推。Logo 使用稀疏地址表，字模记录 39 个字符的 16 行。

Logo 160×160，地址 y×160+x；O_pixel[24] 为不透明标志，[23:0] 为 RGB888。字模 O_row_bits[15] 对应最左列。以上解释已与原 hdmi_mixer 对照。

本目录保留来源信息，不据此扩大原资料的使用授权。无外部 .mem/.mif 初始化文件依赖。本步没有证明稀疏 case 表将映射为高效块 RAM；实际显示模块的存储实现与综合检查在后续完成。
