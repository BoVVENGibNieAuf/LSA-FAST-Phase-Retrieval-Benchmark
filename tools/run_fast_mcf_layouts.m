function run_fast_mcf_layouts(action)
% Sequential 3-layout x 3-phase-seed suite; re-invocation resumes unfinished cases.
if nargin<1, action='continue'; end
assert(ismember(action,{'continue','new'}));
root=fileparts(fileparts(mfilename('fullpath')));
old=path; guard=onCleanup(@()path(old)); %#ok<NASGU>
addpath(fullfile(root,'src','simulation'),fullfile(root,'src','solvers'), ...
 fullfile(root,'src','metrics'),fullfile(root,'tests'),fullfile(root,'tools'));
pilot=fullfile(root,'runs','pilot'); if ~isfolder(pilot), mkdir(pilot); end
lockpath=fullfile(pilot,'MCF_LAYOUTS.lock'); lock=java.io.File(lockpath);
assert(lock.mkdir(),'FAST:LayoutLocked','Layout batch already active; inspect a stale lock before removal');
lockGuard=onCleanup(@()rmdir(lockpath)); %#ok<NASGU>
assert(~isfolder(fullfile(pilot,'FAIR_COMPARE.lock')),'FAST:PilotLocked','Another pilot is active');
existing=dir(fullfile(pilot,'layouts_*')); existing=existing([existing.isdir]);
if strcmp(action,'continue') && ~isempty(existing)
 [~,ix]=sort({existing.name}); batchid=existing(ix(end)).name;
