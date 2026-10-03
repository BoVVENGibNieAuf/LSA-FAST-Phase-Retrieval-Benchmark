function result=test_fast_mcf
% Mathematical invariants, detector semantics and fixed-fiber pairing.
saved=rng; guard=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(13,'twister'); cfg=fast_mcf_config; n=32;
a=randn(n)+1i*randn(n); b=randn(n)+1i*randn(n);
H=fast_mcf_transfer(n,cfg.dx,cfg.lambda,cfg.z);
P=@(u)ifft2(fft2(u).*H); Pt=@(u)ifft2(fft2(u).*conj(H));
result.round_trip=norm(Pt(P(a))-a,'fro')/norm(a,'fro');
pa=P(a); pb=Pt(b);
result.adjoint=abs(sum(conj(pa(:)).*b(:))-sum(conj(a(:)).*pb(:)))/(norm(a,'fro')*norm(b,'fro'));
result.plane_wave=norm(P(ones(n))-ones(n),'fro')/n;
% Exact known Fourier mode independently fixes sign, bin index and units.
[j,k]=meshgrid(0:n-1); wave=exp(2i*pi*(3*j+2*k)/n);
f2=(3/(n*cfg.dx))^2+(2/(n*cfg.dx))^2;
expected=exp(1i*2*pi/cfg.lambda*cfg.z*(sqrt(1-cfg.lambda^2*f2)-1));
result.fourier_mode=norm(P(wave)-expected*wave,'fro')/n;
v=reshape(1:64,8,8); av=fast_mcf_pixel_average(v,2); manual=zeros(4);
for r=1:4, for c=1:4, manual(r,c)=mean(v(2*r-1:2*r,2*c-1:2*c),'all'); end, end
result.pixel_average=norm(av-manual,'fro');
% Constant intensity with alternating phase stays constant after integration.
checker=(-1).^j; result.intensity_integration=norm(fast_mcf_pixel_average(abs(checker).^2,2)-ones(n/2),'fro');
g=fast_mcf_geometry(cfg); g2=fast_mcf_geometry(cfg);
result.geometry_repeat=isequal(g,g2);
[ref,coeff]=fast_mcf_field(cfg,g,2*cfg.n,cfg.dx/2,'blank');
[ref2,~]=fast_mcf_field(cfg,g,2*cfg.n,cfg.dx/2,'blank',coeff);
result.fixed_coefficients=norm(ref-ref2,'fro')/norm(ref,'fro');
[changed,~]=fast_mcf_field(cfg,g,2*cfg.n,cfg.dx/2,'blank',2*coeff);
result.coefficient_linearity=norm(changed-2*ref,'fro')/norm(ref,'fro');
% Reference-subtraction phase on blank must vanish on bright core pixels.
roi=abs(ref)>0.15*max(abs(ref(:)));
result.blank_correction=max(abs(angle(ref(roi).*conj(ref2(roi)))));
[shot,~]=fast_mcf_camera(ones(128),20,0,42);
counts=shot(:).^2*20;
result.poisson_mean=mean(counts); result.poisson_variance=var(counts);
[shot2,~]=fast_mcf_camera(ones(128),20,0,42);
result.camera_repeat=isequal(shot,shot2);
% Exercise the actual checkpoint writer and partial-run recovery path.
scratch=tempname; mkdir(scratch); cleanup=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
partial=fullfile(scratch,'partial'); fresh=fullfile(scratch,'fresh'); mkdir(partial); mkdir(fresh);
d=struct('calibration',a,'mask',double(abs(a)>0.7),'amplitude',abs(P(a)));
c=cfg; c.iterations=1; c.checkpoints=1;
r1=fast_mcf_solve_case(d,H,c,'HIO',partial,scratch,tic,'regression');
c.iterations=2; c.checkpoints=[1 2];
r2=fast_mcf_solve_case(d,H,c,'HIO',partial,scratch,tic,'regression');
r3=fast_mcf_solve_case(d,H,c,'HIO',fresh,scratch,tic,'regression');
u2=load(r2(end).path,'internal_state'); u3=load(r3(end).path,'internal_state');
result.checkpoint_resume_error=norm(u2.internal_state-u3.internal_state,'fro');
result.checkpoint_schema=numel(r1)==1 && numel(r2)==2 && numel(r3)==2 && ...
 r2(1).reused && ~r2(2).reused && ~r1(1).reused;
checks=[result.round_trip result.adjoint result.plane_wave result.fourier_mode ...
 result.pixel_average result.intensity_integration result.fixed_coefficients ...
 result.coefficient_linearity result.blank_correction result.checkpoint_resume_error];
result.passed=all(checks<1e-9) && result.geometry_repeat && result.camera_repeat && result.checkpoint_schema && ...
 abs(result.poisson_mean-20)<0.4 && abs(result.poisson_variance-20)<1.2;
end
