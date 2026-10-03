function run_id=run_fast_mcf_pilot(resume_id,custom_cfg)
% Literature-informed known-truth core-resolved pilot; frozen old runs retained.
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path; pathGuard=onCleanup(@()path(oldpath)); %#ok<NASGU>
addpath(fullfile(root,'src','simulation'),fullfile(root,'src','solvers'), ...
 fullfile(root,'src','metrics'),fullfile(root,'tests'));
pilot=fullfile(root,'runs','pilot'); if ~isfolder(pilot), mkdir(pilot); end
lockpath=fullfile(pilot,'FAIR_COMPARE.lock'); lock=java.io.File(lockpath);
assert(lock.mkdir(),'FAST:Locked','Pilot lock exists; inspect active work before removing.');
lockGuard=onCleanup(@()rmdir(lockpath)); %#ok<NASGU>
resuming=nargin>0 && ~isempty(resume_id);
if resuming
 assert(~isempty(regexp(resume_id,'^mcf_[0-9_]+$','once')),'FAST:ResumeID','Invalid run ID');
 out=fullfile(pilot,resume_id); cfg=jsondecode(fileread(fullfile(out,'config.json')));
 status=jsondecode(fileread(fullfile(out,'status.json')));
 assert(strcmp(status.state,'failed'),'FAST:ResumeState','Resume requires a stopped failed run');
 truthdir=fullfile(root,'evaluation_only',cfg.run_id);
 validate_resume(root,out,truthdir,cfg);
 recovery=fullfile(out,['recovery_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]); mkdir(recovery);
 for name={'failure.json','status.json','provenance.json','tests.json','data_manifest.json'}
  source=fullfile(out,name{1}); if isfile(source), copyfile(source,fullfile(recovery,name{1})); end
 end
else
 if nargin>=2, cfg=custom_cfg; else, cfg=fast_mcf_config; end
 if ~isfield(cfg,'run_id'), cfg.run_id=['mcf_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]; end
 assert(~isfolder(fullfile(pilot,cfg.run_id)),'FAST:ExistingRun','Use resume for an existing run');
 out=fullfile(pilot,cfg.run_id); mkdir(out);
 truthdir=fullfile(root,'evaluation_only',cfg.run_id); mkdir(truthdir);
end
run_id=cfg.run_id;
diary(fullfile(out,'matlab.log')); diaryGuard=onCleanup(@()diary('off')); %#ok<NASGU>
tAll=tic;
try
 writejson(fullfile(out,'config.json'),cfg);
 writejson(fullfile(out,'status.json'),struct('state','running','stage','tests'));
 tests=test_fast_mcf; writejson(fullfile(out,'tests.json'),tests);
 assert(tests.passed,'FAST:Tests','MCF correctness checks failed');
 provenance=struct('matlab_version',version,'computer',computer,'sources',struct([]));
 sources={'tools/run_fast_mcf_pilot.m','tests/test_fast_mcf.m', ...
  'src/solvers/fast_project_amplitude.m','src/solvers/fast_support_step.m', ...
  'src/metrics/fast_field_error.m','src/solvers/fast_mcf_solve_case.m'};
 files=dir(fullfile(root,'src','simulation','fast_mcf_*.m'));
 for j=1:numel(files), sources{end+1}=['src/simulation/' files(j).name]; end %#ok<AGROW>
 for j=1:numel(sources)
  provenance.sources(j).path=sources{j}; provenance.sources(j).sha256=sha256(fullfile(root,sources{j}));
 end
 [gitStatus,gitCommit]=system(sprintf('git -C "%s" rev-parse HEAD',root));
 if gitStatus==0, provenance.git_commit=strtrim(gitCommit); else, provenance.git_commit='unavailable; source hashes authoritative'; end
 writejson(fullfile(out,'provenance.json'),provenance);
 writejson(fullfile(out,'status.json'),struct('state','running','stage','data_generation'));
 if resuming
  audit=jsondecode(fileread(fullfile(out,'generation_audit.json')));
  writejson(fullfile(recovery,'resume.json'),struct('run_id',cfg.run_id, ...
   'generation_reused',true,'previous_elapsed_seconds',status.elapsed_seconds, ...
   'wall_budget_scope','600 seconds per invocation; previous attempt archived'));
 else
  if isfield(cfg,'noise_scan')
   audit=fast_mcf_noise_generate(out,truthdir,cfg);
  elseif isfield(cfg,'layout')
   assert(strcmp(sha256(cfg.layout_bank),cfg.layout_bank_sha256),'FAST:GeometryHash','Geometry bank changed');
   audit=fast_mcf_layout_generate(out,truthdir,cfg);
  else
   audit=fast_mcf_generate(out,truthdir,cfg);
  end
  writejson(fullfile(out,'generation_audit.json'),audit);
 end
 H=fast_mcf_transfer(cfg.n,cfg.dx,cfg.lambda,cfg.z);
 records=struct([]); manifest=struct([]); count=0;
 for s=1:numel(cfg.scenes)
  scene=cfg.scenes{s}; truthPath=fullfile(truthdir,[scene '_truth.mat']);
  for c=1:numel(cfg.conditions)
   condition=cfg.conditions{c}; name=[scene '_' condition];
   inputPath=fullfile(out,[name '_input.mat']); d=load(inputPath);
   count=count+1; manifest(count).case=name; manifest(count).input_sha256=sha256(inputPath); %#ok<AGROW>
   manifest(count).truth_sha256=sha256(truthPath);
   writejson(fullfile(out,'data_manifest.json'),manifest);
   caseDir=fullfile(out,name); mkdir(caseDir); outputs=struct('ZERO',d.calibration);
   row=score(d.calibration,d,truthPath,H,scene,condition,'ZERO',0,0,0);
   records=append(records,row);
   % Truth residual quantifies fine-grid/pixel integration/model mismatch.
   t=load(truthPath,'truth');
   row=score(t.truth,d,truthPath,H,scene,condition,'TRUTH_DIAGNOSTIC',0,0,0);
   records=append(records,row); clear t
   for m=1:numel(cfg.methods)
    method=cfg.methods{m};
    % Solver function receives measurements/calibration only.
    receipts=fast_mcf_solve_case(d,H,cfg,method,caseDir,out,tAll,name);
    writejson(fullfile(caseDir,[method '_receipts.json']),receipts);
    for k=1:numel(receipts)
     receipt=receipts(k); u=load(receipt.path,'internal_state');
     row=score(u.internal_state,d,truthPath,H,scene,condition,method, ...
      receipt.iteration,receipt.seconds,2*receipt.iteration);
     row.scoring_propagations=k; records=append(records,row);
    end
    outputs.(method)=d.mask.*u.internal_state;
    writejson(fullfile(out,'metrics.json'),records);
   end
   plot_case(caseDir,outputs,d,truthPath,cfg,records,scene,condition);
   fprintf('MCF case %d/%d complete: %s\n',count,numel(cfg.scenes)*numel(cfg.conditions),name);
  end
 end
 writetable(struct2table(records),fullfile(out,'metrics.csv'));
 save(fullfile(out,'summary.mat'),'cfg','audit','tests','records','manifest');
 report(out,cfg,audit,records,toc(tAll));
 writejson(fullfile(out,'status.json'),struct('state','completed', ...
  'stop_reason','all_fixed_cases_final_iteration','elapsed_seconds',toc(tAll),'report','REPORT.md'));
 fprintf('MCF_PILOT_COMPLETE: %s\n',out);
catch err
 writejson(fullfile(out,'failure.json'),struct('identifier',err.identifier,'message',err.message, ...
  'report',getReport(err,'extended','hyperlinks','off')));
 writejson(fullfile(out,'status.json'),struct('state','failed','elapsed_seconds',toc(tAll)));
 rethrow(err);
end
end
function row=score(u,d,truthPath,H,scene,condition,method,it,seconds,calls)
t=load(truthPath,'truth','roi'); f=d.mask.*u; predicted=ifft2(fft2(f).*H);
[roiError,phaseError,theta]=fast_field_error(f,t.truth,t.roi);
fieldError=norm(f*exp(-1i*theta)-t.truth,'fro')/norm(t.truth,'fro');
invalid=mean(abs(f(t.roi))<=1e-12); if invalid>0, phaseError=NaN; end
row=struct('scene',scene,'condition',condition,'method',method,'iteration',it, ...
 'solver_propagations',calls,'scoring_propagations',1,'solver_seconds',seconds, ...
 'amplitude_nrmse',norm(abs(predicted)-d.amplitude,'fro')/norm(d.amplitude,'fro'), ...
 'field_nrmse',fieldError,'bright_core_field_nrmse',roiError,'phase_rmse_rad',phaseError, ...
 'phase_alignment_rad',theta,'phase_invalid_fraction',invalid, ...
 'outside_support_energy_fraction',sum(abs(u(d.mask==0)).^2)/sum(abs(u(:)).^2));
end
function plot_case(out,outputs,d,truthPath,cfg,records,scene,condition)
t=load(truthPath,'truth','roi'); f=figure('Visible','off'); guard=onCleanup(@()close(f)); %#ok<NASGU>
x=((0:cfg.n-1)-(cfg.n-1)/2)*cfg.dx*1e6;
fields={t.truth,outputs.ZERO,outputs.HIO,outputs.ER}; labels={'TRUTH','ZERO','HIO','ER'};
for j=1:4
 u=fields{j}; [~,~,theta]=fast_field_error(u,t.truth,t.roi);
 corrected=angle(u.*conj(d.calibration)*exp(-1i*theta)); corrected(~t.roi)=NaN;
 subplot(2,4,j); imagesc(x,x,abs(u)); axis image; colorbar; title([labels{j} ' amplitude']);
 subplot(2,4,j+4); imagesc(x,x,corrected,[-1 1]); axis image; colorbar; title([labels{j} ' corrected phase']);
end
sgtitle([scene ' / ' condition ' (coordinates: um; phase: rad)']);
set(f,'Position',[50 50 1500 750]); exportgraphics(f,fullfile(out,'field_comparison.png'),'Resolution',150);
f2=figure('Visible','off'); guard2=onCleanup(@()close(f2)); %#ok<NASGU>
metrics={'amplitude_nrmse','field_nrmse','phase_rmse_rad'};
for j=1:3
 subplot(1,3,j); hold on
 for m=1:numel(cfg.methods)
  rows=records(strcmp({records.scene},scene)&strcmp({records.condition},condition)&strcmp({records.method},cfg.methods{m}));
  plot([rows.iteration],[rows.(metrics{j})],'-o','DisplayName',cfg.methods{m});
 end
 xlabel('Iteration'); title(strrep(metrics{j},'_',' ')); legend('Location','best'); grid on
end
set(f2,'Position',[50 50 1200 360]); exportgraphics(f2,fullfile(out,'metric_curves.png'),'Resolution',150);
end
function report(out,cfg,audit,records,elapsed)
f=fopen(fullfile(out,'REPORT.md'),'w','n','UTF-8'); assert(f>=0); guard=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'# Core-resolved MCF pilot\n\nRun: %s\n\n',cfg.run_id);
if isfield(cfg,'layout')
 fprintf(f,'Layout: %s; seed: %d; common reference power %.6g, reference photoelectrons %.6g.\n\n',cfg.layout,cfg.seed,cfg.reference_power,cfg.reference_photons);
end
fprintf(f,'## Model\n\n%d illuminated cores; nominal hex pitch 3.2 um (layout geometry recorded separately); assumed mode radius 0.9 um with 10%% variation. Per-core phase and gain fixed across reference/sample. Scalar diagonal transmission, sample at input facet.\n\n',audit.core_count);
fprintf(f,'Reconstruction: 256x256, 0.5 um object-space samples. Generation: 512x512, 0.25 um samples, 2x2 intensity integration. Wavelength 532 nm, detector z=120 um. Standard angular-spectrum operator in an explicitly separate benchmark.\n\n');
fprintf(f,'Known synthetic reference calibration common to both solvers. Two reference intensity planes are saved for a future estimated-calibration test. Camera conditions in config.json; Poisson shot noise and read-noise sigma %.6g electrons, exposure defined in config.json.\n\n',cfg.read_noise_electrons);
fprintf(f,'## Sampling audit\n\n2x versus 4x reference-amplitude NRMSE: %.6g. Maximum detector edge-energy fraction: %.6g.\n\n',audit.oversample_2_vs_4_amplitude_nrmse,max(audit.detector_edge_energy_fraction));
fprintf(f,'## Results at fixed final iteration\n\n|Scene|Condition|Method|Iteration|Amplitude NRMSE|Full-field NRMSE|Core phase RMSE rad|Solver s|\n|---|---|---|---:|---:|---:|---:|---:|\n');
for j=1:numel(records)
 r=records(j);
 if r.iteration==0 || r.iteration==cfg.iterations
  fprintf(f,'|%s|%s|%s|%d|%.6g|%.6g|%.6g|%.4f|\n',r.scene,r.condition,r.method,r.iteration,r.amplitude_nrmse,r.field_nrmse,r.phase_rmse_rad,r.solver_seconds);
 end
end
fprintf(f,'\nEach method/case: 40 iterations, 80 solver propagations, 4 scoring propagations. ZERO and TRUTH_DIAGNOSTIC each require one scoring propagation. Generation audit records its propagation count; unit tests have separate setup cost. One fixed fiber realization.\n\n');
fprintf(f,'Measurement residual compares predicted detector amplitude with square-root measured pixel intensity. Full-field error covers the complete field; phase error uses a fixed bright-core ROI. A single global phase is aligned for scoring. TRUTH_DIAGNOSTIC measures the residual caused by fine/coarse sampling, pixel integration and noise.\n\n');
fprintf(f,'## Figures\n\n![Generated MCF fields](MCF_model.png)\n\n');
for s=1:numel(cfg.scenes)
 for c=1:numel(cfg.conditions)
  name=[cfg.scenes{s} '_' cfg.conditions{c}];
  fprintf(f,'### %s\n\n![Fields](%s/field_comparison.png)\n\n![Metrics](%s/metric_curves.png)\n\n',name,name,name);
 end
end
fprintf(f,'## Next physical refinements\n\nFit core geometry/mode widths to the public reference amplitude; add the documented imaging pupil and coordinate transform; evaluate estimated reference calibration, coupling and polarization drift.\n\n');
fprintf(f,'Wall-clock including generation, tests, plots, scoring and IO: %.2f s. CPU double; 600 s soft cap; fixed array dimensions, peak memory unmeasured.\n',elapsed);
end
function rows=append(rows,row)
if isempty(rows), rows=row; else, rows(end+1)=row; end
end
function writejson(p,value)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); guard=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,jsonencode(value,'PrettyPrint',true),'char');
end
function h=sha256(p)
f=fopen(p,'rb'); assert(f>=0); guard=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end

