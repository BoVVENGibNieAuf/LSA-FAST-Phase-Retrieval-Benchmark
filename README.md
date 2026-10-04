## 当前完整阶段报告（六节版，2026-10-04）

已补齐无噪声完整iteration曲线与各方法最佳iteration/最低值：8次补录、808条记录、16处原检查点吻合。无噪声最佳iteration为28–100，均不在首步。最新版PDF共10页。

[阅读PDF](reports/research_summary_20261004/MCF_Research_Progress.pdf) · [可编辑LaTeX工程](reports/research_summary_20261004/MCF_Research_LaTeX.zip) · [报告源文件和绘图数据](reports/research_summary_20261004/)

按“简报 → 原文章复现 → 数据生成与噪声 → 无噪声比较 → 有噪声比较 → 小结”组织。含噪主结果为早期恢复效果与真实曲线；回顾性最低误差明确使用评价真值选点，不能当作已验证早停规则。此前以最终预算为主的报告保留为历史版本。

- 重建源码：`src/`；运行入口：`START_POISSON_STAGE.cmd`。
- 本轮原始数据：`runs/pilot/poisson_stage_20261004/`；无噪声/真值恢复见 `CIRCULAR_RESTORE_zh.md`。
- 绘图与报告脚本：`tools/build_research_summary.py`；报告模板：`tools/research_summary_template.tex`。
- 报告第6节含资料索引与7篇参考文献。

## 历史噪声阶段报告（2026-10-04）

48/48 MATLAB solves completed (34.99 s), 4,848 curve rows and 96 independently verified final metrics. ER has the lowest final field error in all four noisy conditions. All 48 runs have higher field error at 200 than at 80 propagation calls. Three seeds per condition; fixed parameters and ideal known calibration.

- [New stage PDF](reports/poisson_stage_20261004/MCF_Poisson_stage_report.pdf)
- [Editable LaTeX](reports/poisson_stage_20261004/MCF_Poisson_LaTeX.zip)
- [Two figures and full table](reports/poisson_stage_20261004/REPORT.md)
- [Protocol and literature](reports/POISSON_STAGE_PROTOCOL_20261004.md)
- [Completed MATLAB results](runs/pilot/poisson_stage_20261004/status.json)

This is a pure Poisson detector-count experiment, p=1/10 mean detected counts per blank-reference pixel/frame. Historical shot+read results remain engineering tests. The older 16-page report is retained as historical; this report is the current noise-stage update.

# FAST 相位恢复基准研究

**源码状态：公开（Public）。2026-10-04 已核验仓库及已发布 Release 可公开访问，无需仓库邀请或额外访问授权。** 仓库可见性不改变现有许可证、实验验证状态或复跑结论。

## 当前入口：圆形端面两类 MCF

[导师快速复跑说明](QUICKSTART_zh.md) · [方法卡](docs/methods/METHOD_CARDS_zh.md) · [方法卡 Word](docs/methods/FAST_四类求解器方法卡.docx) · [交付清单](docs/methods/DELIVERY_CHECKLIST_zh.md)

Windows：下载解压后双击 **START_CIRCULAR_BENCHMARK.cmd**。MATLAB 直接运行 `setup_project; run_fast_circular_benchmark`。模拟输入现场生成，无需恢复旧 MAT 文件。

**验证状态：2026-10-03：圆形数值运行已完成，16/16个四方法任务、零失败，几何与求解器测试通过。正式结果见 reports/FAST_圆形MCF_结果汇报_20261003.docx。全新下载副本数值复跑仍未验证。**

两类为周期性和非周期性 MCF，圆形端面、芯位置和算法支持域分开建模；FAST/HIO、ER、RAAR、L-BFGS 共用预算，另列零迭代对照。本轮是已知合成校准的工程试运行，尚无独立实测参考。

## 目录

- `src/`、`configs/`：模拟、求解、评分和配置。
- `tests/`：算子、梯度、求解器及旧基线数值检查。
- `tools/`：MATLAB 运行入口及数据恢复工具。
- `runs/pilot/`：运行记录、指标与图；历史数据保留，不覆盖。
- `evaluation_only/`：仿真评分真值，不加入公共 MATLAB 路径；未实施操作系统级权限隔离。
- `docs/project/`：原始导师任务书；`docs/methods/`：四方法卡和交付核对。
- `legacy_fast/`、`data/raw/`：冻结作者代码与公开输入，保留原许可证。

作者原始 FAST 复现与新模拟比较是两条独立入口。原始复现见 RUNBOOK.md；新模拟请使用上面的快速开始。

## 公开源码与结果恢复

代码、报告、结果图和工程资料保存在本公开仓库。当前圆形 MCF 的完整结果可从 [circular-results-2026-10-03 Release](https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark/releases/tag/circular-results-2026-10-03) 公开下载，恢复步骤见 [CIRCULAR_RESTORE_zh.md](CIRCULAR_RESTORE_zh.md)。

历史作者复现所用的六个 MAT 文件位于 `snapshot-2026-09-29` Release；截至 2026-10-04，该 Release 仍为 **草稿（Draft）**，未公开发布，普通访客不能下载。仓库转为公开不会自动发布草稿。仅 clone 不含这些大文件，历史恢复说明见 [RESTORE.md](RESTORE.md)，哈希见 `large_files_manifest.json`。

## 最新阅读版与 LaTeX 源码（2026-10-04）

[12页 LaTeX 排版 PDF](reports/FAST_圆形MCF_LaTeX排版版_20261004.pdf) · [完整 LaTeX 工程 ZIP](reports/FAST_LaTeX工程_20261004.zip) · [LaTeX 源文件](reports/latex_delivery_20261004/main.tex)。工程含高清结果图、数据摘要与编译说明，已验证独立编译。

早期 PDF/Word 和历史归档保留原交付版本；其中关于仓库访问权限的旧文字，以本页当前公开状态为准。

## 历史阅读版（2026-10-03）

[6页 PDF](reports/FAST_圆形MCF_佳伟老师交付版_20261003.pdf) · [可批注 Word](reports/FAST_圆形MCF_佳伟老师交付版_20261003.docx) · [完整方法卡](docs/methods/FAST_四类求解器方法卡.docx)。新版精简阅读路径，原结果汇报和原始数据保留。
