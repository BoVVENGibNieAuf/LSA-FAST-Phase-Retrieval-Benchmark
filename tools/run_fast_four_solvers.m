function run_id=run_fast_four_solvers(resume_id)
% Four-solver architecture pilot reuses frozen MCF inputs without regeneration.
% Optional failed-run ID reuses completed method outputs after hash validation.
root=fileparts(fileparts(mfilename('fullpath'))); oldpath=path;
pathGuard=onCleanup(@()path(oldpath)); %#ok<NASGU>
addpath(fullfile(root,'configs'),fullfile(root,'src','simulation'), ...
 fullfile(root,'src','solvers'),fullfile(root,'src','metrics'),fullfile(root,'tests'));
pilot=fullfile(root,'runs','pilot'); lockpath=fullfile(pilot,'FAIR_COMPARE.lock');
lock=java.io.File(lockpath);
assert(lock.mkdir(),'FAST:Locked','Another pilot is active; inspect lock before recovery');
lockGuard=onCleanup(@()rmdir(lockpath)); %#ok<NASGU>
resuming=nargin>0 && ~isempty(resume_id);
if resuming
 assert(~isempty(regexp(resume_id,'^four_[0-9_]+$','once')));
 out=fullfile(pilot,resume_id); cfg=jsondecode(fileread(fullfile(out,'config.json')));
 status=jsondecode(fileread(fullfile(out,'status.json')));
 assert(ismember(status.state,{'failed','completed_with_failures'}),'FAST:ResumeState','Resume requires stopped failed run');
 archive=fullfile(out,['recovery_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]); mkdir(archive);
 for name={'status.json','failure.json','metrics.json','metrics.csv','failures.json','REPORT.md'}
  if isfile(fullfile(out,name{1})), copyfile(fullfile(out,name{1}),fullfile(archive,name{1})); end
 end
else
 cfg=fast_four_solver_config; cfg.run_id=['four_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
 out=fullfile(pilot,cfg.run_id); assert(~isfolder(out)); mkdir(out);
 writejson(fullfile(out,'config.json'),cfg);
end
run_id=cfg.run_id; total=tic;
diary(fullfile(out,'matlab.log')); diaryGuard=onCleanup(@()diary('off')); %#ok<NASGU>
try
 writejson(fullfile(out,'status.json'),struct('state','running','stage','tests'));
 sources={'configs/fast_four_solver_config.m','src/solvers/fast_four_solve.m', ...
 'src/solvers/fast_raar_step.m','src/solvers/fast_amplitude_objective.m', ...
 'src/solvers/fast_project_amplitude.m','src/solvers/fast_support_step.m', ...
 'src/simulation/fast_mcf_transfer.m','src/simulation/fast_mcf_config.m', ...
 'src/metrics/fast_field_error.m','tools/run_fast_four_solvers.m','tests/test_fast_four_solvers.m'};
 provenance=struct('matlab',version,'computer',computer,'sources',struct([]));
 for j=1:numel(sources)
  provenance.sources(j).path=sources{j}; provenance.sources(j).sha256=sha256(fullfile(root,sources{j}));
 end
 if resuming
  previous=jsondecode(fileread(fullfile(out,'provenance.json')));
  for j=1:numel(previous.sources)
   assert(strcmp(sha256(fullfile(root,previous.sources(j).path)),previous.sources(j).sha256), ...
    'FAST:ChangedSource','Resume source changed: %s',previous.sources(j).path);
  end
 else
  writejson(fullfile(out,'provenance.json'),provenance);
 end
 checks=test_fast_four_solvers; writejson(fullfile(out,'tests.json'),checks);
 assert(checks.passed,'FAST:Tests','Four-solver numerical checks failed; inspect tests.json');
 previous_manifest=struct([]);
 if resuming && isfile(fullfile(out,'data_manifest.json'))
  previous_manifest=jsondecode(fileread(fullfile(out,'data_manifest.json')));
 end
 rows=struct([]); failures=struct([]); manifest=struct([]); completed=0;
 for layoutIndex=1:numel(cfg.source_runs)
  source_id=cfg.source_runs{layoutIndex}; source=fullfile(pilot,source_id);
  base=jsondecode(fileread(fullfile(source,'config.json')));
  original=jsondecode(fileread(fullfile(source,'data_manifest.json')));
  assert(strcmp(base.layout,cfg.layouts{layoutIndex}));
  H=fast_mcf_transfer(base.n,base.dx,base.lambda,base.z);
  for c=1:numel(cfg.conditions)
   condition=cfg.conditions{c}; inputname=[cfg.scene '_' condition];
   name=[base.layout '_' condition]; caseDir=fullfile(out,name);
   if ~isfolder(caseDir), mkdir(caseDir); end
   inputPath=fullfile(source,[inputname '_input.mat']);
   truthPath=fullfile(root,'evaluation_only',source_id,[cfg.scene '_truth.mat']);
   expected=original(strcmp({original.case},inputname)); assert(isscalar(expected));
   input_hash=sha256(inputPath); truth_hash=sha256(truthPath);
   assert(strcmp(input_hash,expected.input_sha256) && strcmp(truth_hash,expected.truth_sha256), ...
    'FAST:InputChanged','Frozen input or truth changed');
   entry=struct('case',name,'source_run',source_id,'input_sha256',input_hash,'truth_sha256',truth_hash, ...
    'calibration_id',[source_id ':saved_known_synthetic_reference'],'seed',base.seed, ...
    'source_config_sha256',sha256(fullfile(source,'config.json')),'physical_config',base);
   if ~isempty(previous_manifest)
    old_entry=previous_manifest(strcmp({previous_manifest.case},name));
    if ~isempty(old_entry)
     assert(strcmp(entry.input_sha256,old_entry.input_sha256) && ...
      strcmp(entry.truth_sha256,old_entry.truth_sha256) && ...
      strcmp(entry.source_config_sha256,old_entry.source_config_sha256),'FAST:ResumeInput','Resume provenance changed');
    end
   end
   manifest=append(manifest,entry); writejson(fullfile(out,'data_manifest.json'),manifest);
   d=load(inputPath,'amplitude','mask','calibration');
   outputs=struct; receipts=struct([]);
   for m=1:numel(cfg.methods)
    method=cfg.methods{m}; resultPath=fullfile(caseDir,[method '_result.mat']);
    receiptPath=fullfile(caseDir,[method '_receipt.json']);
    assert(toc(total)<cfg.max_wall_seconds,'FAST:BatchTimeout','Batch soft wall-clock cap reached');
    writejson(fullfile(out,'status.json'),struct('state','running','case',name,'method',method, ...
     'completed_solver_runs',completed,'total_solver_runs',16));
    try
     if resuming && isfile(resultPath) && isfile(receiptPath)
      receipt=jsondecode(fileread(receiptPath));
      assert(strcmp(receipt.result_sha256,sha256(resultPath)) && strcmp(receipt.input_sha256,input_hash));
      saved=load(resultPath,'result'); result=saved.result;
     else
      % Preserve interrupted/failed attempts; completed methods are reused.
      attempt=fullfile(caseDir,[method '_attempt_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]); mkdir(attempt);
      warm=ifft2(fft2(d.calibration).*H); warm=ifft2(fft2(warm).*conj(H)); clear warm
      result=fast_four_solve(d,H,cfg,method,attempt);
      if isfile(resultPath)
       copyfile(resultPath,fullfile(attempt,'previous_result.mat'));
      end
      save(resultPath,'result','-v7');
      receipt=struct('method',method,'input_sha256',input_hash,'result_sha256',sha256(resultPath), ...
       'stop_reason',result.stop_reason,'solver_propagations',result.solver_propagations);
      writejson(receiptPath,receipt);
     end
     % Same 80-call output as previously executed 40-step HIO/ER baseline.
     if ismember(method,{'HIO','ER'})
      old=load(fullfile(source,inputname,[method '_iter040.mat']),'physical_output');
      s=result.snapshots([result.snapshots.budget]==80);
      delta=norm(s.physical_output-old.physical_output,'fro')/max(norm(old.physical_output,'fro'),eps);
      assert(delta<1e-11,'FAST:LegacyRegression','HIO/ER 80-call output differs from saved baseline');
      writejson(fullfile(caseDir,[method '_legacy_check.json']),struct('relative_error',delta,'passed',true));
     end
     receipts=append(receipts,receipt);
     for s=result.snapshots
      r=score(s,d,H,truthPath,name,base.layout,condition,method,result.stop_reason);
      rows=append(rows,r);
     end
     outputs.(method)=result.snapshots(end).physical_output;
     completed=completed+1;
     if strcmp(result.stop_reason,'line_search_failed')
      failures=append(failures,struct('case',name,'method',method,'identifier','FAST:LineSearch', ...
       'message','L-BFGS line search stopped; latest accepted field scored with actual call count'));
     end
    catch err
     failure=struct('case',name,'method',method,'identifier',err.identifier,'message',err.message);
     failures=append(failures,failure);
     writejson(fullfile(caseDir,[method '_failure_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.json']), ...
      struct('failure',failure,'report',getReport(err,'extended','hyperlinks','off')));
    end
    writejson(fullfile(out,'metrics.json'),rows); writejson(fullfile(out,'failures.json'),failures);
   end
   writejson(fullfile(caseDir,'receipts.json'),receipts);
   plot_case(caseDir,outputs,d,truthPath,base,cfg,name,rows);
  end
 end
 if ~isempty(rows), writetable(struct2table(rows),fullfile(out,'metrics.csv')); end
 report(out,cfg,rows,failures,toc(total));
 state='completed'; if ~isempty(failures), state='completed_with_failures'; end
 writejson(fullfile(out,'status.json'),struct('state',state,'completed_solver_runs',completed, ...
  'total_solver_runs',16,'failure_count',numel(failures),'elapsed_seconds',toc(total),'report','REPORT.md'));
 fprintf('FOUR_SOLVERS_COMPLETE: %s\n',out);
 if ~isempty(failures), error('FAST:SolverFailures','Some methods failed; inspect failures.json and report'); end
catch err
 current_status=jsondecode(fileread(fullfile(out,'status.json')));
 if ~strcmp(current_status.state,'completed_with_failures')
  writejson(fullfile(out,'status.json'),struct('state','failed','elapsed_seconds',toc(total)));
 end
 writejson(fullfile(out,'failure.json'),struct('identifier',err.identifier,'message',err.message, ...
  'report',getReport(err,'extended','hyperlinks','off')));
 rethrow(err)
end
end
function row=score(s,d,H,truthPath,name,layout,condition,method,stop)
t=load(truthPath,'truth','roi'); f=s.physical_output; prediction=ifft2(fft2(f).*H);
[roi_error,phase_error,theta]=fast_field_error(f,t.truth,t.roi);
invalid=mean(abs(f(t.roi))<=1e-12); if invalid>0, phase_error=NaN; end
row=struct('case',name,'layout',layout,'condition',condition,'method',method,'budget',s.budget, ...
 'solver_propagations',s.solver_propagations,'state_propagations',s.state_propagations, ...
 'iterations',s.iteration,'solver_seconds',s.solver_seconds,'scoring_propagations',1, ...
 'amplitude_nrmse',norm(abs(prediction)-d.amplitude,'fro')/norm(d.amplitude,'fro'), ...
 'field_nrmse',norm(f*exp(-1i*theta)-t.truth,'fro')/norm(t.truth,'fro'), ...
 'bright_core_field_nrmse',roi_error,'phase_rmse_rad',phase_error,'phase_invalid_fraction',invalid, ...
 'stop_reason',stop,'line_trials',s.line_trials,'rejected_trials',s.rejected_trials);
end
function plot_case(out,outputs,d,truthPath,base,cfg,name,rows)
t=load(truthPath,'truth','roi'); labels=[{'TRUTH'} reshape(cfg.methods,1,[])];
f=figure('Visible','off'); guard=onCleanup(@()close(f)); %#ok<NASGU>
x=((0:base.n-1)-(base.n-1)/2)*base.dx*1e6;
ampmax=max(abs(t.truth(:))); phaselim=pi;
for j=1:numel(cfg.methods)
 if isfield(outputs,cfg.methods{j}), w=outputs.(cfg.methods{j}); ampmax=max(ampmax,max(abs(w(:)))); end
end
for j=1:numel(labels)
 label=labels{j};
 if strcmp(label,'TRUTH'), u=t.truth;
 elseif isfield(outputs,label), u=outputs.(label);
 else, continue
 end
 [~,~,theta]=fast_field_error(u,t.truth,t.roi);
 phase=angle(u.*conj(d.calibration)*exp(-1i*theta)); phase(~t.roi)=NaN;
 subplot(2,5,j); imagesc(x,x,abs(u),[0 ampmax]); axis image; colorbar; title([label ' amplitude']);
 subplot(2,5,j+5); imagesc(x,x,phase,[-phaselim phaselim]); axis image; colorbar; title([label ' phase (rad)']);
end
sgtitle([name ' / 200-call budget; coordinates um']);
set(f,'Position',[30 30 1650 700]); exportgraphics(f,fullfile(out,'fields_200.png'),'Resolution',140);
f2=figure('Visible','off'); guard2=onCleanup(@()close(f2)); %#ok<NASGU>
metrics={'amplitude_nrmse','field_nrmse','phase_rmse_rad'};
for j=1:3
 for axisKind=1:2
  subplot(2,3,j+3*(axisKind-1)); hold on
  for m=1:numel(cfg.methods)
   if isempty(rows), continue; end
   r=rows(strcmp({rows.case},name)&strcmp({rows.method},cfg.methods{m}));
   if isempty(r), continue; end
   if axisKind==1, xx=[r.solver_propagations]; else, xx=[r.solver_seconds]; end
   plot(xx,[r.(metrics{j})],'-o','DisplayName',cfg.methods{m});
  end
  if axisKind==1, xlabel('Actual solver propagations'); else, xlabel('Solver seconds'); end
  title(strrep(metrics{j},'_',' ')); grid on; legend('Location','best');
 end
end
set(f2,'Position',[30 30 1250 700]); exportgraphics(f2,fullfile(out,'cost_curves.png'),'Resolution',140);
end
function report(out,cfg,rows,failures,elapsed)
f=fopen(fullfile(out,'REPORT.md'),'w','n','UTF-8'); assert(f>=0); guard=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'# FAST / MCF 四求解器阶段汇报\n\n运行编号：`%s`\n\n',cfg.run_id);
fprintf(f,'## 本次工作\n\n按课题说明接入 HIO、ER、RAAR 和幅值损失 L-BFGS，统一输入、参考初值、支持域、传播算子和评分。复用规则与不规则纤芯各一个固定样本，覆盖干净与含噪测量，共 16 个求解任务。\n\n');
fprintf(f,'按累计 80、200 次传播调用保存输出，线搜索及拒绝试探的开销全部计入。CPU double；HIO beta=0.2，RAAR beta=0.9；L-BFGS 记忆长度 10，Armijo 线搜索，幅值平滑 epsilon=1e-8（检测振幅 RMS 归一化单位）。参数为首轮固定配置。\n\n');
fprintf(f,'## 200 次传播预算结果\n\n|纤芯|测量|方法|实际调用|接受步数|振幅残差|复场 NRMSE|相位 RMSE / rad|求解秒|停止原因|\n|---|---|---|---:|---:|---:|---:|---:|---:|---|\n');
for j=1:numel(rows)
 r=rows(j); if r.budget~=200, continue; end
 fprintf(f,'|%s|%s|%s|%d|%d|%.4f|%.4f|%.4f|%.3f|%s|\n',r.layout,r.condition,r.method, ...
  r.solver_propagations,r.iterations,r.amplitude_nrmse,r.field_nrmse,r.phase_rmse_rad,r.solver_seconds,r.stop_reason);
end
fprintf(f,'\n振幅残差为预测检测振幅与测量振幅的相对二范数差。复场和相位误差由保存的仿真真值评分，只对齐一个全局相位。相位评分采用预先固定的亮纤芯区域。\n\n');
fprintf(f,'## 实际运行图\n\n');
for l=1:numel(cfg.layouts)
 for c=1:numel(cfg.conditions)
  name=[cfg.layouts{l} '_' cfg.conditions{c}];
  fprintf(f,'### %s\n\n![恢复振幅与参考校正相位](%s/fields_200.png)\n\n![误差与计算代价](%s/cost_curves.png)\n\n',name,name,name);
 end
end
fprintf(f,'## 运行记录\n\n端到端用时 %.2f 秒；失败记录 %d 条。每项输出附输入与代码哈希、调用数、计时和停止原因。评分传播开销单列，图像使用统一色标。\n\n',elapsed,numel(failures));
for j=1:numel(failures), fprintf(f,'- %s / %s：%s\n',failures(j).case,failures(j).method,failures(j).message); end
fprintf(f,'\n本轮覆盖两个纤芯排布、一个固定随机种子和两种测量条件，采用已知仿真参考校准。\n\n请老师指导下一阶段的工作重点。\n');
end
function rows=append(rows,row)
if isempty(rows), rows=row; else, rows(end+1)=row; end
end
function writejson(p,value)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); guard=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,unicode2native(jsonencode(value,'PrettyPrint',true),'UTF-8'),'uint8');
end
function h=sha256(p)
f=fopen(p,'rb'); assert(f>=0); guard=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
