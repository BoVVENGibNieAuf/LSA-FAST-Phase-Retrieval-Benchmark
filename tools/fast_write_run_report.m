function fast_write_run_report(out,m,environment)
% Called only after successful numerical execution and image export.
fid=fopen(fullfile(out,'REPORT.md'),'w','n','UTF-8');
assert(fid>=0,'Cannot create report'); c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# FAST 作者公开示例复现报告\n\n');
fprintf(fid,'状态：作者 2500 次校准、40 次样品更新已完成。MATLAB %s。\n\n',environment.matlab_version);
fprintf(fid,'范围：公开相位目标示例。没有独立相位真值，不代表已复现论文所有实验、1 μm 分辨率或纳米级准确度。\n\n');
fprintf(fid,'## 输入—参数—输出\n\n');
fprintf(fid,'|步骤|输入|参数与操作|输出|\n|---|---|---|---|\n');
fprintf(fid,'|读取|data/raw/data.mat|四幅 1920×2560 double 幅值；不再次开平方|两参考幅值、样品幅值、端面参考幅值、zs|\n');
fprintf(fid,'|支持域|amp_facet_ref|imbinarize 阈值 0.02；imclose，strel disk 半径 10 像素|mask|\n');
fprintf(fid,'|传播|当前复场|作者 prop.m；dp=2.2 μm，λ=532 nm；无新增 padding 或带限|传播后的复场|\n');
fprintf(fid,'|参考校准|两检测面参考幅值、mask|zs=[78.8,86] mm；零相位、mask 振幅初始化；β=0.2；2500 次|reference.mat：复场、相位、amp_cc|\n');
fprintf(fid,'|样品恢复|amp_far_sam、mask、参考相位|z=78.8 mm；mask×exp(i×参考相位)；β=0.2；40 次|sample.mat：第39、40次输出复场|\n');
fprintf(fid,'|参考校正|样品与参考相位|相位相减后 wrapToPi；不做相位展开|第40次原始校正相位|\n');
fprintf(fid,'|作者显示|第39次相位与参考|加4.1 rad，wrapToPi，乘mask，11×11中值滤波|08_author_display39.png|\n');
fprintf(fid,'|最终迭代对照|第40次相位与参考|同样的显示处理|09_final_iteration40_display.png|\n');
fprintf(fid,'\n校准每轮按 n=1、2 顺序更新；第二检测面使用第一检测面更新后的场，再对该轮两次输出取平均。不是两路独立并行更新。\n\n');
fprintf(fid,'HIO：支持域内接受反传场；域外为旧场减 0.2 倍反传场。域外迭代值不要求每次为零。\n\n');
fprintf(fid,'## 实测运行与一致性检查\n\n');
fprintf(fid,'- 校准耗时（包含启动检查、读入）：%.1f s；总耗时：%.1f s。\n',m.calibration_seconds,m.total_seconds);
fprintf(fid,'- 原算法传播次数：%d；另加验证传播：%d。\n',m.algorithm_propagations,m.extra_validation_propagations);
fprintf(fid,'- 最终参考振幅与实测端面振幅相关系数：%.6f。\n',m.facet_amplitude_correlation);
fprintf(fid,'- 参考检测面 A / B 幅值 NRMSE：%.6f / %.6f。\n',m.reference_amplitude_nrmse_a,m.reference_amplitude_nrmse_b);
fprintf(fid,'- 样品第 39 / 40 次幅值 NRMSE：%.6f / %.6f。\n',m.sample_amplitude_nrmse39,m.sample_amplitude_nrmse40);
fprintf(fid,'- 第39到40次的支持域内包裹相位变化 RMS：%.6f rad。\n',m.phase_change39_to40_rms_in_mask_rad);
fprintf(fid,'- 第40次辅助迭代场的域外能量占比：%.6f。\n',m.sample_outside_energy_fraction40);
fprintf(fid,'- 停止原因：达到作者固定迭代次数，不是自动收敛判定。\n\n');
fprintf(fid,'幅值 NRMSE = 预测幅值与实测幅值差的二范数 / 实测幅值二范数；未做最优缩放；对原始 HIO 迭代场计算。数据一致性与振幅相关性不是独立相位准确度。\n\n');
fprintf(fid,'## 结果图\n\n');
fprintf(fid,'![支持域](02_support_mask.png)\n\n![收敛记录](10_calibration_convergence.png)\n\n');
fprintf(fid,'![作者显示结果](08_author_display39.png)\n\n![实际第40次结果](09_final_iteration40_display.png)\n\n');
fprintf(fid,'## 实现边界\n\n');
fprintf(fid,'冻结 legacy_fast 未改动。executed_main.m 保留实际执行脚本：仅去掉 clear/close all/clc，加入日志、有限数检查、检查点、2小时循环上限和保存钩子；默认隐藏新图窗。没有修改传播、精度、HIO、次数或显示处理。随机种子0，原初始化不使用随机数。单个当前GPU；无GPU时保留作者CPU分支。\n\n');
fprintf(fid,'作者 k 从2开始，因此校准显示/相关性记录位于实际第19、39、…、2499次，样品显示位于第9、19、29、39次。保留原显示结果，同时另存实际末次结果。原脚本没有执行倾斜校正（代码已注释）、样品面数字重聚焦或相位展开；本次也没有补加。4.1 rad 是作者显示常数，未把它解释为物理标定。\n\n');
fprintf(fid,'来源、哈希、环境与数值见 input_manifest.json、source_version.json、environment.mat、metrics.json、matlab.log。PNG 为可视化，定量处理应读取 MAT 文件。图像是否与论文指定面板吻合，仍需人工/独立参考核验；脚本完成不自动等于验证论文准确度。\n');
end

