# FAST 相位恢复基准研究
当前阶段：已记录完成作者公开单样品复现（2026-09-27，2500轮校准、40轮样品恢复，约19.5分钟）；尚未实现多算法比较，也没有独立相位真值。

最新结果见 `runs/pilot/author_20260927_225947/REPORT.md` 与 `metrics.json`。早期接手和审计报告保留为历史记录。当前上传准备状态及缺失文件见 `UPLOAD_STATUS.md`。

## 开始
在 MATLAB 中打开本目录，执行：
```matlab
setup_project
env = check_environment;
```
环境检查不执行 FAST，不创建 GPU 重建任务。检查结果返回 env，并在命令窗口显示。

## 目录
- legacy_fast/：作者原始代码（文件只读），提交 27961c38b6e7f9d148b38a470e3b6b90accc4468，保留许可证。
- data/raw/：作者公开 data.mat（只读）；不代表全文全部原始实验数据。
- data/derived/：后续预处理、校准缓存及其来源记录。
- src/operators/：传播、校准、支持域；src/solvers/：比较求解器；src/metrics/：评价指标。当前仅建目录。
- configs/：配置；tests/：后续数值测试。当前未实现测试。
- runs/pilot/：后续单样品运行；reports/：审计与统计。
- evaluation_only/：未来独立参考，仅评分使用；当前为空，无配对真值。
- manuscript/：图表与论文草稿。
- docs/papers/：论文 PDF、补充 DOCX。
- docs/project/：原课题任务书的未修改副本。
- tools/：MATLAB 环境检查入口。

详见 RUNBOOK.md、REPORT_reproduction.md、data_manifest.json 和 PLAN_next_step.md。
原始文件使用 Windows 只读属性和 SHA-256 清单防止误改；不是不可绕过的 ACL 安全隔离。


## 私有备份与恢复

代码、报告、结果图和工程资料保存在本仓库；全部六个 MAT 文件放在同仓库的 [snapshot-2026-09-29 Release](https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark/releases/tag/snapshot-2026-09-29)。仅 clone 不含大文件，恢复步骤见 [RESTORE.md](RESTORE.md)，哈希见 `large_files_manifest.json`。
