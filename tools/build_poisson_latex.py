from pathlib import Path
import csv,shutil,json
R=Path(__file__).resolve().parents[1];D=R/'reports/poisson_stage_20261004';L=D/'latex';L.mkdir(exist_ok=True)
for n in ['figures','data']:shutil.copytree(D/n,L/n,dirs_exist_ok=True)
s=list(csv.DictReader((D/'data/summary.csv').open()))
rows=[]
for r in s:
 layout='周期' if r['layout']=='periodic' else '非周期';m=r['method'].replace('LBFGS','L-BFGS')
 vals=[f"${float(r[k+'_mean']):.4f}\\pm{float(r[k+'_sd']):.4f}$" for k in ['field_nrmse','phase_rmse_rad']]
 rows.append(f"{layout} & {r['p_blank']} & {m} & {' & '.join(vals)}\\\\")
tex=r'''\documentclass[UTF8,a4paper,11pt,fontset=fandol]{ctexart}
\usepackage[margin=18mm]{geometry}
\usepackage{amsmath,amssymb,graphicx,booktabs,hyperref,pdflscape,fancyhdr}
\hypersetup{colorlinks=true,urlcolor=blue}
\pagestyle{fancy}\fancyhf{}\fancyhead[L]{MCF相位恢复：阶段研究进展}\fancyhead[R]{2026-10-04}\fancyfoot[C]{\thepage}
\setlength{\headheight}{15pt}\setlength{\parindent}{0pt}\setlength{\parskip}{5pt}
\begin{document}
\begin{center}{\LARGE\bfseries 多芯光纤相位恢复：阶段研究进展}\par\vspace{5pt}阶段汇报\quad |\quad 呈佳伟老师\end{center}
佳伟老师：这段时间围绕“多芯光纤相位恢复中，不同重建方法的精度与噪声稳定性”开展工作，已从作者公开示例复现推进到统一条件下的仿真对照。
\section*{这段时间完成的工作}
\begin{enumerate}
\item \textbf{跑通作者公开示例。} 完成 FAST 参考校准与样品重建，建立后续比较的基础流程。
\item \textbf{建立已知真值的 MCF 仿真。} 构建圆形端面，比较周期与非周期纤芯布局，使恢复误差能够直接量化。
\item \textbf{完成四种方法的统一比较。} 实现 HIO、ER、RAAR 与 L-BFGS，在共同输入、初值和计算预算下进行无噪声及含噪声对照。
\item \textbf{补充文献依据与迭代稳定性分析。} 根据成像文献设置 Poisson 探测噪声，完成多种子重复，记录误差随迭代开销的变化。
\end{enumerate}
\section*{目前得到的认识}
在本轮固定条件下，无噪声时 RAAR 的最终复场误差最低；含噪时 ER 最低。增加迭代开销并不保证恢复更准确：本轮所有含噪求解在200次传播时的误差均高于80次传播。因此，后续需要关注噪声条件与停止准则对恢复效果的共同影响。

本阶段已完成\textbf{公开示例跑通与已知真值仿真对照}，结论范围仍是固定合成样品和已知理想校准。以下给出最近完成的噪声对照结果及图表。请老师指导下一步工作重点。
\section*{报告、源文件与结果在哪里}
\textbf{公开仓库：}\href{https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark}{LSA-FAST-Phase-Retrieval-Benchmark}（点击可打开），首页 README 提供最新报告和下载入口。
\begin{itemize}
\item \textbf{当前报告与可编辑 LaTeX：}\href{https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark/tree/main/reports/poisson_stage_20261004}{reports/poisson\_stage\_20261004/}。PDF 为阅读版，\path{MCF_Poisson_LaTeX.zip} 含正文、矢量图和绘图数据；解压后主文件为 \path{main.tex}。
\item \textbf{重建源码与运行入口：}\href{https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark/tree/main/src}{src/} 为仿真、求解和评分代码，\path{tools/} 为运行脚本；本轮 Windows 入口为 \path{START_POISSON_STAGE.cmd}。
\item \textbf{本轮原始结果：}\href{https://github.com/BoVVENGibNieAuf/LSA-FAST-Phase-Retrieval-Benchmark/tree/main/runs/pilot/poisson_stage_20261004}{runs/pilot/poisson\_stage\_20261004/}，含输入、最终复场、逐步误差CSV和参数记录。
\item \textbf{此前圆形 MCF 图像与方法说明：} 仓库 \path{reports/latex_delivery_20261004/} 与 \path{docs/methods/}；历史大文件恢复入口见首页说明。
\end{itemize}
\clearpage
\section*{本次补充：Poisson 噪声对照}
本轮完成48次固定预算求解，记录逐步误差；全部任务完成，最终误差由保存复场独立复核。
\section*{主要发现}
\begin{itemize}
\item 在两类布局、两个计数水平下，ER 的最终复场 NRMSE 均为四方法最低。$p=1$ 时周期／非周期分别为 0.6898／0.6940；$p=10$ 时为 0.2971／0.2958（三次均值）。
\item 全部 48 次求解的复场误差在 200 次传播时均高于 80 次传播。ER 的均值增幅在 $p=1$ 时为 0.1156／0.1095，在 $p=10$ 时为 0.0397／0.0390。继续迭代未改善这些含噪测量的真值误差。
\item $p=1$ 时，ER 的最终复场误差也高于初始参考（周期 0.6555、非周期 0.6739）；在四方法中最低并不等同于最终恢复优于初值。$p=10$ 时 ER 明显优于初值。
\item 原无噪声结果仍以 RAAR 最低（0.1182／0.1027）；无噪声排序不能直接推广至含噪条件。当前证据支持下一阶段研究噪声匹配与停止准则，尚未据真值选择新的停止点。请老师指导下一步重点。
\end{itemize}
\section*{本轮只改变探测噪声}
复用周期／非周期圆形端面、原 mixed 样品、支持域、已知理想参考场与固定算法参数。$2$ 布局$\times2$计数水平$\times3$种子$\times4$算法，共48次；每次200次正／反传播。无噪声结果复用原始保存记录。
\[
\alpha=\frac{p}{\langle I_{\rm ref}\rangle},\qquad
K_i\sim\operatorname{Poisson}(\alpha I_i),\qquad
A_i=\sqrt{K_i/\alpha},\quad p\in\{1,10\}.
\]
$p$ 为\textbf{空白参考帧全 $256\times256$ 像素平均检测计数}，单位为计数/像素/帧。样品吸收保留：实际期望样品均值为周期 $0.4206p$、非周期 $0.4126p$。不叠加读噪。随机种子为41001、41002、41003，同一条件下四算法共享同一输入。
\textbf{适用范围：} 单个合成样品、理想已知校准、固定参数，三次重复仅初步检查稳定性。本实验没有模拟低光子条件下参考校准的退化，不代表端到端实验系统性能。历史“20万总电子+1电子读噪”结果单独保留为工程测试。
\clearpage\begin{landscape}\thispagestyle{empty}
\section*{图1：误差随传播预算变化}
\begin{center}\includegraphics[width=242mm,height=143mm,keepaspectratio]{figures/convergence.pdf}\end{center}
\small 实线为三个种子的均值，阴影为最小--最大范围；四个面板对应两种布局与空白参考 $p=1/10$。本轮每2次传播记录一次，含初值，共4,848条记录，未平滑。48次均达到200次传播，无提前停止。HIO/ER/RAAR对应100次迭代；L-BFGS包含初始梯度及被拒绝线搜索的计算，横轴以实际传播开销公平比较，接受迭代数另存CSV。指标越低越好。\end{landscape}
\clearpage\begin{landscape}\thispagestyle{empty}
\section*{图2：最终误差与计数水平}
\begin{center}\includegraphics[width=242mm,height=140mm,keepaspectratio]{figures/noise_levels.pdf}\end{center}
\small $p=1/10$ 的圆点为各随机种子，短横线为均值；无噪声菱形为原200次传播保存结果，无新增重复。横轴是离散条件，不连接为连续光子扫描曲线。各方法均采用同一最终传播预算；相位误差及样本标准差见表1。\end{landscape}
\clearpage
\section*{表1：200次传播的最终误差}
\small\begin{center}\begin{tabular}{ll l rr}\toprule
布局 & $p$ & 方法 & 复场 NRMSE & 相位 RMSE / rad\\\midrule
TABLE_ROWS
\bottomrule\end{tabular}\end{center}
每项为3次重复的均值 $\pm$ 样本标准差（$n-1$分母），不作显著性检验。全部求解停止原因为达到传播预算。
\subsection*{指标与核验}
原评分ROI保持不变。令真值为 $u_\star$、共同支持域投影后的结果为 $\hat u$，仅按原ROI $\Omega$ 对齐一个全局相位：
\[
\theta=\arg\sum_{i\in\Omega}\overline{u_{\star,i}}\hat u_i,\qquad
E_u=\frac{\|e^{-\mathrm{i}\theta}\hat u-u_\star\|_2}{\|u_\star\|_2},\qquad
E_\phi=\sqrt{\frac{1}{|\Omega|}\sum_{i\in\Omega}\arg\!\left(e^{-\mathrm{i}\theta}\hat u_i\overline{u_{\star,i}}\right)^2}.
\]
复场指标在全场计算，相位指标在ROI计算；无增益拟合。真值仅用于求解后评价。17个源代码及输入哈希一致，48份完成回执校验通过，96项最终指标由保存复场独立重算。逐步曲线来自MATLAB评分记录，未另行重跑重建。
\subsection*{文献依据与迁移边界}
\begin{enumerate}\raggedright
\item \textit{Learning to synthesize: robust phase retrieval at low photon counts}, Light: Science \& Applications (2020). \newline\href{https://doi.org/10.1038/s41377-020-0267-2}{doi:10.1038/s41377-020-0267-2}，式(5)支持探测域Poisson+Gaussian形式，并研究约1/10 photons/pixel/frame。
\item \textit{Low Photon Count Phase Retrieval Using Deep Learning}, PRL (2018). \newline\href{https://doi.org/10.1103/PhysRevLett.121.243902}{doi:10.1103/PhysRevLett.121.243902}，参考照明计数定义依据。
\item \textit{Experimental robustness of Fourier Ptychography phase retrieval algorithms}, Optics Express (2015). \newline\href{https://doi.org/10.1364/OE.23.033214}{doi:10.1364/OE.23.033214}，强度Poisson鲁棒性对照依据。
\end{enumerate}
本轮选择纯Poisson分量，并以空白帧均值标定。计数水平是迁移的研究条件，未逐项复现论文探测效率、读噪或光学系统；不把检测计数直接等同于未经效率校正的入射光子数。
\end{document}
'''.replace('TABLE_ROWS','\n'.join(rows))
(L/'main.tex').write_text(tex)
shutil.copy2(R/'reports/latex_delivery_20261004/build.sh',L/'build.sh')
shutil.copy2(R/'reports/latex_delivery_20261004/build.cmd',L/'build.cmd')
(L/'README.md').write_text('XeLaTeX运行两次或 tectonic main.tex。正文、两张矢量主图、全部曲线CSV与核验摘要均包含。原始MAT结果见项目 runs/pilot/poisson_stage_20261004。\n')
