function run_fast_clean_convergence
% Dense diagnostics only; original solver, fixed inputs and parameters.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src','simulation'),fullfile(root,'src','solvers'),fullfile(root,'src','metrics'));
old=fullfile(root,'runs','pilot','four_20261003_224047_034');
out=fullfile(root,'runs','pilot','clean_convergence_20261004');
if ~isfolder(out), mkdir(out); end
lock=java.io.File(fullfile(root,'runs','pilot','FAIR_COMPARE.lock'));
assert(lock.mkdir(),'Another run is active'); guard=onCleanup(@()lock.delete()); %#ok<NASGU>
cfg=jsondecode(fileread(fullfile(old,'config.json'))); cfg.budgets=2:2:200;
writejson(fullfile(out,'config.json'),cfg);
provenance=struct('matlab_version',version,'sources',struct([]));
files={'tools/run_fast_clean_convergence.m','src/solvers/fast_four_solve.m','src/solvers/fast_amplitude_objective.m','src/solvers/fast_support_step.m','src/solvers/fast_raar_step.m','src/solvers/fast_project_amplitude.m','src/metrics/fast_field_error.m','src/simulation/fast_mcf_transfer.m'};
for k=1:2
 files{end+1}=fullfile('runs','pilot',cfg.source_runs{k},'mixed_clean_input.mat');
 files{end+1}=fullfile('evaluation_only',cfg.source_runs{k},'mixed_truth.mat');
end
for k=1:numel(files), provenance.sources(k).path=files{k}; provenance.sources(k).sha256=sha256(fullfile(root,files{k})); end
if isfile(fullfile(out,'provenance.json'))
 prior=jsondecode(fileread(fullfile(out,'provenance.json'))); assert(isequal(prior.sources(:),provenance.sources(:)),'Inputs/code changed');
else
 writejson(fullfile(out,'provenance.json'),provenance);
end
rows=struct([]); checks=struct([]); started=tic;
for k=1:2
 src=fullfile(root,'runs','pilot',cfg.source_runs{k}); base=jsondecode(fileread(fullfile(src,'config.json')));
 H=fast_mcf_transfer(base.n,base.dx,base.lambda,base.z);
 t=load(fullfile(root,'evaluation_only',cfg.source_runs{k},'mixed_truth.mat'));
 for c=1:1
  condition=cfg.conditions{c}; name=[base.layout '_' condition]; d=load(fullfile(src,['mixed_' condition '_input.mat']));
  for j=1:4
   assert(toc(started)<900,'Batch time cap'); method=cfg.methods{j}; file=fullfile(out,[name '_' method '.csv']);
   checkfile=fullfile(out,[name '_' method '_check.json']);
   if isfile(file) && isfile(checkfile), continue; end
   result=fast_four_solve(d,H,cfg,method);
   saved=load(fullfile(old,name,[method '_result.mat']));
   for b=[80 200]
    a=result.snapshots([result.snapshots.budget]==b); z=saved.result.snapshots([saved.result.snapshots.budget]==b);
    delta=norm(a.physical_output-z.physical_output,'fro')/max(norm(z.physical_output,'fro'),eps);
    assert(delta<1e-11 && a.iteration==z.iteration,'Original checkpoint mismatch');
    check=struct('case',name,'method',method,'budget',b,'relative_field_delta',delta);
    checks=[checks check]; %#ok<AGROW>
   end
   s0=struct('physical_output',d.mask.*d.calibration,'iteration',0,'solver_propagations',0,'state_propagations',0,'budget',0);
   part=score(s0,t,name,method,d,H);
   for s=result.snapshots, part(end+1)=score(s,t,name,method,d,H); end %#ok<AGROW>
   writetable(struct2table(part),file);
   fid=fopen(checkfile,'w'); fwrite(fid,jsonencode(checks(end-1:end))); fclose(fid);
   fprintf('CONVERGENCE_DONE %s %s\n',name,method);
  end
 end
end
for k=1:2
 for c=1:1
  name=[cfg.layouts{k} '_' cfg.conditions{c}];
  for j=1:4
   p=table2struct(readtable(fullfile(out,[name '_' cfg.methods{j} '.csv']))); rows=[rows; p(:)]; %#ok<AGROW>
  end
 end
end
writetable(struct2table(rows),fullfile(out,'curves.csv'));
fid=fopen(fullfile(out,'status.json'),'w'); fwrite(fid,jsonencode(struct('state','completed','rows',numel(rows),'seconds',toc(started),'backend','MATLAB CPU double','original_run','four_20261003_224047_034'))); fclose(fid);
end
function r=score(s,t,name,method,d,H)
u=s.physical_output; [~,phase,theta]=fast_field_error(u,t.truth,t.roi);
r=struct('case',name,'method',method,'iterations',s.iteration,'propagations',s.solver_propagations,'state_propagations',s.state_propagations,'field_nrmse',norm(u*exp(-1i*theta)-t.truth,'fro')/norm(t.truth,'fro'),'phase_rmse_rad',phase,'measurement_amplitude_nrmse',norm(abs(ifft2(fft2(u).*H))-d.amplitude,'fro')/norm(d.amplitude,'fro'));
% Scoring propagation is diagnostic only, excluded from solver budget.
end

function writejson(p,s)
f=fopen(p,'w'); assert(f>=0); fwrite(f,jsonencode(s)); fclose(f);
end
function h=sha256(p)
f=fopen(p,'rb'); b=fread(f,Inf,'*uint8'); fclose(f); d=java.security.MessageDigest.getInstance('SHA-256'); d.update(b); h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