function validate_resume(root,out,truthdir,cfg)
% Ensure preserved numerical sources and recorded inputs still match the run.
if isfield(cfg,'layout')
 assert(strcmp(sha256(cfg.layout_bank),cfg.layout_bank_sha256),'FAST:GeometryHash','Geometry bank changed');
end
p=jsondecode(fileread(fullfile(out,'provenance.json')));
repairable={'tools/run_fast_mcf_pilot.m','tests/test_fast_mcf.m'};
for j=1:numel(p.sources)
 if ~ismember(p.sources(j).path,repairable)
  assert(strcmp(sha256(fullfile(root,p.sources(j).path)),p.sources(j).sha256), ...
   'FAST:ResumeSource','Numerical source changed: %s',p.sources(j).path);
 end
end
m=jsondecode(fileread(fullfile(out,'data_manifest.json')));
for j=1:numel(m)
 parts=strsplit(m(j).case,'_');
 assert(strcmp(sha256(fullfile(out,[m(j).case '_input.mat'])),m(j).input_sha256));
 assert(strcmp(sha256(fullfile(truthdir,[parts{1} '_truth.mat'])),m(j).truth_sha256));
end
for s=1:numel(cfg.scenes)
 assert(isfile(fullfile(truthdir,[cfg.scenes{s} '_truth.mat'])));
 for c=1:numel(cfg.conditions)
  assert(isfile(fullfile(out,[cfg.scenes{s} '_' cfg.conditions{c} '_input.mat'])));
 end
end
assert(isfile(fullfile(out,'generation_audit.json')));
end
