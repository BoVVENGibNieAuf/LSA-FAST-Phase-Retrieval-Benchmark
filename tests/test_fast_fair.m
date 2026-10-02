function results = test_fast_fair()
% Small, explicitly same-model correctness checks, NOT paper experiments.
saved=rng; restore=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(20261002,'twister');
n=32; dp=2.2e-6; lambda=532e-9; z=0.0788;
a=randn(n)+1i*randn(n); b=randn(n)+1i*randn(n);
P=@(u,d)prop(u,dp,dp,lambda,d);
results=struct;
results.zero_distance=norm(P(a,0)-a,'fro')/norm(a,'fro');
results.round_trip=norm(P(P(a,z),-z)-a,'fro')/norm(a,'fro');
pa=P(a,z); ab=P(b,-z);
results.adjoint=abs(sum(conj(pa(:)).*b(:))-sum(conj(a(:)).*ab(:)))/(norm(a,'fro')*norm(b,'fro'));
% Legacy even-grid kernel places zero frequency at index n/2, not n/2+1.
% A constant remains constant, with the legacy grid's transfer coefficient.
pw=P(ones(n),z);
k=2*pi/lambda; expected=exp(-1i*sqrt(k^2-2*(2*pi/(dp*n))^2)*z);
results.legacy_plane_wave=norm(pw-expected,'fro')/n;
results.legacy_dc_phase_offset_rad=angle(expected/exp(-1i*k*z));
mask=rand(n)>0.5; beta=0.2;
old=((1+beta)*b-a).*mask+a-beta*b;
new=fast_support_step(a,b,mask,'HIO',beta);
results.hio_algebra=norm(new-old,'fro')/norm(old,'fro');
er=fast_support_step(a,b,mask,'ER',beta);
results.er_support=norm(er(~mask));
v=fast_project_amplitude(zeros(n),ones(n));
results.zero_amplitude_finite=all(isfinite(v(:))) && all(v(:)==1);
results.amplitude_constraint=norm(abs(fast_project_amplitude(a,abs(b)))-abs(b),'fro')/norm(b,'fro');
[results.global_phase_nrmse,results.global_phase_rmse]=fast_field_error(a*exp(1i*0.8),a,true(n));
[results.gain_not_removed,~]=fast_field_error(2*a,a,true(n));
truth=mask.*a; measured=abs(P(truth,z));
back=P(fast_project_amplitude(P(truth,z),measured),-z);
results.truth_fixed_point=norm(mask.*back-truth,'fro')/norm(truth,'fro');
% ER reduces Euclidean distance to the amplitude set for this unitary model.
u=mask.*b; residual=zeros(6,1);
for j=1:6
    residual(j)=norm(abs(P(u,z))-measured,'fro');
    u=mask.*P(fast_project_amplitude(P(u,z),measured),-z);
end
results.er_nonincrease=all(diff(residual)<=1e-10*max(residual));
checks=[results.zero_distance,results.round_trip,results.adjoint,results.legacy_plane_wave, ...
 results.hio_algebra,results.er_support,results.amplitude_constraint, ...
 results.global_phase_nrmse,results.global_phase_rmse,results.truth_fixed_point];
results.passed=all(checks<1e-9) && results.zero_amplitude_finite && ...
 abs(results.gain_not_removed-1)<1e-10 && results.er_nonincrease;
results.scope='CPU double, even grid, no evanescent frequencies; legacy frequency indexing retained';
% Caller writes this result before aborting on a failed check.
end
