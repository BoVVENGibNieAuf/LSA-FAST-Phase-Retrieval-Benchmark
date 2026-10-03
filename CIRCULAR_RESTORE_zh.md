# 圆形MCF结果恢复

本档案对应 circular_20261003_224006_279 / four_20261003_224047_034，共184个文件，包括原始MAT输入、评分真值、全部检查点、指标和图像。

下载私有Release：https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark/releases/tag/circular-results-2026-10-03

附件：circular-results-20261003.zip；SHA-256：`99637764c0fdc7c986fd15f10317c84da486a3f6fc91ccb862e21b2bdf3ad7c9`。

在项目根目录执行：

```sh
python tools/restore_circular_results.py /path/to/circular-results-20261003.zip
```

脚本先校验完整档案与每个文件，拒绝不安全路径，保留已有相同文件，拒绝覆盖不同文件。本地空目录恢复已逐文件验证。下载加展开预留300MB磁盘。

档案保留原始项目路径及代码/输入哈希作为证据。跨机器新数值复跑使用 START_CIRCULAR_BENCHMARK.cmd；旧配置中的绝对路径不自动重写。用户Windows原目录运行已成功，全新下载副本数值复跑未验证。
