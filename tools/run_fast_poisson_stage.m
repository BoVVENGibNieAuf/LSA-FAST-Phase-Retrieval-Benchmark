function run_fast_poisson_stage
% Fixed preregistered 48-solve detector shot-noise experiment. MATLAB only.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src','simulation'),fullfile(root,'src','solvers'),fullfile(root,'src','metrics'));
out=fullfile(root,'runs','pilot','poisson_stage_20261004');
if ~isfolder(out), mkdir(out); end
lock=java.io.File(fullfile(root,'runs','pilot','FAIR_COMPARE.lock'));
assert(lock.mkdir(),'FAST:Locked','Another comparison lock exists'); guard=onCleanup(@()lock.delete()); %#ok<NASGU>
cfg=jsondecode(fileread(fullfile(root,'runs','pilot','four_20261003_224047_034','config.json')));
cfg.budgets=2:2:200; cfg.levels=[1 10]; cfg.seeds=[41001 41002 41003];
cfg.max_wall_seconds=3600; cfg.run_id='poisson_stage_20261004';
cfg.noise='Pure Poisson detector counts; alpha=p/mean(blank detector intensity); no read noise';
cfg.count_unit='expected detected counts/pixel/frame of blank reference, full 256x256 grid';
cfg.truth_use='evaluation only, fixed budget and parameters; no truth-based tuning';
cfg.calibration='unchanged known synthetic reference, no noisy recalibration';
provenance=struct('matlab_version',version,'backend','MATLAB CPU double','files',struct([]));
files={'tools/run_fast_poisson_stage.m','src/solvers/fast_four_solve.m','src/solvers/fast_amplitude_objective.m','src/solvers/fast_support_step.m','src/solvers/fast_raar_step.m','src/solvers/fast_project_amplitude.m','src/simulation/fast_mcf_camera.m','src/simulation/fast_mcf_transfer.m','src/metrics/fast_field_error.m'};
for k=1:2
 for f={'config.json','mixed_clean_input.mat','reference_measurements.mat'}
  files{end+1}=fullfile('runs','pilot',cfg.source_runs{k},f{1}); %#ok<AGROW>
 end
 files{end+1}=fullfile('evaluation_only',cfg.source_runs{k},'mixed_truth.mat'); %#ok<AGROW>
end
for k=1:numel(files), provenance.files(k).path=files{k}; provenance.files(k).sha256=sha256(fullfile(root,files{k})); end
provfile=fullfile(out,'provenance.json');
if isfile(provfile)
 prior=jsondecode(fileread(provfile)); assert(isequal(prior.files(:),provenance.files(:)),'FAST:ChangedSources','Source/input hashes changed; preserve old run');
else
 writejson(provfile,provenance);
end
writejson(fullfile(out,'config.json'),cfg);
timer=tic; done=0;
try
for k=1:2
 src=fullfile(root,'runs','pilot',cfg.source_runs{k}); base=jsondecode(fileread(fullfile(src,'config.json')));
 H=fast_mcf_transfer(base.n,base.dx,base.lambda,base.z);
 clean=load(fullfile(src,'mixed_clean_input.mat'));
 ref=load(fullfile(src,'reference_measurements.mat'),'reference_amplitudes');
 refI=ref.reference_amplitudes(:,:,find(abs(base.reference_z-base.z)<1e-15,1)).^2;
 assert(~isempty(refI)); intensity=clean.amplitude.^2;
 for p=cfg.levels
  for seed=cfg.seeds
   name=sprintf('%s_p%d_seed%d',base.layout,p,seed); caseDir=fullfile(out,name);
   if ~isfolder(caseDir), mkdir(caseDir); end
   inputfile=fullfile(caseDir,'input.mat'); alpha=p/mean(refI(:));
   if isfile(inputfile)
    d=load(inputfile); assert(d.camera.seed==seed && d.camera.exposure==alpha);
   else
    d=clean; [d.amplitude,d.camera]=fast_mcf_camera(intensity,alpha,0,seed);
    d.camera.p_blank=p; d.camera.expected_sample_mean=mean(alpha*intensity(:));
    d.camera.actual_sample_mean=mean(alpha*d.amplitude(:).^2);
    d.camera.model='Poisson only'; save(inputfile,'-struct','d');
   end
   for j=1:4
    method=cfg.methods{j}; resultfile=fullfile(caseDir,[method '_result.mat']);
    curvefile=fullfile(caseDir,[method '_curve.csv']); receiptfile=fullfile(caseDir,[method '_done.json']);
    if isfile(receiptfile)
     rr=jsondecode(fileread(receiptfile));
     assert(strcmp(rr.input_sha256,sha256(inputfile)) && strcmp(rr.result_sha256,sha256(resultfile)) && strcmp(rr.curve_sha256,sha256(curvefile)),'FAST:CheckpointChanged','Saved completion files changed');
     done=done+1; continue;
    end
    assert(toc(timer)<cfg.max_wall_seconds,'FAST:BatchTimeout','Batch cap');
    writejson(fullfile(out,'status.json'),struct('state','running','completed',done,'total',48,'current',[name '_' method]));
    result=fast_four_solve(d,H,cfg,method);
    % Ground truth loaded only after reconstruction returned.
    t=load(fullfile(root,'evaluation_only',cfg.source_runs{k},'mixed_truth.mat'));
    s0=struct('physical_output',d.mask.*d.calibration,'iteration',0,'solver_propagations',0,'state_propagations',0,'budget',0);
    rows=score(s0,t,base.layout,p,seed,method);
    for s=result.snapshots, rows(end+1)=score(s,t,base.layout,p,seed,method); end %#ok<AGROW>
    clear t
    writetable(struct2table(rows),curvefile);
    result.snapshots=result.snapshots(end); % retain final field, full objective trace and scalar curves
    save(resultfile,'result');
    receipt=struct('case',name,'method',method,'input_sha256',sha256(inputfile),'result_sha256',sha256(resultfile),'curve_sha256',sha256(curvefile),'stop_reason',result.stop_reason,'seconds',result.solver_seconds,'propagations',result.solver_propagations);
    writejson(receiptfile,receipt); done=done+1;
    fprintf('POISSON_DONE %d/48 %s %s\n',done,name,method);
   end
  end
 end
end
writejson(fullfile(out,'status.json'),struct('state','completed','completed',done,'total',48,'invocation_seconds',toc(timer),'matlab_version',version,'backend','MATLAB CPU double'));
catch e
 writejson(fullfile(out,'status.json'),struct('state','failed','completed',done,'total',48,'message',e.message,'invocation_seconds',toc(timer)));
 rethrow(e)
end
end
function r=score(s,t,layout,p,seed,method)
u=s.physical_output; [~,phase,theta]=fast_field_error(u,t.truth,t.roi);
r=struct('layout',layout,'p_blank',p,'seed',seed,'method',method,'budget',s.budget,'iterations',s.iteration,'propagations',s.solver_propagations,'state_propagations',s.state_propagations,'field_nrmse',norm(u*exp(-1i*theta)-t.truth,'fro')/norm(t.truth,'fro'),'phase_rmse_rad',phase);
end
function writejson(p,s)
f=fopen([p '.tmp'],'w'); assert(f>=0); fwrite(f,jsonencode(s)); fclose(f); movefile([p '.tmp'],p,'f');
end
function h=sha256(p)
f=fopen(p,'rb'); b=fread(f,Inf,'*uint8'); fclose(f); d=java.security.MessageDigest.getInstance('SHA-256'); d.update(b); h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
