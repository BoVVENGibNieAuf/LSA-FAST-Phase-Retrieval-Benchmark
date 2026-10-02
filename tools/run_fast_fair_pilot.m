function run_fast_fair_pilot
% Small T1 pilot: frozen common calibration, HIO vs ER, zero-iteration control.
% No quantitative phase-accuracy claim without independent truth.
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path; pathGuard=onCleanup(@()path(oldpath)); %#ok<NASGU>
addpath(fullfile(root,'legacy_fast'),fullfile(root,'src','solvers'), ...
 fullfile(root,'src','metrics'),fullfile(root,'tests'));
% Do not overlap another recorded author run.
s=dir(fullfile(root,'runs','pilot','author_*','status.json'));
for j=1:numel(s)
 q=jsondecode(fileread(fullfile(s(j).folder,s(j).name)));
 assert(~strcmp(q.state,'running'),'FAST:ActiveRun','An author run is marked running; inspect before starting.');
end
lockpath=fullfile(root,'runs','pilot','FAIR_COMPARE.lock');
lock=java.io.File(lockpath);
assert(lock.mkdir(),'FAST:Locked','Fair-comparison lock exists; inspect active work before removing it.');
lockGuard=onCleanup(@()rmdir(lockpath)); %#ok<NASGU>
id=['fair_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
out=fullfile(root,'runs','pilot',id); mkdir(out);
diary(fullfile(out,'matlab.log')); diaryGuard=onCleanup(@()diary('off')); %#ok<NASGU>
tAll=tic;
try
 cfg=struct('run_id',id,'version','fair-pilot-v1','calibration_id','author_20261002_184441', ...
 'methods',{{'HIO','ER'}},'iterations',40,'beta',0.2,'checkpoints',[10 20 30 40], ...
 'seed',0,'precision','double','max_wall_seconds',900,'minimum_free_gpu_bytes',2*1024^3, ...
 'physical_output','mask .* internal_state','initialization','mask .* exp(1i*phase_reference)', ...
 'phase_zero_convention','exp(1i*angle(0))=1','independent_phase_truth',false, ...
 'postprocessing','none','timing_scope','synchronized iteration blocks; excludes evaluation, IO, and checkpoint boundary finite check', ...
 'order',{{'HIO','ER'}},'statistical_scope','single public sample, single ordered timing trial; not a general ranking');
 writejson(fullfile(out,'config.json'),cfg);
 writejson(fullfile(out,'status.json'),struct('state','running','stage','tests'));
 tests=test_fast_fair(); writejson(fullfile(out,'tests.json'),tests);
 assert(tests.passed,'FAST:Tests','Correctness tests failed; see tests.json.');
 cal=fullfile(root,'runs','pilot',cfg.calibration_id);
 calStatus=jsondecode(fileread(fullfile(cal,'status.json')));
 assert(strcmp(calStatus.state,'completed'),'Calibration run incomplete');
 % Hash raw inputs and calibration against the verified restoration receipt.
 rawPath=fullfile(root,'data','raw','data.mat');
 assert(strcmp(sha256(rawPath),'5c532cef5747c3c892bf575ba38a2e75689078b02bb844eb05af8b5bcdae29d3'),'Raw input hash mismatch');
 inputs=struct('raw_sha256',sha256(rawPath),'reference_sha256',sha256(fullfile(cal,'reference.mat')), ...
 'author_sample_sha256',sha256(fullfile(cal,'sample.mat')));
 srcfiles={'tools/run_fast_fair_pilot.m','tests/test_fast_fair.m', ...
 'src/solvers/fast_project_amplitude.m','src/solvers/fast_support_step.m', ...
 'src/metrics/fast_field_error.m','legacy_fast/prop.m'};
 sources=struct('path',{},'sha256',{});
 for j=1:numel(srcfiles)
  sources(j).path=srcfiles{j}; sources(j).sha256=sha256(fullfile(root,srcfiles{j}));
 end
 inputs.sources=sources; writejson(fullfile(out,'provenance.json'),inputs);
 raw=load(rawPath,'amp_far_sam','zs');
 ref=load(fullfile(cal,'reference.mat'),'phase_reference','mask','dp','lambda','b','zs');
 assert(isequal(size(raw.amp_far_sam),size(ref.mask),size(ref.phase_reference)),'Size mismatch');
 assert(all(isfinite(raw.amp_far_sam(:))) && all(raw.amp_far_sam(:)>=0),'Invalid amplitude');
 assert(all(isfinite(ref.phase_reference(:))) && any(ref.mask(:)),'Invalid reference');
 assert(isequal(raw.zs,ref.zs) && ref.b==cfg.beta,'Calibration parameters mismatch');
 cfg.dp=ref.dp; cfg.lambda=ref.lambda; cfg.z_det_sample=raw.zs(1);
 cfg.grid=size(ref.mask); cfg.calibration_cost='reused; calibration excluded from both solvers';
 gpu=[]; useGPU=false;
 if exist('gpuDeviceCount','file') && gpuDeviceCount>0
  gpu=gpuDevice; useGPU=true;
  assert(gpu.AvailableMemory>=cfg.minimum_free_gpu_bytes,'Insufficient free GPU memory');
  cfg.backend='GPU'; cfg.device=gpu.Name; cfg.gpu_available_before=gpu.AvailableMemory;
 else
  cfg.backend='CPU'; cfg.device=computer;
 end
 cfg.peak_gpu_memory='not measured; before/after snapshots are not peak';
 writejson(fullfile(out,'config.json'),cfg);
 rng(cfg.seed,'twister');
 amplitude=raw.amp_far_sam; mask=double(ref.mask); phaseRef=ref.phase_reference;
 initial=mask.*exp(1i*phaseRef);
 if useGPU
  amplitude=gpuArray(amplitude); mask=gpuArray(mask); initial=gpuArray(initial);
 end
 P=@(u,z)prop(u,cfg.dp,cfg.dp,cfg.lambda,z);
 z=cfg.z_det_sample;
 % Symmetric backend warm-up outside solver timing and budgets.
 tmp=P(P(initial,z),-z); sync(gpu); clear tmp;
 cfg.warmup_propagations=2; writejson(fullfile(out,'config.json'),cfg);
 zero=score(initial,mask,amplitude,P,z); zero.method='ZERO'; zero.iteration=0;
 zero.solver_propagations=0; zero.evaluation_propagations=2; zero.solver_seconds=0;
 records=zero;
 writejson(fullfile(out,'metrics.json'),records);
 author=load(fullfile(cal,'sample.mat'),'U_sample40');
 hioField=[]; compare=struct; snapshots=struct;
 for m=1:numel(cfg.methods)
  method=cfg.methods{m}; u=initial; solveSec=0; evalCount=0;
  for it=1:cfg.iterations
   assert(toc(tAll)<cfg.max_wall_seconds,'FAST:TimeCap','Pilot wall-clock soft cap reached');
   sync(gpu); t=tic;
   detector=P(u,z);
   candidate=P(fast_project_amplitude(detector,amplitude),-z);
   u=fast_support_step(u,candidate,mask,method,cfg.beta);
   sync(gpu); solveSec=solveSec+toc(t);
   clear detector candidate;
   if ismember(it,cfg.checkpoints)
    assert(all(isfinite(host(u(:)))),'FAST:Nonfinite','Nonfinite solver output');
    row=score(u,mask,amplitude,P,z); evalCount=evalCount+2;
    row.method=method; row.iteration=it; row.solver_propagations=2*it;
    row.evaluation_propagations=evalCount; row.solver_seconds=solveSec;
    records(end+1)=row; %#ok<AGROW>
    % Every checkpoint is recoverable even if the run is interrupted.
    internal_state=host(u); physical_output=host(mask.*u); %#ok<NASGU>
    completed_iteration=it; %#ok<NASGU>
    save(fullfile(out,sprintf('%s_iter%03d.mat',method,it)), ...
      'internal_state','physical_output','completed_iteration','cfg','-v7.3');
    writejson(fullfile(out,'metrics.json'),records);
    writejson(fullfile(out,'status.json'),struct('state','running','stage',method, ...
      'completed_iterations',it,'total_iterations',cfg.iterations,'elapsed_seconds',toc(tAll)));
    fprintf('%s %d/40: physical residual %.6g, internal residual %.6g, solver %.2fs\n', ...
      method,it,row.physical_amplitude_nrmse,row.internal_amplitude_nrmse,solveSec);
   end
  end
  field=host(mask.*u);
  snapshots.(method)=field;
  if strcmp(method,'HIO')
   delta=host(u)-author.U_sample40;
   compare.hio_vs_author_internal_relative_error=norm(delta(:))/norm(author.U_sample40(:));
   compare.hio_author_tolerance=1e-7;
   writejson(fullfile(out,'equivalence.json'),compare);
   assert(compare.hio_vs_author_internal_relative_error<compare.hio_author_tolerance, ...
     'FAST:Equivalence','HIO does not match saved author sample; stop before comparison interpretation');
   hioField=field;
  else
   [compare.hio_er_field_difference,compare.hio_er_phase_difference_rad]= ...
      fast_field_error(field,hioField,logical(ref.mask));
   compare.difference_is_not_accuracy=true;
  end
  clear u internal_state physical_output field delta;
 end
 writejson(fullfile(out,'equivalence.json'),compare);
 save(fullfile(out,'summary.mat'),'records','compare','cfg','tests','-v7.3');
 % Shared phase scale; no filtering, offset, phase unwrapping or imagewise normalization.
 fig=figure('Visible','off'); fg=onCleanup(@()close(fig)); %#ok<NASGU>
 fields={host(initial),snapshots.HIO,snapshots.ER}; names={'ZERO','HIO','ER'};
 for j=1:3
  phi=angle(fields{j}.*exp(-1i*phaseRef)); phi(~logical(ref.mask))=NaN;
  subplot(1,3,j); imagesc(phi,[-pi pi]); axis image off; colorbar; title(names{j});
 end
 colormap(fig,parula); exportgraphics(fig,fullfile(out,'phase_comparison.png'),'Resolution',150);
 fid=fopen(fullfile(out,'REPORT.md'),'w','n','UTF-8'); assert(fid>=0);
 fprintf(fid,'# FAST/HIO vs ER: first fair pilot\n\nRun: %s. Common calibration: %s.\n\n',id,cfg.calibration_id);
 fprintf(fid,'Both methods: 40 iterations / 80 solver propagations; 8 additional scoring propagations each. ZERO: 0 solver / 2 scoring. Shared warm-up: 2. Unit-test propagations are separate setup cost, not solver work.\n\n');
 fprintf(fid,'|Method|Iteration|Solver calls|Score calls|Solver seconds|Physical amplitude NRMSE|Internal amplitude NRMSE|\n|---|---:|---:|---:|---:|---:|---:|\n');
 for j=1:numel(records)
  r=records(j); fprintf(fid,'|%s|%d|%d|%d|%.4f|%.8f|%.8f|\n',r.method,r.iteration,r.solver_propagations,r.evaluation_propagations,r.solver_seconds,r.physical_amplitude_nrmse,r.internal_amplitude_nrmse);
 end
 fprintf(fid,'\nNo independent phase truth: residuals and HIO/ER disagreement are NOT phase accuracy. One sample and one fixed timing order do not establish general superiority. No postprocessing. Physical output is support-projected for every method; HIO internal field is diagnostic only.\n\n');
 fprintf(fid,'Legacy prop.m frequency indexing is retained, including its shifted DC convention; see tests.json. Zero-field amplitude projection uses phase zero, separately versioned from original code.\n');
 fprintf(fid,'\nHIO/author internal relative difference: %.4g (tolerance %.4g).\n',compare.hio_vs_author_internal_relative_error,compare.hio_author_tolerance);
 fprintf(fid,'\nTotal elapsed including setup, scoring, IO and plotting: %.2f s. GPU peak memory not measured.\n',toc(tAll)); fclose(fid);
 writejson(fullfile(out,'status.json'),struct('state','completed','stop_reason','fixed_40_iterations_each', ...
  'elapsed_seconds',toc(tAll),'report','REPORT.md'));
 fprintf('FAIR_PILOT_COMPLETE: %s\n',out);
catch err
 writejson(fullfile(out,'failure.json'),struct('identifier',err.identifier,'message',err.message,'report',getReport(err,'extended','hyperlinks','off')));
 writejson(fullfile(out,'status.json'),struct('state','failed','elapsed_seconds',toc(tAll)));
 rethrow(err);
end
end
function r=score(u,mask,amplitude,P,z)
v=P(mask.*u,z); w=P(u,z);
den=norm(amplitude(:)); assert(host(den)>0);
r=struct('physical_amplitude_nrmse',host(norm(abs(v(:))-amplitude(:))/den), ...
 'internal_amplitude_nrmse',host(norm(abs(w(:))-amplitude(:))/den), ...
 'outside_energy_fraction',host(sum(abs((1-mask(:)).*u(:)).^2)/sum(abs(u(:)).^2)));
end
function x=host(x)
if isa(x,'gpuArray'), x=gather(x); end
end
function sync(gpu)
if ~isempty(gpu), wait(gpu); end
end
function writejson(p,value)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,jsonencode(value,'PrettyPrint',true),'char');
end
function h=sha256(p)
f=fopen(p,'rb'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f)
 b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8'));
end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