else
 batchid=['layouts_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
end
out=fullfile(pilot,batchid); if ~isfolder(out), mkdir(out); end
statuspath=fullfile(out,'status.json');
if isfile(statuspath)
 previous=jsondecode(fileread(statuspath));
 if strcmp(previous.state,'completed')
  fprintf('Layout batch already completed: %s\nUse run_fast_mcf_layouts(''new'') for a new batch.\n',out); return;
 end
end
t=tic;
try
 files={'tools/run_fast_mcf_layouts.m','tools/run_fast_mcf_pilot.m', ...
  'src/simulation/fast_mcf_layout_bank.m','src/simulation/fast_mcf_layout_geometry.m', ...
  'src/simulation/fast_mcf_layout_generate.m','tests/test_fast_mcf_layouts.m'};
 provenance=struct([]);
 for j=1:numel(files)
  provenance(j).path=files{j}; provenance(j).sha256=filehash(fullfile(root,files{j}));
 end
 sourcepath=fullfile(out,'suite_sources.json');
 if isfile(sourcepath)
  previous_sources=jsondecode(fileread(sourcepath));
  assert(isequal({previous_sources.sha256},{provenance.sha256}), ...
   'FAST:SuiteSourceChanged','Suite code changed since preparation; inspect before resuming');
 else
  put(sourcepath,provenance);
 end
 put(statuspath,struct('state','running','stage','geometry','batch_id',batchid));
 raw=fullfile(root,'data','raw','data.mat'); bankpath=fullfile(out,'layout_bank.mat');
 if ~isfile(bankpath)
  bank=fast_mcf_layout_bank(raw,out); %#ok<NASGU>
  put(fullfile(out,'reference_source.json'),struct('path','data/raw/data.mat','sha256',filehash(raw), ...
   'scope','core locations from public amplitude; synthetic coordinate scale'));
 end
 tests=test_fast_mcf_layouts(bankpath); put(fullfile(out,'layout_tests.json'),tests);
 assert(tests.passed,'FAST:LayoutTests','Layout pairing test failed');
 planpath=fullfile(out,'plan.json');
 if ~isfile(planpath)
  labels={'hex','jitter','measured'}; seeds=[20261003 20261004 20261005]; plans=struct([]); k=0;
  bankhash=filehash(bankpath);
  for s=1:numel(seeds)
   for j=1:numel(labels)
    k=k+1; cfg=fast_mcf_config;
    cfg.version='mcf-layout-suite-v2'; cfg.layout=labels{j}; cfg.seed=seeds(s);
    cfg.noise_seed=3102026+100*s; cfg.layout_bank=bankpath; cfg.layout_bank_sha256=bankhash;
    cfg.reference_power=1e-9; cfg.reference_photons=200000;
    cfg.geometry='127 cores; matched 19.2um outer core radius; shared mode/gain/phase draws';
    cfg.camera='fixed total reference photons across layouts; fixed exposure across scenes';
    cfg.run_id=sprintf('mcf_%s_%02d',batchid(9:end),k);
    plans(k).cfg=cfg; %#ok<AGROW>
   end
  end
  put(planpath,plans);
 end
 plans=jsondecode(fileread(planpath)); done=0;
 for k=1:numel(plans)
  assert(toc(t)<1800,'FAST:BatchTime','1800-second between-case soft cap reached; rerun to continue');
  cfg=plans(k).cfg; runpath=fullfile(pilot,cfg.run_id); state=fullfile(runpath,'status.json');
  assert(strcmp(filehash(bankpath),cfg.layout_bank_sha256),'FAST:LayoutHash','Saved geometry changed');
  if isfile(state)
   st=jsondecode(fileread(state));
   if strcmp(st.state,'completed')
    fprintf('Reusing completed run %s\n',cfg.run_id);
   elseif strcmp(st.state,'failed')
    run_fast_mcf_pilot(cfg.run_id);
   else
    error('FAST:UnknownRun','Inspect unfinished run %s before continuing',cfg.run_id);
   end
  else
   run_fast_mcf_pilot('',cfg);
  end
  done=done+1;
  put(statuspath,struct('state','running','batch_id',batchid,'completed_runs',done, ...
   'total_runs',numel(plans),'elapsed_seconds',toc(t)));
 end
 aggregate(root,out,plans);
 put(statuspath,struct('state','completed','batch_id',batchid,'completed_runs',done, ...
  'total_runs',numel(plans),'elapsed_seconds',toc(t),'report','LAYOUT_REPORT.md'));
 fprintf('MCF_LAYOUTS_COMPLETE: %s\n',out);
catch err
 p=fullfile(out,['failure_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.json']);
 put(p,struct('identifier',err.identifier,'message',err.message,'report',getReport(err,'extended','hyperlinks','off')));
 put(statuspath,struct('state','failed','batch_id',batchid,'elapsed_seconds',toc(t),'failure',p));
 rethrow(err);
end
end
function aggregate(root,out,plans)
rows=struct([]); audits=struct([]);
for k=1:numel(plans)
 cfg=plans(k).cfg; p=fullfile(root,'runs','pilot',cfg.run_id);
 r=jsondecode(fileread(fullfile(p,'metrics.json')));
 a=jsondecode(fileread(fullfile(p,'generation_audit.json')));
 assert(abs(a.reference_power/cfg.reference_power-1)<1e-10);
 assert(abs(a.reference_photons/cfg.reference_photons-1)<1e-10);
 audits(k).run_id=cfg.run_id; audits(k).audit=a; %#ok<AGROW>
 for j=1:numel(r)
  row=r(j); if isempty(row.phase_rmse_rad), row.phase_rmse_rad=NaN; end
  row.layout=cfg.layout; row.seed=cfg.seed; row.run_id=cfg.run_id;
  if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
 end
end
put(fullfile(out,'all_metrics.json'),rows); writetable(struct2table(rows),fullfile(out,'all_metrics.csv'));
put(fullfile(out,'power_and_sampling_audits.json'),audits);
stats=struct([]); labels={'hex','jitter','measured'};
for l=1:3
 for scene={'blank','step','smooth','mixed'}
  for condition={'clean','shot_read'}
   for method={'HIO','ER'}
    ix=strcmp({rows.layout},labels{l}) & strcmp({rows.scene},scene{1}) & ...
     strcmp({rows.condition},condition{1}) & strcmp({rows.method},method{1}) & [rows.iteration]==40;
    r=rows(ix); assert(numel(r)==3,'FAST:MissingSeed','Expected all 3 paired seeds');
    s=struct('layout',labels{l},'scene',scene{1},'condition',condition{1},'method',method{1}, ...
     'seeds',3,'amplitude_mean',mean([r.amplitude_nrmse]),'amplitude_std',std([r.amplitude_nrmse]), ...
     'field_mean',mean([r.field_nrmse]),'field_std',std([r.field_nrmse]), ...
     'phase_mean',mean([r.phase_rmse_rad]),'phase_std',std([r.phase_rmse_rad]), ...
     'invalid_phase_fraction_max',max([r.phase_invalid_fraction]));
    if isempty(stats), stats=s; else, stats(end+1)=s; end %#ok<AGROW>
   end
  end
 end
end
put(fullfile(out,'summary.json'),stats); writetable(struct2table(stats),fullfile(out,'summary.csv'));
f=fopen(fullfile(out,'LAYOUT_REPORT.md'),'w','n','UTF-8'); assert(f>=0); cleanup=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'# MCF layout comparison\n\nThree layouts, 127 cores each, three paired phase/gain/width seeds. Four samples, two camera conditions, HIO/ER 40 iterations each. Reference power and total photons matched.\n\n');
fprintf(f,'![Core detection audit](core_detection_overlay.png)\n\n![Layouts](layout_comparison.png)\n\n');
fprintf(f,'|Layout|Scene|Noise|Method|Amplitude mean +/- SD|Field mean +/- SD|Phase rad mean +/- SD|\n|---|---|---|---|---:|---:|---:|\n');
for j=1:numel(stats)
 s=stats(j); fprintf(f,'|%s|%s|%s|%s|%.5g +/- %.3g|%.5g +/- %.3g|%.5g +/- %.3g|\n', ...
 s.layout,s.scene,s.condition,s.method,s.amplitude_mean,s.amplitude_std,s.field_mean,s.field_std,s.phase_mean,s.phase_std);
end
fprintf(f,'\n## Individual runs\n\n');
for k=1:numel(plans)
 c=plans(k).cfg; fprintf(f,'- %s / seed %d: [%s](../%s/REPORT.md)\n',c.layout,c.seed,c.run_id,c.run_id);
end
fprintf(f,'\nThe measured geometry preserves a detected public-image patch up to translation and uniform scale. Inspect the centroid overlay for missed/merged cores. The 3 seeds sample transmission parameters on fixed layouts; additional independently selected patches are needed to quantify geometry-to-geometry variability. Dispersion here is sample SD, not a confidence interval.\n');
end
function put(p,v)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,jsonencode(v,'PrettyPrint',true),'char');
end
function h=filehash(p)
f=fopen(p,'rb'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
