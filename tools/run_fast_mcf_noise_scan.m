function run_fast_mcf_noise_scan
% Three light levels, two read-noise levels, two layouts, three fixed seeds.
root=fileparts(fileparts(mfilename('fullpath'))); old=path;
pathGuard=onCleanup(@()path(old)); %#ok<NASGU>
addpath(fullfile(root,'src','simulation'),fullfile(root,'src','solvers'), ...
 fullfile(root,'src','metrics'),fullfile(root,'tests'),fullfile(root,'tools'));
pilot=fullfile(root,'runs','pilot'); lockpath=fullfile(pilot,'MCF_NOISE.lock');
lock=java.io.File(lockpath); assert(lock.mkdir(),'FAST:Locked','Noise scan lock exists; inspect before removal');
guard=onCleanup(@()rmdir(lockpath)); %#ok<NASGU>
assert(~isfolder(fullfile(pilot,'FAIR_COMPARE.lock')) && ~isfolder(fullfile(pilot,'MCF_LAYOUTS.lock')));
baseline=fullfile(pilot,'layouts_20261003_170247_158');
status=read(fullfile(baseline,'status.json')); assert(strcmp(status.state,'completed'));
existing=dir(fullfile(pilot,'noise_*')); existing=existing([existing.isdir]);
if isempty(existing), id=['noise_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))];
else, [~,ix]=sort({existing.name}); id=existing(ix(end)).name; end
out=fullfile(pilot,id); if ~isfolder(out), mkdir(out); end
statuspath=fullfile(out,'status.json');
if isfile(statuspath)
 status=read(statuspath); if strcmp(status.state,'completed'), fprintf('Already complete: %s\n',out); return; end
end
t=tic;
try
 sourceNames={'tools/run_fast_mcf_noise_scan.m','tools/run_fast_mcf_pilot.m', ...
  'src/simulation/fast_mcf_noise_camera.m','src/simulation/fast_mcf_noise_generate.m','tests/test_fast_mcf_noise.m'};
 hashes=cell(size(sourceNames));
 for j=1:numel(sourceNames), hashes{j}=digest(fullfile(root,sourceNames{j})); end
 sp=fullfile(out,'source_hashes.json');
 if isfile(sp), prev=read(sp); assert(isequal(prev(:),hashes(:)),'FAST:SourcesChanged','Inspect changed code before resuming');
 else, put(sp,hashes); put(fullfile(out,'source_paths.json'),sourceNames); end
 put(statuspath,struct('state','running','stage','camera_tests'));
 tests=test_fast_mcf_noise; put(fullfile(out,'camera_tests.json'),tests);
 assert(tests.passed,'FAST:NoiseTests','Poisson distribution/repeatability tests failed');
 planpath=fullfile(out,'plan.json');
 if ~isfile(planpath)
  base=read(fullfile(baseline,'plan.json')); plans=struct([]); k=0;
  for j=1:numel(base)
   original=base(j).cfg; if strcmp(original.layout,'jitter'), continue; end
   st=read(fullfile(pilot,original.run_id,'status.json')); assert(strcmp(st.state,'completed'));
   for photons=[200000 2000000 20000000]
    for sigma=[0 1]
     k=k+1; cfg=original; cfg.version='mcf-noise-scan-v1'; cfg.noise_scan=true;
     cfg.source_run_id=original.run_id; cfg.scenes={'mixed'}; cfg.conditions={'shot_read'};
     cfg.reference_photons=photons; cfg.read_noise_electrons=sigma;
     cfg.noise_seed=original.noise_seed+4; % Original mixed sample's camera seed.
     cfg.run_id=sprintf('mcf_%s_%02d',id(7:end),k);
     cfg.camera='Poisson product/PTRS, fixed reference-total photons, unchanged sqrt/clipping';
     cfg.parameter_selection='prespecified three photon levels x two read-noise levels; 40 iterations';
     plans(k).cfg=cfg; plans(k).reuse_baseline=(photons==200000 && sigma==1); %#ok<AGROW>
    end
   end
  end
  put(planpath,plans);
 end
 plans=read(planpath); complete=0;
 for k=1:numel(plans)
  assert(toc(t)<1800,'FAST:TimeCap','Noise scan between-case 1800s cap; relaunch to continue');
  cfg=plans(k).cfg;
  if plans(k).reuse_baseline
   fprintf('Reuse baseline %s\n',cfg.source_run_id);
  else
   p=fullfile(pilot,cfg.run_id,'status.json');
   if isfile(p)
    st=read(p);
    if strcmp(st.state,'failed'), run_fast_mcf_pilot(cfg.run_id);
    elseif ~strcmp(st.state,'completed'), error('FAST:UnknownState','Inspect run %s',cfg.run_id); end
   else
    run_fast_mcf_pilot('',cfg);
   end
  end
  complete=complete+1;
  put(statuspath,struct('state','running','completed_cases',complete,'total_cases',numel(plans),'elapsed_seconds',toc(t)));
 end
 summarize(pilot,out,plans);
 put(statuspath,struct('state','completed','completed_cases',complete,'total_cases',numel(plans), ...
  'new_cases',30,'reused_cases',6,'elapsed_seconds',toc(t),'report','NOISE_REPORT.md'));
 fprintf('MCF_NOISE_SCAN_COMPLETE: %s\n',out);
catch err
 p=fullfile(out,['failure_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')) '.json']);
 put(p,struct('identifier',err.identifier,'message',err.message,'report',getReport(err,'extended','hyperlinks','off')));
 put(statuspath,struct('state','failed','failure',p,'elapsed_seconds',toc(t))); rethrow(err);
