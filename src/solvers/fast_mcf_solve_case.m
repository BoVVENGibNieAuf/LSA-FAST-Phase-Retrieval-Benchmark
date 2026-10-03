function receipts=fast_mcf_solve_case(d,H,cfg,method,caseDir,out,tAll,name)
% Shared solver, with typed receipt schema and validated checkpoint recovery.
u=d.calibration.*d.mask; seconds=0;
receipts=struct('path',{},'iteration',{},'seconds',{},'reused',{});
k=0; first=1; gap=false;
for it=reshape(cfg.checkpoints,1,[])
 p=fullfile(caseDir,sprintf('%s_iter%03d.mat',method,it));
 if ~isfile(p), gap=true; continue; end
 assert(~gap,'FAST:CheckpointGap','A checkpoint is missing before %s',p);
 saved=load(p,'internal_state','physical_output','completed_iteration','seconds');
 assert(saved.completed_iteration==it && isequal(size(saved.internal_state),size(H)), ...
  'FAST:CheckpointShape','Invalid checkpoint iteration or dimensions');
 assert(all(isfinite(saved.internal_state(:))) && isfinite(saved.seconds) && saved.seconds>=0, ...
  'FAST:CheckpointValue','Invalid checkpoint state or timing');
 assert(isequal(saved.physical_output,d.mask.*saved.internal_state), ...
  'FAST:CheckpointProjection','Stored physical output disagrees with state');
 k=k+1; receipts(k)=struct('path',p,'iteration',it,'seconds',saved.seconds,'reused',true); %#ok<AGROW>
 u=saved.internal_state; seconds=saved.seconds; first=it+1;
end
for it=first:cfg.iterations
 assert(toc(tAll)<cfg.max_wall_seconds,'FAST:TimeCap','MCF pilot wall-clock soft cap reached');
 timer=tic; detector=ifft2(fft2(u).*H);
 v=ifft2(fft2(fast_project_amplitude(detector,d.amplitude)).*conj(H));
 u=fast_support_step(u,v,d.mask,method,cfg.beta); seconds=seconds+toc(timer);
 assert(all(isfinite(u(:))),'FAST:Nonfinite','Nonfinite MCF solver state');
 if ismember(it,cfg.checkpoints)
  k=k+1; internal_state=u; physical_output=d.mask.*u; completed_iteration=it; %#ok<NASGU>
  p=fullfile(caseDir,sprintf('%s_iter%03d.mat',method,it));
  assert(~isfile(p),'FAST:CheckpointOverwrite','Checkpoint already exists');
  save(p,'internal_state','physical_output','completed_iteration','seconds');
  receipts(k)=struct('path',p,'iteration',it,'seconds',seconds,'reused',false); %#ok<AGROW>
  f=fopen(fullfile(out,'status.json'),'w','n','UTF-8'); assert(f>=0);
  guard=onCleanup(@()fclose(f)); %#ok<NASGU>
  fwrite(f,jsonencode(struct('state','running','case',name,'method',method, ...
   'completed_iterations',it,'elapsed_seconds',toc(tAll))),'char');
  clear guard
 end
end
end
