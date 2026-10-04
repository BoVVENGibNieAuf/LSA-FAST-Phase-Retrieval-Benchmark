# 六节研究进展报告

顺序：简报、原文章复现结果、测试数据生成和噪声模型、无噪声对比、有噪声对比、小结。

main.tex 用XeLaTeX编译两次，或运行tectonic。figures与data为本报告使用的实际结果。

最佳iteration与最低误差按每种方法、每次运行分别回顾性选点；不是已验证自动停止规则。原始完整曲线及选点定义见data，完整含噪曲线见figures/noise_full_history.pdf。

源码、原始数据、历史MAT恢复与7篇引用见报告第6节。主项目运行和绘图入口见仓库README。

无噪声补录8次、808条记录、16处旧检查点吻合；原汇总表xCase列来自MATLAB保留字转换，报告clean_curves.csv规范为case，全部值与8个逐方法文件逐项相等。曲线整合入口tools/integrate_clean_convergence.py。
