# FAST 相位恢复基准研究

## 当前入口：圆形端面两类 MCF

[导师快速复跑说明](QUICKSTART_zh.md) · [方法卡](docs/methods/METHOD_CARDS_zh.md) · [方法卡 Word](docs/methods/FAST_四类求解器方法卡.docx) · [交付清单](docs/methods/DELIVERY_CHECKLIST_zh.md)

Windows：下载解压后双击 **START_CIRCULAR_BENCHMARK.cmd**。MATLAB 直接运行 `setup_project; run_fast_circular_benchmark`。模拟输入现场生成，无需恢复旧 MAT 文件。

**验证状态（2026-10-03）：代码准备完成，MATLAB 节点启动受阻；新几何结果和全新下载复跑未验证。** 旧六角外轮廓结果保留为历史架构验证。完整结果版 Word 等待新运行；方法卡已提供。

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

## 私有备份与恢复

代码、报告、结果图和工程资料保存在本仓库；全部六个 MAT 文件放在同仓库的 [snapshot-2026-09-29 Release](https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark/releases/tag/snapshot-2026-09-29)。仅 clone 不含大文件，恢复步骤见 [RESTORE.md](RESTORE.md)，哈希见 `large_files_manifest.json`。
