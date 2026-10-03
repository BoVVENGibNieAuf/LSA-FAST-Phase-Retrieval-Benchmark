# 圆形 MCF 汇报：LaTeX 工程

## 文件

- `main.tex`：完整中文报告，包含原生 LaTeX 数学公式。
- `figures/`：8 张独立 PDF 结果图和布局图；PDF 中坐标与文字为矢量，场数据为原始数值网格。
- `main.pdf`：实际编译的阅读版（构建后生成）。
- `data/`：本次报告使用的指标 CSV、相机审计和图数据来源摘要。
- `MANIFEST.sha256`：工程内容校验清单。

## 编译

推荐 XeLaTeX（TeX Live / MiKTeX，含中文支持）运行两遍：

```sh
xelatex -interaction=nonstopmode -halt-on-error main.tex
xelatex -interaction=nonstopmode -halt-on-error main.tex
```

也可使用 Tectonic：

```sh
tectonic --keep-logs main.tex
```

Windows 安装好 XeLaTeX 后双击 `build.cmd`；Linux/macOS 执行 `sh build.sh`。
包依赖均为常见 TeX Live 宏包；中文使用 `ctex` 的 Fandol 字体集，不依赖 Windows 专有字体。
首次运行 Tectonic 需要联网下载 TeX 宏包和字体，缓存后可复用。

在 Overleaf 中上传整个工程 ZIP、选用 XeLaTeX、将主文档设为 `main.tex` 即可。此为可选操作；未替用户上传 Overleaf。

## 数据与修订范围

原始求解批次：`four_20261003_224047_034`；输入批次：
`mcf_20261003_224006_279_01` 和 `_02`。
16 组 200 次传播结果的复场 NRMSE 已从保存的 MAT 恢复场重新计算，与原始 CSV 一致。
本工程仅进行公式排版、说明完善与图表复用，没有重跑求解器或改变原始结果。

报告中的 20 万为整个空白参考帧的总期望光电子数；样品帧总期望计数另表列出。
相机模型使用 `fast_mcf_camera.m`，而不是后续噪声扫描的其他采样器。
公式定义明确区分负值截断前读数、非负计数与求解器输入振幅。
