# FAST / MCF 四求解器阶段汇报

运行编号：`four_20261003_224047_034`

## 本次工作

按课题说明接入 HIO、ER、RAAR 和幅值损失 L-BFGS，统一输入、参考初值、支持域、传播算子和评分。复用规则与不规则纤芯各一个固定样本，覆盖干净与含噪测量，共 16 个求解任务。

按累计 80、200 次传播调用保存输出，线搜索及拒绝试探的开销全部计入。CPU double；HIO beta=0.2，RAAR beta=0.9；L-BFGS 记忆长度 10，Armijo 线搜索，幅值平滑 epsilon=1e-8（检测振幅 RMS 归一化单位）。参数为首轮固定配置。

## 200 次传播预算结果

|纤芯|测量|方法|实际调用|接受步数|振幅残差|复场 NRMSE|相位 RMSE / rad|求解秒|停止原因|
|---|---|---|---:|---:|---:|---:|---:|---:|---|
|periodic|clean|ZERO|0|0|0.5966|0.6555|0.2504|0.000|zero_iteration|
|periodic|clean|HIO|200|100|0.0228|0.1489|0.1108|0.400|propagation_budget|
|periodic|clean|ER|200|100|0.0136|0.1475|0.1242|0.385|propagation_budget|
|periodic|clean|RAAR|200|100|0.0125|0.1182|0.0970|0.510|propagation_budget|
|periodic|clean|LBFGS|200|99|0.0120|0.2123|0.1665|0.957|propagation_budget|
|periodic|shot_read|ZERO|0|0|0.7229|0.6555|0.2504|0.000|zero_iteration|
|periodic|shot_read|HIO|200|100|0.3838|1.3988|1.7770|0.392|propagation_budget|
|periodic|shot_read|ER|200|100|0.3256|0.6313|0.4861|0.384|propagation_budget|
|periodic|shot_read|RAAR|200|100|0.4237|0.9480|1.0032|0.502|propagation_budget|
|periodic|shot_read|LBFGS|200|98|0.3195|0.8608|0.7725|0.865|propagation_budget|
|aperiodic|clean|ZERO|0|0|0.6165|0.6739|0.2584|0.000|zero_iteration|
|aperiodic|clean|HIO|200|100|0.0224|0.1267|0.0935|0.446|propagation_budget|
|aperiodic|clean|ER|200|100|0.0136|0.1292|0.1082|0.367|propagation_budget|
|aperiodic|clean|RAAR|200|100|0.0118|0.1027|0.0811|0.460|propagation_budget|
|aperiodic|clean|LBFGS|200|99|0.0119|0.1523|0.1147|0.875|propagation_budget|
|aperiodic|shot_read|ZERO|0|0|0.7374|0.6739|0.2584|0.000|zero_iteration|
|aperiodic|shot_read|HIO|200|100|0.3893|1.3830|1.7575|0.393|propagation_budget|
|aperiodic|shot_read|ER|200|100|0.3296|0.6231|0.4705|0.380|propagation_budget|
|aperiodic|shot_read|RAAR|200|100|0.4306|0.9260|0.9729|0.453|propagation_budget|
|aperiodic|shot_read|LBFGS|200|99|0.3234|0.8542|0.7733|1.039|propagation_budget|

振幅残差为预测检测振幅与测量振幅的相对二范数差。复场和相位误差由保存的仿真真值评分，只对齐一个全局相位。相位评分采用预先固定的亮纤芯区域。

## 实际运行图

### periodic_clean

![恢复振幅与参考校正相位](periodic_clean/fields_200.png)

![误差与计算代价](periodic_clean/cost_curves.png)

### periodic_shot_read

![恢复振幅与参考校正相位](periodic_shot_read/fields_200.png)

![误差与计算代价](periodic_shot_read/cost_curves.png)

### aperiodic_clean

![恢复振幅与参考校正相位](aperiodic_clean/fields_200.png)

![误差与计算代价](aperiodic_clean/cost_curves.png)

### aperiodic_shot_read

![恢复振幅与参考校正相位](aperiodic_shot_read/fields_200.png)

![误差与计算代价](aperiodic_shot_read/cost_curves.png)

## 运行记录

端到端用时 32.62 秒；失败记录 0 条。每项输出附输入与代码哈希、调用数、计时和停止原因。评分传播开销单列，图像使用统一色标。


本轮覆盖两个纤芯排布、一个固定随机种子和两种测量条件，采用已知仿真参考校准。

请老师指导下一阶段的工作重点。
