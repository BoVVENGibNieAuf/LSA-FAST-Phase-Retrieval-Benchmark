# 多芯光纤相位恢复：阶段研究进展

## 这段时间完成的工作

1. 跑通 FAST 作者公开示例的参考校准与样品重建。
2. 建立已知真值的圆形 MCF 仿真，比较周期与非周期纤芯布局。
3. 实现 HIO、ER、RAAR、L-BFGS，在统一输入、初值和计算预算下比较。
4. 查阅成像噪声文献，完成 Poisson 多种子对照与迭代稳定性分析。

## 资料入口

[公开仓库](https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark) 首页有最新下载入口。

- [报告PDF](MCF_Poisson_stage_report.pdf)；[LaTeX工程ZIP](MCF_Poisson_LaTeX.zip)，主文件为 `main.tex`。
- 重建源码：`src/`；运行脚本：`tools/`；本轮入口：`START_POISSON_STAGE.cmd`。
- 原始结果：`runs/pilot/poisson_stage_20261004/`，含输入、最终复场、曲线CSV与参数。
- 既往圆形MCF报告：`reports/latex_delivery_20261004/`；方法说明：`docs/methods/`。

---

