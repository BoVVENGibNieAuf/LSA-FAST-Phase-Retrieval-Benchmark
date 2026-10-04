function run_fast_support_optics
% Standalone resumable branch pilot. No writes to previous runs or latest pointers.
root=fileparts(fileparts(mfilename('fullpath'))); setup_project;
addpath(fullfile(root,'src','branch'),fullfile(root,'src','simulation'));
out=fullfile(root,'runs','support_optics_v1'); if ~isfolder(out), mkdir(out); end
lock=java.io.File(fullfile(out,'RUN.lock')); assert(lock.mkdir(),'FAST:Locked','Inspect previous process/lock before restart');
lockguard=onCleanup(@()rmdir(char(lock.getPath))); %#ok<NASGU>
timer=tic; rows=struct([]); current=struct; truth=[]; roi=[]; op=[]; d=[];
try
% Hash all executable dependencies; receipts are only reused under same hash.
files=[dir(fullfile(root,'src','branch','*.m'));dir(fullfile(root,'src','simulation','*.m')); ...
 dir(fullfile(root,'src','solvers','*.m'));dir(fullfile(root,'src','metrics','*.m')); ...
 dir(fullfile(root,'configs','*.m'));dir(fullfile(root,'tests','test_fast_optics.m')); ...
 dir(fullfile(root,'tools','run_fast_support_optics.m'))];
provenance=struct([]);
for j=1:numel(files)
 provenance(j).name=files(j).name; provenance(j).sha256=hash(fullfile(files(j).folder,files(j).name));
end
encoded=jsonencode(provenance); file=fullfile(out,'provenance.json');
if isfile(file), assert(strcmp(fileread(file),encoded),'FAST:ChangedCode','Use a new run folder after code changes'); else, putraw(file,encoded); end
put(fullfile(out,'tests.json'),test_fast_optics);
cfg=fast_mcf_config; cfg.n=600; cfg.dx=0.22e-6; cfg.facet_radius=26e-6;
cfg.support_radius=29e-6; cfg.patch_radius=22e-6; cfg.mode_truncation_radii=3;
% Keep transmission/coordinates identical for every ablation.
bank=fast_mcf_circular_bank(cfg,out); cfg.layout_bank=fullfile(out,'layout_bank.mat');
% columns label, support, w[um], truncation[w], NA, camera bin.
variants={ 'control','legacy_disk',0.9,3,Inf,2; ...
 'support','reference_close',0.9,3,Inf,2; ...
 'threshold_only','reference_threshold',0.9,3,Inf,2; ...
 'tails','reference_close',0.9,5,Inf,2; ...
 'relay','reference_close',0.9,5,0.25,2; ...
 'mode12','reference_close',1.2,5,0.25,2; ...
 'mode15','reference_close',1.5,5,0.25,2; ...
 'pixels1','reference_close',0.9,5,0.25,1; ...
 'pixels4','reference_close',0.9,5,0.25,4; ...
 'pixels5','reference_close',0.9,5,0.25,5};
protocol=struct('version','support-optics-v1','variants',{variants},'n',cfg.n,'dx_m',cfg.dx, ...
 'z_object_m',cfg.z,'reference_p_fine',10,'noise_seeds',[41001 41002 41003], ...
 'budgets',200,'max_wall_seconds',1800,'scope','163-core reduced patch; known ideal calibration; not full FAST reproduction', ...
 'sampling','fixed reconstruction grid/FOV; measured pixels binned; no interpolation gain', ...
 'support_source','ideal independent blank facet amplitude; no sample-truth tuning');
