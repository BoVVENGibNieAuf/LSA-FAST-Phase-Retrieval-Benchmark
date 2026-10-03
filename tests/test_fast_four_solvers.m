function checks=test_fast_four_solvers
% Derivative, reflector order, fixed point, legacy equivalence and accounting.
saved=rng; guard=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(104,'twister'); n=16; base=fast_mcf_config; cfg=fast_four_solver_config;
H=fast_mcf_transfer(n,base.dx,base.lambda,base.z);
P=@(u)ifft2(fft2(u).*H); Pt=@(u)ifft2(fft2(u).*conj(H));
mask=zeros(n); mask(4:13,4:13)=1; idx=logical(mask);
u=mask.*(randn(n)+1i*randn(n)); v=randn(n)+1i*randn(n);
a=abs(P(u)); x=[real(u(idx));imag(u(idx))]+0.1*randn(2*nnz(idx),1);
epsilon=1e-5; [~,g]=fast_amplitude_objective(x,a,mask,H,epsilon);
errors=zeros(1,4);
for j=1:4
 direction=randn(size(x)); direction=direction/norm(direction); h=1e-5;
 fp=fast_amplitude_objective(x+h*direction,a,mask,H,epsilon);
 fm=fast_amplitude_objective(x-h*direction,a,mask,H,epsilon);
 fd=(fp-fm)/(2*h); errors(j)=abs(fd-g'*direction)/max([1 abs(fd) abs(g'*direction)]);
end
checks.gradient_directional=max(errors);
[f0,g0]=fast_amplitude_objective(zeros(size(x)),a,mask,H,epsilon);
checks.zero_finite=isfinite(f0) && all(isfinite(g0));
% Independent pointwise form: inside=v; outside=beta*u+(1-2*beta)*v.
beta=.73; expected=mask.*v+(1-mask).*(beta*u+(1-2*beta)*v);
checks.raar_formula=norm(fast_raar_step(u,v,mask,beta)-expected,'fro');
checks.raar_beta_zero=norm(fast_raar_step(u,v,mask,0)-v,'fro');
checks.raar_fixed_point=norm(fast_raar_step(u,Pt(fast_project_amplitude(P(u),a)),mask,beta)-u,'fro');
d=struct('mask',mask,'calibration',u+.3*mask.*v,'amplitude',a);
cfg.budgets=[8 20]; cfg.max_solver_seconds=60;
checks.legacy_equivalence=0; checks.budget_and_projection=true;
for method={'HIO','ER','RAAR','LBFGS'}
 r=fast_four_solve(d,H,cfg,method{1});
 checks.budget_and_projection=checks.budget_and_projection && numel(r.snapshots)==2 && ...
  all([r.snapshots.solver_propagations]<=[r.snapshots.budget]) && r.solver_propagations<=20;
 for s=r.snapshots
  checks.budget_and_projection=checks.budget_and_projection && ...
   isequal(s.physical_output,s.internal_state.*mask) && all(isfinite(s.internal_state(:)));
 end
 if ismember(method{1},{'HIO','ER'})
  w=d.calibration.*mask;
  for k=1:10
   q=Pt(fast_project_amplitude(P(w),a));
   w=fast_support_step(w,q,mask,method{1},cfg.hio_beta);
  end
  checks.legacy_equivalence=max(checks.legacy_equivalence,norm(r.snapshots(end).internal_state-w,'fro'));
 elseif strcmp(method{1},'LBFGS')
  t=r.objective_trace; accepted=t([t.accepted]);
  checks.lbfgs_descent=all(diff([accepted.objective])<=1e-10) && numel(accepted)>1;
  checks.lbfgs_accounting=r.solver_propagations==2*numel(t) && r.line_trials==numel(t)-1 && ...
   r.rejected_trials==sum(~[t.accepted]);
 end
end
% Force an early stop; future budget records must retain actual call count.
cfg.gradient_tolerance=1e20; r=fast_four_solve(d,H,cfg,'LBFGS');
checks.early_stop=strcmp(r.stop_reason,'gradient_tolerance') && all([r.snapshots.solver_propagations]==2);
% Deliberately impossible positive descent direction acceptance threshold:
% high Armijo forces backtracking; verify rejection costs and descent.
cfg.gradient_tolerance=1e-10; cfg.armijo=.99; cfg.budgets=[2 12];
r=fast_four_solve(d,H,cfg,'LBFGS');
checks.rejection_accounting=r.rejected_trials>0 && r.solver_propagations==2*numel(r.objective_trace) && ...
 r.rejected_trials==sum(~[r.objective_trace.accepted]);
checks.passed=checks.gradient_directional<1e-6 && checks.zero_finite && ...
 checks.raar_formula<1e-10 && checks.raar_beta_zero<1e-10 && checks.raar_fixed_point<1e-9 && ...
 checks.legacy_equivalence<1e-10 && checks.budget_and_projection && checks.lbfgs_descent && ...
 checks.lbfgs_accounting && checks.early_stop && checks.rejection_accounting;
end