end
end
function summarize(pilot,out,plans)
rows=struct([]); camera=struct([]);
for k=1:numel(plans)
 cfg=plans(k).cfg; runid=cfg.run_id;
 if plans(k).reuse_baseline, runid=cfg.source_run_id; end
 r=read(fullfile(pilot,runid,'metrics.json'));
 selected=strcmp({r.scene},'mixed') & strcmp({r.condition},'shot_read'); r=r(selected);
 for j=1:numel(r)
  row=r(j); if isempty(row.phase_rmse_rad), row.phase_rmse_rad=NaN; end
  row.layout=cfg.layout; row.seed=cfg.seed; row.photons=cfg.reference_photons;
  row.read_sigma=cfg.read_noise_electrons; row.run_id=runid; row.reused=plans(k).reuse_baseline;
  if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
 end
 camera(k).run_id=runid; camera(k).reused=plans(k).reuse_baseline; %#ok<AGROW>
 if ~plans(k).reuse_baseline, camera(k).audit=read(fullfile(pilot,runid,'camera_audit.json'));
 else, camera(k).audit=struct('sampler','original Poisson product baseline'); end
end
put(fullfile(out,'all_metrics.json'),rows); writetable(struct2table(rows),fullfile(out,'all_metrics.csv'));
put(fullfile(out,'camera_audits.json'),camera);
stats=struct([]);
for layout={'hex','measured'}
 for photons=[200000 2000000 20000000]
  for sigma=[0 1]
   for method={'HIO','ER'}
    ix=strcmp({rows.layout},layout{1}) & [rows.photons]==photons & [rows.read_sigma]==sigma & ...
     strcmp({rows.method},method{1}) & [rows.iteration]==40;
    r=rows(ix); assert(numel(r)==3);
    s=struct('layout',layout{1},'photons',photons,'read_sigma',sigma,'method',method{1}, ...
     'seeds',3,'phase_mean',mean([r.phase_rmse_rad]),'phase_std',std([r.phase_rmse_rad]), ...
     'field_mean',mean([r.field_nrmse]),'field_std',std([r.field_nrmse]), ...
     'amplitude_mean',mean([r.amplitude_nrmse]),'amplitude_std',std([r.amplitude_nrmse]), ...
     'invalid_phase_fraction_max',max([r.phase_invalid_fraction]));
    if isempty(stats), stats=s; else, stats(end+1)=s; end %#ok<AGROW>
   end
  end
 end
end
put(fullfile(out,'summary.json'),stats); writetable(struct2table(stats),fullfile(out,'summary.csv'));
f=figure('Visible','off'); guard=onCleanup(@()close(f)); %#ok<NASGU>
layouts={'hex','measured'};
for j=1:2
 for si=1:2
  subplot(2,2,2*(j-1)+si); hold on
  for method={'HIO','ER'}
   r=stats(strcmp({stats.layout},layouts{j}) & [stats.read_sigma]==si-1 & strcmp({stats.method},method{1}));
   errorbar([r.photons],[r.phase_mean],[r.phase_std],'-o','DisplayName',method{1});
  end
  set(gca,'XScale','log'); xlabel('Reference expected total photoelectrons'); ylabel('Phase RMSE (rad)');
  title(sprintf('%s / read sigma=%d e-',layouts{j},si-1)); legend('Location','best'); grid on
 end
end
set(f,'Position',[50 50 1100 800]); exportgraphics(f,fullfile(out,'noise_sensitivity.png'),'Resolution',150);
fid=fopen(fullfile(out,'NOISE_REPORT.md'),'w','n','UTF-8'); assert(fid>=0); closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'# MCF photon/read-noise scan\n\nFixed mixed sample, two layouts and three paired transmission seeds. 36 conditions: 30 new and six reused baseline conditions. Each method gets 40 iterations.\n\n![Sensitivity](noise_sensitivity.png)\n\n');
fprintf(fid,'|Layout|Reference photons|Read sigma e-|Method|Phase mean +/- SD rad|Field mean +/- SD|Amplitude mean|\n|---|---:|---:|---|---:|---:|---:|\n');
for j=1:numel(stats)
 s=stats(j); fprintf(fid,'|%s|%.0f|%.0f|%s|%.6g +/- %.3g|%.6g +/- %.3g|%.6g|\n', ...
 s.layout,s.photons,s.read_sigma,s.method,s.phase_mean,s.phase_std,s.field_mean,s.field_std,s.amplitude_mean);
end
fprintf(fid,'\nTotal reference photons are exposure calibration, not equal detected sample photons. Three levels correspond to mean reference counts 3.05, 30.5 and 305 per pixel. Camera audits record actual sample counts, clipping and low-signal pixel contributions. Known reference calibration and all clean fields are reused.\n\n');
fprintf(fid,'Baseline 200000-photon/1-electron results preserve the original product-sampler realization. New points use exact Poisson product/PTRS sampling with fixed seeds. At the other photon levels read-noise variants share shot counts. These are three transmission realizations on fixed layouts.\n');
end
function x=read(p)
x=jsondecode(fileread(p));
end
function put(p,x)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,jsonencode(x,'PrettyPrint',true),'char');
end
function h=digest(p)
f=fopen(p,'rb'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
