# MATLAB 使用说明
## 当前环境
发现 C:/Program Files/MATLAB/R2024b/bin/matlab.exe；尚未验证 MATLAB 启动、许可证、工具箱、GPU 可用性。
Windows Python 的 SSL DLL 载入失败，下载已改用系统 curl 并成功；不影响下载的 MATLAB 文件。

## 检查
MATLAB 当前目录切换到项目根目录，执行 setup_project，然后 env = check_environment。
setup_project 只添加 src、configs、tools、tests，不添加 legacy_fast、raw 或 evaluation_only，也不调用 savepath 修改永久配置。
环境检查使用 whos('-file',...) 读取数据目录；不加载全部数据、不启动重建。

## 后续 T0 运行约定（本轮未执行）
先审计 main.m 的显示输出时点和依赖，确认计算资源与运行记录方案。
原始 main.m 包含 clear、close all、clc；2500 次参考循环、40 次样品循环，运行可能很久。
从新的 runs/pilot/<run_id>/ 工作目录调用原始代码；临时将 legacy_fast 和 data/raw 加入搜索路径，结束后恢复路径。
不要 cd 到 legacy_fast 写结果，不将 data.mat 复制回原代码目录，不覆盖原始文件。
原生 main.m 未自动保存所有中间结果，也没有硬超时；完整记录入口尚未实现，不要将裸 main 运行当作完整基准。
参考参数：dp=2.2e-6 m，lambda=532e-9 m，beta=0.2。它们是作者样例值，不是当前实验系统标定。
原版调用 imbinarize、imclose、strel、corr2、medfilt2、gpuDeviceCount、gpuArray、gather、wrapToPi；须检查 Image Processing、Parallel Computing、Mapping 等相应依赖，不修改原版以偷偷绕过。

## 数据
data/raw/data.mat 为 MATLAB v5 格式，148903690 字节。
amp_facet_ref、amp_far_ref_a、amp_far_ref_b、amp_far_sam：1920 x 2560 double。
zs：1 x 2 double，值 [0.0788, 0.086]，代码将其用作米制检测传播距离。
四幅数组在代码中按幅值使用，不应再盲目开平方；上游归一化/曝光/暗场细节待核实。
没有提供可直接用于逐像素评分的独立复场真值。

## 校验
data_manifest.json 记录下载 URL、冻结提交、字节数和 SHA-256。
Windows 只读属性是防误改措施，不等于完整 ACL 隔离或备份。

## 2026-09-27 复现入口（尚未完成数值运行）
用户已授权运行作者示例，覆盖上文初始整理阶段的暂不运行约定。执行 setup_project; run_fast_reproduction。详见 reports/FAST_reproduction_audit_20260927.md。该入口已写入但未经 MATLAB 执行验证；远程启动检查超时，未生成 MATLAB 日志。仅实际成功后运行目录才会生成 REPORT.md 和 metrics.json，不能把步骤审计当成复现完成。