put(fullfile(out,'protocol.json'),protocol);
completed=0; total=2*(10+3*3)*4;
for layout=1:2
 cfg.layout=bank.labels{layout}; baseg=fast_mcf_layout_geometry(cfg);
 for v=1:size(variants,1)
  label=variants{v,1}; cfg.mode_radius=variants{v,3}*1e-6; cfg.mode_truncation_radii=variants{v,4};
  g=baseg; g.width=baseg.width*(cfg.mode_radius/0.9e-6);
  % Source tails extend across core boundary; only physical facet truncates.
  ref=fast_mcf_field(cfg,g,cfg.n,cfg.dx,'blank');
  truth=fast_mcf_field(cfg,g,cfg.n,cfg.dx,'mixed');
  scale=norm(ref,'fro'); ref=ref/scale; truth=truth/scale;
  [mask,maskinfo]=fast_optics_support(abs(ref),cfg.dx,variants{v,2});
  roi=abs(ref)>0.15*max(abs(ref(:))); % fixed within same physical field, not support
  op=fast_optics_operator(cfg.n,cfg.dx,cfg.lambda,cfg.z,variants{v,5},variants{v,6});
  detector=fast_optics_apply(truth,op,false); blank=fast_optics_apply(ref,op,false);
  ideal=fast_optics_bin(abs(detector).^2,op.bin);
  refinement=NaN;
  if strcmp(label,'relay')
   refFine=fast_mcf_field(cfg,g,2*cfg.n,cfg.dx/2,'blank');
   truthFine=fast_mcf_field(cfg,g,2*cfg.n,cfg.dx/2,'mixed')/norm(refFine,'fro');
   fineOp=fast_optics_operator(2*cfg.n,cfg.dx/2,cfg.lambda,cfg.z,0.25,2*op.bin);
   fineDetector=fast_optics_apply(truthFine,fineOp,false);
   fineIdeal=fast_optics_bin(abs(fineDetector).^2,fineOp.bin);
   refinement=norm(fineIdeal-ideal,'fro')/norm(fineIdeal,'fro');
   clear refFine truthFine fineOp fineDetector fineIdeal
  end
  % Common incident exposure fixed by NO-PUPIL blank at this field width.
  unfiltered=fast_optics_operator(cfg.n,cfg.dx,cfg.lambda,cfg.z,Inf,1);
  blank0=fast_optics_apply(ref,unfiltered,false);
  exposure=10/mean(abs(blank0(:)).^2);
  noiseSeeds=0; if ismember(label,{'support','relay','pixels1'}), noiseSeeds=[0 41001 41002 41003]; end
  for seed=noiseSeeds
   assert(toc(timer)<1800,'FAST:WallCap','Resume to continue after 1800s wall cap');
   name=sprintf('%s_%s_seed%d',cfg.layout,label,seed); caseDir=fullfile(out,name);
   if ~isfolder(caseDir), mkdir(caseDir); end
   d=struct('mask',mask,'calibration',ref,'amplitude',sqrt(ideal));
   if seed>0
    % Generate on finest detector lattice, then SUM identical count draws.
    % Identical seed across bins gives nested measurements and fixed photons.
    [fineAmp,noiseInfo]=fast_mcf_camera(abs(detector).^2,exposure,0,seed);
    d.amplitude=sqrt(fast_optics_bin(fineAmp.^2,op.bin));
   else
    noiseInfo=struct('seed',0,'kind','noiseless');
   end
   audit=maskinfo; audit.grid_refinement_relative_intensity_error=refinement;
   audit.truth_energy_excluded=sum(abs(truth(~mask)).^2)/sum(abs(truth(:)).^2);
   audit.pupil_sample_throughput=norm(detector,'fro')^2/norm(truth,'fro')^2;
   audit.pupil_blank_throughput=norm(blank,'fro')^2/norm(ref,'fro')^2;
   audit.expected_sample_counts=sum(abs(detector).^2,'all')*exposure;
   audit.camera_pixel_um=2.2*op.bin; audit.object_pixel_um=0.22*op.bin;
   put(fullfile(caseDir,'audit.json'),audit); put(fullfile(caseDir,'noise.json'),noiseInfo);
   if seed==0
    f=figure('Visible','off');
    subplot(2,2,1); imagesc(abs(ref)); axis image; title('Physical reference amplitude'); colorbar;
    facetOp=fast_optics_operator(cfg.n,cfg.dx,cfg.lambda,0,0.25,1);
    subplot(2,2,2); imagesc(abs(fast_optics_apply(ref,facetOp,false))); axis image; title('NA 0.25 facet image amplitude'); colorbar;
    subplot(2,2,3); imagesc(mask); axis image; title('Solver support');
    subplot(2,2,4); imagesc(d.amplitude.^2); axis image; title('Pixel-integrated detector intensity'); colorbar;
    exportgraphics(f,fullfile(caseDir,'model.png'),'Resolution',150); close(f);
   end
   inputFile=fullfile(caseDir,'input.mat');
   if ~isfile(inputFile), save(inputFile,'d','op','g','cfg','-v7'); end
   evalDir=fullfile(root,'evaluation_only','support_optics_v1',name);
   if ~isfolder(evalDir), mkdir(evalDir); end
   if ~isfile(fullfile(evalDir,'truth.mat')), save(fullfile(evalDir,'truth.mat'),'truth','roi','-v7'); end
   for method={'HIO','ER','RAAR','LBFGS'}
    m=method{1}; receipt=fullfile(caseDir,[m '_receipt.json']);
    if isfile(receipt)
     saved=jsondecode(fileread(receipt));
     assert(strcmp(saved.input_hash,hash(inputFile)) && strcmp(saved.curve_hash,hash(fullfile(caseDir,[m '_curve.csv']))) && ...
      strcmp(saved.final_hash,hash(fullfile(caseDir,[m '_final.mat']))),'FAST:Receipt','Saved artifact mismatch');
     completed=completed+1; continue
    end
    current=struct('case_name',name,'method',m); rows=struct([]);
    observe(d.mask.*d.calibration,0,0,0);
    solver=fast_four_solver_config; solver.budgets=200; solver.max_solver_seconds=120; solver.observer=@observe;
    result=fast_optics_solve(d,op,solver,m); % truth stays in observer/scoring scope
    writetable(struct2table(rows),fullfile(caseDir,[m '_curve.csv']));
    save(fullfile(caseDir,[m '_final.mat']),'result','-v7');
    put(receipt,struct('state','completed','input_hash',hash(inputFile), ...
     'curve_hash',hash(fullfile(caseDir,[m '_curve.csv'])), ...
     'final_hash',hash(fullfile(caseDir,[m '_final.mat'])), ...
     'stop_reason',result.stop_reason,'calls',result.solver_propagations));
    completed=completed+1;
    put(fullfile(out,'status.json'),struct('state','running','completed',completed,'total',total,'case_name',name,'method',m));
   end
  end
 end
