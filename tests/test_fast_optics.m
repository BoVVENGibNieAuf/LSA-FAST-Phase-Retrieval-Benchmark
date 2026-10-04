function receipt=test_fast_optics
% Operator adjoint, integrated detector gradient and legacy-limit equivalence.
saved=rng; guard=onCleanup(@()rng(saved)); rng(72); %#ok<NASGU>
n=24; op=fast_optics_operator(n,0.5e-6,532e-9,12e-6,0.25,2);
u=randn(n)+1i*randn(n); v=randn(n)+1i*randn(n);
Au=fast_optics_apply(u,op,false); Atv=fast_optics_apply(v,op,true);
adj=abs(sum(conj(Au(:)).*v(:))-sum(conj(u(:)).*Atv(:)))/max(1,norm(u(:))*norm(v(:)));
assert(adj<1e-12);
m=true(n); x=[real(u(:));imag(u(:))]; a=abs(randn(n/2));
[f,g]=fast_optics_objective(x,a,m,op,1e-8); %#ok<ASGLU>
p=randn(size(x)); p=p/norm(p); h=1e-5;
f1=fast_optics_objective(x+h*p,a,m,op,1e-8);
f0=fast_optics_objective(x-h*p,a,m,op,1e-8);
grad=abs((f1-f0)/(2*h)-g'*p)/max(1,abs(g'*p)); assert(grad<1e-6);
y=fast_optics_project(u,a,2); projected=sqrt(fast_optics_bin(abs(y).^2,2));
assert(norm(projected-a,'fro')<1e-12);
z=fast_optics_project(zeros(n),a,2); assert(norm(sqrt(fast_optics_bin(abs(z).^2,2))-a,'fro')<1e-12);
assert(abs(sum(fast_optics_bin(abs(u).^2,2),'all')-sum(abs(u).^2,'all'))<1e-9);
op=fast_optics_operator(n,0.5e-6,532e-9,12e-6,Inf,1);
a=abs(randn(n)); mask=true(n); mask(1:3,:)=false;
d=struct('mask',mask,'calibration',u,'amplitude',a);
cfg=fast_four_solver_config; cfg.budgets=[2 8]; cfg.max_solver_seconds=30;
for method={'HIO','ER','RAAR','LBFGS'}
 old=fast_four_solve(d,op.transfer,cfg,method{1}); new=fast_optics_solve(d,op,cfg,method{1});
 assert(norm(old.snapshots(end).physical_output-new.snapshots(end).physical_output,'fro')<1e-9);
end
receipt=struct('passed',true,'adjoint_relative_error',adj,'gradient_relative_error',grad, ...
 'legacy_limit_methods',4,'block_norm_and_count_conservation',true);
end
