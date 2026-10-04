function result=fast_optics_solve(d,op,cfg,method,checkpoint_dir)
% Common entry point. No truth path/data accepted. Complete forward and
% adjoint propagation calls counted; rejected L-BFGS evaluations also count.
if nargin<5, checkpoint_dir=''; end
assert(ismember(method,{'HIO','ER','RAAR','LBFGS'}));
assert(isequal([op.n op.n],size(d.mask),size(d.calibration)));
assert(isequal(size(d.amplitude),[op.n/op.bin op.n/op.bin]));
assert(all(d.mask(:)==0 | d.mask(:)==1) && any(d.mask(:)));
assert(all(isfinite(d.amplitude(:))) && all(d.amplitude(:)>=0));
assert(all(isfinite(d.calibration(:))) && all(isfinite(op.transfer(:))));
% Finite pupil: adjoint data correction, NOT an inverse propagation.
% HIO/RAAR are generalized consistency iterations in this branch.
budgets=reshape(cfg.budgets,1,[]);
assert(all(diff(budgets)>0) && all(mod(budgets,2)==0) && all(budgets>=2));
u=d.mask.*d.calibration; calls=0; steps=0; seconds=0; trials=0; rejected=0;
lastAcceptedCalls=0; objective=NaN; stop='propagation_budget';
snaps=struct('budget',{},'solver_propagations',{},'state_propagations',{}, ...
 'iteration',{},'solver_seconds',{},'objective',{},'line_trials',{}, ...
 'rejected_trials',{},'internal_state',{},'physical_output',{});
trace=struct('calls',{},'objective',{},'accepted',{});
start=tic;
if strcmp(method,'LBFGS')
 timer=tic;
 scale=norm(d.amplitude,'fro')/sqrt(numel(d.amplitude));
 assert(isfinite(scale) && scale>0,'FAST:ZeroData','Nonzero measured amplitude required');
 idx=logical(d.mask); x=[real(u(idx));imag(u(idx))]/scale;
 a=d.amplitude/scale;
 [objective,g]=fast_optics_objective(x,a,d.mask,op,cfg.amplitude_epsilon);
 calls=2; lastAcceptedCalls=2; assert(isfinite(objective) && all(isfinite(g)));
 S=zeros(numel(x),0); Y=S; trace=add_trace(trace,calls,objective,true);
 seconds=seconds+toc(timer); emit();
 while calls<budgets(end)
  assert(toc(start)<cfg.max_solver_seconds,'FAST:SolverTimeout','Solver soft time cap reached');
  timer=tic;
  if norm(g)<=cfg.gradient_tolerance*max(1,norm(x))
   seconds=seconds+toc(timer); stop='gradient_tolerance'; break
  end
  p=lbfgs_direction(g,S,Y);
  slope=g'*p;
  if ~isfinite(slope) || slope>=0
   S=zeros(numel(x),0); Y=S; p=-g; slope=-(g'*g);
  end
  alpha=1; accepted=false; seconds=seconds+toc(timer);
  for ls=1:cfg.max_line_trials
   if calls+2>budgets(end), break; end
   assert(toc(start)<cfg.max_solver_seconds,'FAST:SolverTimeout','Solver soft time cap reached');
   timer=tic; xt=x+alpha*p;
   [ft,gt]=fast_optics_objective(xt,a,d.mask,op,cfg.amplitude_epsilon);
   calls=calls+2; trials=trials+1;
   accepted=isfinite(ft) && all(isfinite(gt)) && ft<=objective+cfg.armijo*alpha*slope;
   trace=add_trace(trace,calls,ft,accepted);
   if accepted
    s=xt-x; y=gt-g; curvature=s'*y;
    if curvature>1e-10*norm(s)*norm(y) && curvature>0
     if size(S,2)==cfg.lbfgs_memory, S(:,1)=[]; Y(:,1)=[]; end
     S(:,end+1)=s; Y(:,end+1)=y; %#ok<AGROW>
    end
    x=xt; g=gt; objective=ft; steps=steps+1; lastAcceptedCalls=calls;
    n=nnz(idx); u=complex(zeros(size(d.mask))); u(idx)=scale*complex(x(1:n),x(n+1:end));
   else
    rejected=rejected+1;
   end
   seconds=seconds+toc(timer); emit();
   if accepted, break; end
   alpha=alpha*cfg.backtrack;
  end
  if ~accepted
   if calls<budgets(end), stop='line_search_failed'; end
   break
  end
 end
else
 while calls<budgets(end)
  assert(toc(start)<cfg.max_solver_seconds,'FAST:SolverTimeout','Solver soft time cap reached');
  timer=tic; detector=fast_optics_apply(u,op,false);
  projected=fast_optics_project(detector,d.amplitude,op.bin);
  v=u+fast_optics_apply(projected-detector,op,true);
  if strcmp(method,'RAAR')
   u=fast_raar_step(u,v,d.mask,cfg.raar_beta);
  else
   u=fast_support_step(u,v,d.mask,method,cfg.hio_beta);
  end
  calls=calls+2; steps=steps+1; lastAcceptedCalls=calls;
  assert(all(isfinite(u(:))),'FAST:Nonfinite','Nonfinite solver state');
  seconds=seconds+toc(timer); emit();
 end
end
% Early stopping carries the last accepted state to each remaining budget;
% actual spent calls remain unchanged and stop reason is recorded.
for b=budgets
 if isempty(snaps) || ~ismember(b,[snaps.budget]), snapshot(b); end
end
result=struct('method',method,'stop_reason',stop,'solver_propagations',calls, ...
 'solver_seconds',seconds,'iterations',steps,'line_trials',trials, ...
 'rejected_trials',rejected,'snapshots',snaps,'objective_trace',trace);
 function emit
  if isfield(cfg,'observer')
   cfg.observer(d.mask.*u,steps,calls,seconds);
  end
  if ismember(calls,budgets), snapshot(calls); end
 end
 function snapshot(budget)
  checkpoint=struct('budget',budget,'solver_propagations',calls,'state_propagations',lastAcceptedCalls, ...
   'iteration',steps,'solver_seconds',seconds,'objective',objective, ...
   'line_trials',trials,'rejected_trials',rejected,'internal_state',u,'physical_output',d.mask.*u);
  snaps(end+1)=checkpoint;
  if ~isempty(checkpoint_dir)
   path=fullfile(checkpoint_dir,sprintf('%s_budget%04d.mat',method,budget));
   assert(~isfile(path),'FAST:Overwrite','Checkpoint already exists');
   save(path,'checkpoint');
  end
 end
end
function p=lbfgs_direction(g,S,Y)
q=g; k=size(S,2); alpha=zeros(k,1); rho=alpha;
for j=k:-1:1
 rho(j)=1/(Y(:,j)'*S(:,j)); alpha(j)=rho(j)*(S(:,j)'*q); q=q-alpha(j)*Y(:,j);
end
if k>0, gamma=(S(:,k)'*Y(:,k))/(Y(:,k)'*Y(:,k)); else, gamma=1; end
r=gamma*q;
for j=1:k
 beta=rho(j)*(Y(:,j)'*r); r=r+S(:,j)*(alpha(j)-beta);
end
p=-r;
end
function t=add_trace(t,calls,f,accepted)
r=struct('calls',calls,'objective',f,'accepted',accepted);
if isempty(t), t=r; else, t(end+1)=r; end
end
