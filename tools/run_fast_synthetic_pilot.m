function run_fast_synthetic_pilot
% Same-model software validation only, not a physical MCF benchmark.
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path; pathGuard=onCleanup(@()path(oldpath)); %#ok<NASGU>
addpath(fullfile(root,'legacy_fast'),fullfile(root,'src','solvers'), ...
 fullfile(root,'src','metrics'),fullfile(root,'tests'));
% Use same lock as the real-data pilot; never start simultaneous pilot runs.
lockpath=fullfile(root,'runs','pilot','FAIR_COMPARE.lock');
lock=java.io.File(lockpath);
assert(lock.mkdir(),'FAST:Locked','Pilot lock exists; inspect active work, do not blindly delete it.');
lockGuard=onCleanup(@()rmdir(lockpath)); %#ok<NASGU>
id=['synthetic_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
out=fullfile(root,'runs','pilot',id); mkdir(out);
truthdir=fullfile(root,'evaluation_only',id); mkdir(truthdir);
diary(fullfile(out,'matlab.log')); diaryGuard=onCleanup(@()diary('off')); %#ok<NASGU>
tAll=tic;
try
 cfg=struct('run_id',id,'version','synthetic-software-pilot-v1', ...
  'scope','same-grid same-model noiseless software validation, NOT physical MCF simulation', ...
  'grid',[128 128],'dp',2.2e-6,'lambda',532e-9,'z',0.0788,'seed',20261002, ...
  'beta',0.2,'iterations',40,'checkpoints',[10 20 30 40],'backend','CPU', ...
  'precision','double','max_wall_seconds',300,'methods',{{'HIO','ER'}}, ...
  'scenes',{{'blank','step','smooth','mixed'}},'noise','none', ...
  'calibration','known analytic synthetic phase; NOT an estimated or experimental calibration', ...
  'geometry','generic circular support, NOT measured MCF core geometry', ...
  'initialization','unit amplitude on support with common synthetic reference phase', ...
  'postprocessing','none','output','support-projected physical field', ...
  'phase_alignment','one global phase using reference, scoring only; no fitted gain/tilt/shift', ...
  'invalid_phase_rule','fixed reference ROI; NaN phase RMSE if any reconstructed ROI amplitude <=1e-12', ...
  'truth_access','separate evaluation_only files, never added to MATLAB path; not OS-enforced isolation', ...
  'parameter_selection','fixed before evaluation; no tuning or best-checkpoint selection', ...
  'memory_limit','small fixed 128x128 CPU arrays; no OS-enforced memory cap', ...
  'timing','single ordered trial, excludes scoring/IO; not a robust timing ranking');
 writejson(fullfile(out,'config.json'),cfg);
 writejson(fullfile(out,'status.json'),struct('state','running','stage','tests'));
 tests=test_fast_fair(); writejson(fullfile(out,'tests.json'),tests);
 assert(tests.passed,'FAST:Tests','Correctness tests failed');
 rng(cfg.seed,'twister');
 sources={'tools/run_fast_synthetic_pilot.m','tests/test_fast_fair.m', ...
  'src/solvers/fast_project_amplitude.m','src/solvers/fast_support_step.m', ...
  'src/metrics/fast_field_error.m','legacy_fast/prop.m'};
 provenance=struct('matlab_version',version,'computer',computer);
 provenance.sources=struct('path',{},'sha256',{});
 for k=1:numel(sources)
  provenance.sources(k).path=sources{k}; provenance.sources(k).sha256=sha256(fullfile(root,sources{k}));
 end
 writejson(fullfile(out,'provenance.json'),provenance);
 % Data creation happens separately; solvers receive no truth argument.
 generate_inputs(out,truthdir,cfg);
 records=struct([]); pairs=struct([]); manifest=struct([]);
 for s=1:numel(cfg.scenes)
  name=cfg.scenes{s}; caseDir=fullfile(out,name); mkdir(caseDir);
  inputPath=fullfile(out,[name '_input.mat']); truthPath=fullfile(truthdir,[name '_truth.mat']);
  manifest(s).scene=name; manifest(s).input_sha256=sha256(inputPath); %#ok<AGROW>
  manifest(s).truth_sha256=sha256(truthPath);
  writejson(fullfile(out,'data_manifest.json'),manifest);
  d=load(inputPath); P=@(u,z)prop(u,cfg.dp,cfg.dp,cfg.lambda,z);
  % No truth loaded during solver updates or stopping decisions.
  initial=d.mask.*exp(1i*d.phase_calibration);
  outputs=struct; outputs.ZERO=initial;
  row=score(initial,d,truthPath,P,cfg,name,'ZERO',0,0,0,1);
  records=append(records,row);
  for m=1:numel(cfg.methods)
   method=cfg.methods{m}; u=initial; seconds=0; evalCalls=0;
   for it=1:cfg.iterations
    assert(toc(tAll)<cfg.max_wall_seconds,'FAST:TimeCap','300s wall-clock soft cap reached');
    t=tic;
    detector=P(u,cfg.z);
    v=P(fast_project_amplitude(detector,d.amplitude),-cfg.z);
    u=fast_support_step(u,v,d.mask,method,cfg.beta);
    seconds=seconds+toc(t);
    assert(all(isfinite(u(:))),'FAST:Nonfinite','Nonfinite solver state');
    if ismember(it,cfg.checkpoints)
     evalCalls=evalCalls+1;
     row=score(u,d,truthPath,P,cfg,name,method,it,seconds,2*it,evalCalls);
     records=append(records,row);
     internal_state=u; physical_output=d.mask.*u; completed_iteration=it; %#ok<NASGU>
     save(fullfile(caseDir,sprintf('%s_iter%03d.mat',method,it)), ...
      'internal_state','physical_output','completed_iteration','cfg');
     writejson(fullfile(out,'metrics.json'),records);
     writejson(fullfile(out,'status.json'),struct('state','running','stage',name, ...
      'method',method,'completed_iterations',it,'elapsed_seconds',toc(tAll)));
    end
   end
   outputs.(method)=d.mask.*u;
  end
  pairs(s).scene=name; %#ok<AGROW>
  pairs(s).scope='diagnostic final-iteration ordering, not statistical superiority';
  hi=records(strcmp({records.scene},name)&strcmp({records.method},'HIO')&[records.iteration]==40);
  er=records(strcmp({records.scene},name)&strcmp({records.method},'ER')&[records.iteration]==40);
  pairs(s).residual_order=order(hi.amplitude_nrmse,er.amplitude_nrmse);
  pairs(s).field_error_order=order(hi.field_nrmse,er.field_nrmse);
  pairs(s).phase_error_order=order(hi.phase_rmse_rad,er.phase_rmse_rad);
  pairs(s).residual_vs_field_order_disagrees=~strcmp(pairs(s).residual_order,'tie') && ...
    ~strcmp(pairs(s).field_error_order,'tie') && ~strcmp(pairs(s).residual_order,pairs(s).field_error_order);
  plot_case(caseDir,outputs,d,truthPath,name);
  fprintf('Completed synthetic scene %s (%d/4)\n',name,s);
 end
 writejson(fullfile(out,'data_manifest.json'),manifest);
 writejson(fullfile(out,'ordering_diagnostics.json'),pairs);
 writetable(struct2table(records),fullfile(out,'metrics.csv'));
 save(fullfile(out,'summary.mat'),'records','pairs','cfg','tests');
 report(out,records,pairs,cfg,toc(tAll));
 writejson(fullfile(out,'status.json'),struct('state','completed','stop_reason','four_fixed_scenes_40_iterations_each', ...
  'elapsed_seconds',toc(tAll),'report','REPORT.md'));
 fprintf('SYNTHETIC_PILOT_COMPLETE: %s\n',out);
catch err
 writejson(fullfile(out,'failure.json'),struct('identifier',err.identifier,'message',err.message,'report',getReport(err,'extended','hyperlinks','off')));
 writejson(fullfile(out,'status.json'),struct('state','failed','elapsed_seconds',toc(tAll)));
 rethrow(err);
end
end
function generate_inputs(out,truthdir,cfg)
n=cfg.grid(1); [x,y]=meshgrid(linspace(-1,1,n));
mask=double(x.^2+y.^2<=0.65^2);
phase_calibration=0.6*sin(2*pi*x)+0.4*cos(2*pi*y)+0.2*x.*y;
for k=1:numel(cfg.scenes)
 name=cfg.scenes{k}; a=ones(n);
 switch name
  case 'blank'
   phi=zeros(n);
  case 'step'
   phi=0.8*double(x>0);
  case 'smooth'
   phi=0.8*exp(-((x+0.15).^2+(y-0.1).^2)/0.12);
  case 'mixed'
   phi=0.55*sin(3*pi*x).*cos(2*pi*y);
   a=0.55+0.45*exp(-(x.^2+y.^2)/0.20);
 end
 truth=mask.*a.*exp(1i*(phase_calibration+phi));
 roi=logical(mask); % Fixed from known support; all reference amplitudes >0.5.
 amplitude=abs(prop(truth,cfg.dp,cfg.dp,cfg.lambda,cfg.z));
 save(fullfile(out,[name '_input.mat']),'amplitude','mask','phase_calibration');
 save(fullfile(truthdir,[name '_truth.mat']),'truth','roi','phi','a');
end
end
function row=score(u,d,truthPath,P,cfg,scene,method,it,seconds,calls,evalCalls)
t=load(truthPath,'truth','roi'); f=d.mask.*u;
predicted=P(f,cfg.z);
residual=norm(abs(predicted(:))-d.amplitude(:))/norm(d.amplitude(:));
[nrmse,phaseRmse,theta]=fast_field_error(f,t.truth,t.roi);
invalid=mean(abs(f(t.roi))<=1e-12);
if invalid>0, phaseRmse=NaN; end
row=struct('scene',scene,'method',method,'iteration',it,'solver_propagations',calls, ...
 'scoring_propagations',evalCalls,'solver_seconds',seconds,'amplitude_nrmse',residual, ...
 'field_nrmse',nrmse,'phase_rmse_rad',phaseRmse,'phase_alignment_rad',theta, ...
 'phase_invalid_fraction',invalid,'outside_energy_fraction',sum(abs(u(~t.roi)).^2)/sum(abs(u(:)).^2));
end
function rows=append(rows,row)
if isempty(rows), rows=row; else, rows(end+1)=row; end
end
function result=order(hio,er)
if ~isfinite(hio) || ~isfinite(er), result='unavailable';
elseif abs(hio-er)<1e-10, result='tie';
elseif hio<er, result='HIO_lower';
else, result='ER_lower'; end
end
function plot_case(out,outputs,d,truthPath,name)
t=load(truthPath,'truth','roi'); f=figure('Visible','off'); c=onCleanup(@()close(f)); %#ok<NASGU>
fields={t.truth,outputs.ZERO,outputs.HIO,outputs.ER}; names={'TRUTH','ZERO','HIO','ER'};
for k=1:4
 u=fields{k}; [~,~,theta]=fast_field_error(u,t.truth,t.roi);
 phi=angle(u.*exp(-1i*(d.phase_calibration+theta))); phi(~t.roi)=NaN;
 subplot(1,4,k); imagesc(phi,[-pi pi]); axis image off; colorbar; title([name ' ' names{k}]);
end
set(f,'Position',[100 100 1400 360]); colormap(f,parula);
exportgraphics(f,fullfile(out,'phase_comparison.png'),'Resolution',150);
end
function report(out,records,pairs,cfg,elapsed)
f=fopen(fullfile(out,'REPORT.md'),'w','n','UTF-8'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'# Synthetic software-validation pilot\n\nRun: %s\n\n',cfg.run_id);
fprintf(f,'128x128 CPU double, 4 fixed analytic scenes, noiseless, known synthetic calibration, generic support. Generation and reconstruction use SAME legacy discrete operator. This is an inverse-crime software test, NOT evidence of physical MCF performance.\n\n');
fprintf(f,'Each method/scene: 40 iterations, 80 solver propagations, 4 scoring propagations. ZERO: 0 solver/1 scoring. Data generation: 1 propagation/scene. Small unit-test calls are setup costs. No truth-driven tuning/stopping/selection. Final iteration is reported, not best checkpoint.\n\n');
fprintf(f,'|Scene|Method|Iteration|Amplitude residual|Field NRMSE|Phase RMSE rad|Solver s|\n|---|---|---:|---:|---:|---:|---:|\n');
for k=1:numel(records)
 r=records(k);
 if r.iteration==0 || r.iteration==40
  fprintf(f,'|%s|%s|%d|%.6g|%.6g|%.6g|%.4f|\n',r.scene,r.method,r.iteration,r.amplitude_nrmse,r.field_nrmse,r.phase_rmse_rad,r.solver_seconds);
 end
end
fprintf(f,'\n## Interpretation\n\nOnly a single global phase is removed for scoring. No fitted amplitude, tilt, shift, filtering or unwrapping. ROI is fixed by the reference, not reconstruction. Invalid reconstructed phases are flagged and yield NaN rather than silently shrinking ROI.\n\n');
for k=1:numel(pairs)
 p=pairs(k); fprintf(f,'- %s: residual %s; field error %s; phase error %s.\n',p.scene,p.residual_order,p.field_error_order,p.phase_error_order);
end
fprintf(f,'\nAny difference in ordering is descriptive, not statistical. If no ordering inversion occurs, do not claim this run demonstrated one. Single toy cases cannot establish general superiority. Legacy shifted frequency-grid convention is retained. Formal simulation requires finer-grid data generation, pixel integration and independently chosen noise/model mismatch before reconstruction.\n');
fprintf(f,'\nWall-clock including IO/tests/scoring: %.2f s. CPU memory peak not measured.\n',elapsed);
end
function writejson(p,value)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,jsonencode(value,'PrettyPrint',true),'char');
end
function h=sha256(p)
f=fopen(p,'rb'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
