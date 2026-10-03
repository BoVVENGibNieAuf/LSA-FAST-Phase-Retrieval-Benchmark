function audit=fast_mcf_layout_generate(out,truthdir,cfg)
% Generation owns fiber parameters and truth. Solver inputs have common
% reference field, support, measured amplitudes and propagation parameters.
g=fast_mcf_layout_geometry(cfg); nf=cfg.n*cfg.oversample; df=cfg.dx/cfg.oversample;
[rf,cr]=fast_mcf_field(cfg,g,nf,df,'blank');
raw_power=sum(abs(rf(:)).^2)*df^2;
g.base_gain=g.gain; g.illumination_scale=sqrt(cfg.reference_power/raw_power);
g.gain=g.gain*g.illumination_scale; rf=rf*g.illumination_scale;
ref=fast_mcf_field(cfg,g,cfg.n,cfg.dx,'blank',cr);
x=((0:cfg.n-1)-(cfg.n-1)/2)*cfg.dx; [xx,yy]=meshgrid(x);
mask=double(hypot(xx,yy)<=cfg.support_radius);
roi=logical(mask)&abs(ref)>cfg.roi_fraction*max(abs(ref(:)));
H=fast_mcf_transfer(nf,df,cfg.lambda,cfg.z);
P=@(u)ifft2(fft2(u).*H);
refIntensity=fast_mcf_pixel_average(abs(P(rf)).^2,cfg.oversample);
exposure=cfg.reference_photons/sum(refIntensity(:));
% Independent quadrature resolution check for blank, prior to solver results.
[r4,~]=fast_mcf_field(cfg,g,4*cfg.n,cfg.dx/4,'blank');
H4=fast_mcf_transfer(4*cfg.n,cfg.dx/4,cfg.lambda,cfg.z);
i4=fast_mcf_pixel_average(abs(ifft2(fft2(r4).*H4)).^2,4);
audit=struct('layout',cfg.layout,'reference_power',sum(abs(rf(:)).^2)*df^2, ...
 'reference_photons',sum(refIntensity(:))*exposure,'illumination_scale',g.illumination_scale, ...
 'core_count',g.core_count,'minimum_spacing_m',g.minimum_spacing, ...
 'generation_propagations',2,'oversample_2_vs_4_amplitude_nrmse', ...
 norm(sqrt(refIntensity)-sqrt(i4),'fro')/norm(sqrt(i4),'fro'), ...
 'grid_convergence_tolerance',0.02,'detector_edge_energy_fraction',[], ...
 'edge_tolerance',0.005,'exposure_electrons_per_intensity',exposure);
save(fullfile(out,'generation_audit_partial.mat'),'audit');
assert(audit.oversample_2_vs_4_amplitude_nrmse<audit.grid_convergence_tolerance, ...
 'FAST:Sampling','MCF subpixel convergence check failed');
clear r4 H4 i4
reference_amplitudes=zeros(cfg.n,cfg.n,numel(cfg.reference_z));
for k=1:numel(cfg.reference_z)
 Hr=fast_mcf_transfer(nf,df,cfg.lambda,cfg.reference_z(k));
 reference_amplitudes(:,:,k)=sqrt(fast_mcf_pixel_average(abs(ifft2(fft2(rf).*Hr)).^2,cfg.oversample));
end
audit.generation_propagations=audit.generation_propagations+numel(cfg.reference_z);
save(fullfile(out,'reference_measurements.mat'),'reference_amplitudes','cfg');
save(fullfile(truthdir,'fiber_model.mat'),'g','cfg','cr');
edge=false(cfg.n); edge([1:4 end-3:end],:)=true; edge(:,[1:4 end-3:end])=true;
for s=1:numel(cfg.scenes)
 scene=cfg.scenes{s}; [uf,coeff]=fast_mcf_field(cfg,g,nf,df,scene);
 truth=fast_mcf_field(cfg,g,cfg.n,cfg.dx,scene,coeff);
 intensity=fast_mcf_pixel_average(abs(P(uf)).^2,cfg.oversample);
 audit.generation_propagations=audit.generation_propagations+1;
 audit.detector_edge_energy_fraction(s)=sum(intensity(edge))/sum(intensity(:));
 save(fullfile(out,'generation_audit_partial.mat'),'audit');
 assert(audit.detector_edge_energy_fraction(s)<audit.edge_tolerance, ...
  'FAST:Boundary','Detector edge energy exceeds declared tolerance');
 % One exposure for every scene, selected solely from blank reference.
 for c=1:numel(cfg.conditions)
  condition=cfg.conditions{c};
  if strcmp(condition,'clean')
   amplitude=sqrt(intensity); camera=struct('noise','none','exposure',exposure);
  else
   [amplitude,camera]=fast_mcf_camera(intensity,exposure,cfg.read_noise_electrons,cfg.noise_seed+s);
  end
  calibration=ref;
  save(fullfile(out,[scene '_' condition '_input.mat']),'amplitude','mask','calibration','camera');
 end
 save(fullfile(truthdir,[scene '_truth.mat']),'truth','roi','coeff');
end
% Figure records actual generated fields; no paper figure reuse.
f=figure('Visible','off'); guard=onCleanup(@()close(f)); %#ok<NASGU>
phase=angle(ref); phase(~roi)=NaN;
subplot(2,2,1); imagesc(x*1e6,x*1e6,abs(ref)); axis image; colorbar; title('Reference facet amplitude');
subplot(2,2,2); imagesc(x*1e6,x*1e6,phase,[-pi pi]); axis image; colorbar; title('Per-core reference phase (rad)');
subplot(2,2,3); imagesc(x*1e6,x*1e6,refIntensity); axis image; colorbar; title('Pixel-integrated detector intensity');
subplot(2,2,4); scatter(g.xy(:,1)*1e6,g.xy(:,2)*1e6,25,g.phase,'filled'); axis image; colorbar; title(sprintf('%d illuminated cores',g.core_count));
if isfield(cfg,'facet_radius')
 theta=linspace(0,2*pi,500);
 for j=[1 2 4]
  subplot(2,2,j); hold on;
  plot(cfg.facet_radius*cos(theta)*1e6,cfg.facet_radius*sin(theta)*1e6,'w-','LineWidth',1.2);
  plot(cfg.support_radius*cos(theta)*1e6,cfg.support_radius*sin(theta)*1e6,'r--');
 end
end
set(f,'Position',[50 50 1000 850]); exportgraphics(f,fullfile(out,'MCF_model.png'),'Resolution',150);
end