end
put(fullfile(out,'status.json'),struct('state','completed','completed',completed,'total',total,'elapsed_seconds',toc(timer)));
build_fast_support_optics_summary(out);
fprintf('SUPPORT_OPTICS_COMPLETE: %s\n',out);
catch err
 put(fullfile(out,'failure.json'),struct('message',err.message,'identifier',err.identifier,'elapsed_seconds',toc(timer)));
 put(fullfile(out,'status.json'),struct('state','stopped','message',err.message,'resume','rerun same launcher; accepted receipts reused'));
 rethrow(err)
end
 function observe(u,iteration,calls,seconds)
  [e,p,theta]=fast_field_error(u,truth,roi);
  aligned=u*exp(-1i*theta); full=norm(aligned-truth,'fro')/norm(truth,'fro');
  predicted=sqrt(fast_optics_bin(abs(fast_optics_apply(u,op,false)).^2,op.bin));
  r=current; r.iteration=iteration; r.calls=calls; r.seconds=seconds;
  r.field_nrmse=e; r.full_field_nrmse=full; r.phase_rmse=p;
  r.measurement_residual=norm(predicted-d.amplitude,'fro')/norm(d.amplitude,'fro');
  if isempty(rows), rows=r; else, rows(end+1)=r; end
 end
end
function put(p,v), putraw(p,jsonencode(v,'PrettyPrint',true)); end
function putraw(p,s)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,unicode2native(s,'UTF-8'),'uint8');
end
function h=hash(p)
f=fopen(p,'rb'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
