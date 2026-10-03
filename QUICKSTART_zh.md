# 导师快速复跑：圆形端面 MCF

## 当前验证状态

2026-10-03：新入口和圆形模型已编写；节点 MATLAB 未成功启动，新数值结果、几何图及全新下载复跑**待验证**。旧六角外轮廓结果只作历史架构验证，不代表本模型。

## 所需环境

- 已激活的 MATLAB；项目此前使用 R2024b，其他版本尚未验证。
- CPU double，不要求 GPU。调用基础 MATLAB 数值、绘图及 Java SHA-256；不使用 Python 进行重建。
- 可写项目目录。Windows 脚本自动查找 PATH 或标准 MATLAB 安装目录；非标准目录可设置 `MATLAB_EXE`。
- 本轮完全生成模拟输入，不依赖作者的大体积 MAT 文件、历史运行目录或额外下载。

## 三步运行

1. 私有仓库需先获仓库拥有者授予访问权限；下载 ZIP 后解压，或 `git clone`。
2. Windows 双击 `START_CIRCULAR_BENCHMARK.cmd`。其他系统在 MATLAB 将当前目录切到工程根目录，执行：
   ```matlab
   setup_project
   run_fast_circular_benchmark
   ```
3. 成功后查看 `runs/latest_circular.json`：`four_run` 指向四方法报告，`batch` 指向几何图、冻结配置和批次状态。只有 `status.json` 为 `completed` 才算完成。

## 实验定义

两组均为模拟圆形端面：物理半径26 μm，芯中心范围22 μm，支持域半径29 μm。周期组采用3.2 μm间距六角晶格的圆内截取；非周期组采用固定种子随机排布，最小芯间距2.4 μm。匹配芯数（163芯）、模场宽度/增益/相位抽样、总参考光子数200000。圆形包层边界不意味着包层发光：光场仍集中在离散纤芯。

比较 FAST/HIO、ER、RAAR、幅值损失 L-BFGS；各有80和200次传播预算，线搜索拒绝试探也计费。零迭代参考另列，不算第五求解器。干净/散粒与读出噪声各一组，共16个四方法任务，32个预算结果及4个零迭代结果。

这是单固定样本的工程试运行；参数在评分前固定，没有开发/测试泛化声明，没有实测独立参考。尚不用于宣称某算法普遍最好。

## 结果位置

- `runs/pilot/circular_*/circular_geometry.png`：实际 MATLAB 生成几何图。
- `runs/pilot/circular_*/protocol.json`：评分前写入的范围和参数。
- `runs/pilot/four_*/REPORT.md`、`metrics.csv`、`tests.json`、`status.json`。
- 各条件目录：`fields_200.png`（含真值、零迭代和四方法）、`cost_curves.png`、检查点与方法回执。
- `evaluation_only/`：合成真值，仅评分代码读取；未实现操作系统级权限隔离。

## 中断与复跑

已完成历史结果不会覆盖。再次运行顶层入口会新建一次实验，不自动恢复在途 MATLAB 进程。
四方法运行若已写明 `failed` 或 `completed_with_failures`，可在检查无活动任务、锁已释放后执行 `run_fast_four_solvers('four_具体编号')`；会校验代码/输入哈希并复用完成的方法。生成阶段断点恢复仍用已有 `run_fast_mcf_pilot` 接口，顶层入口尚未实现整个批次自动续跑。不要直接删除未知活动锁。

## 资料入口

[四类方法卡](docs/methods/METHOD_CARDS_zh.md) · [方法卡 Word](docs/methods/FAST_四类求解器方法卡.docx) · [交付状态](docs/methods/DELIVERY_CHECKLIST_zh.md)

给导师的完整结果版 Word 需要本入口成功运行、核验真实图后生成；当前准备版不得当作完成结果汇报。
