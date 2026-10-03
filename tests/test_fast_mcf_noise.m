function result=test_fast_mcf_noise
levels=[0 0.1 5 10 20 200 20000 2000000]; n=20000;
result=struct('passed',true,'cases',struct([]));
for j=1:numel(levels)
 lam=levels(j); [~,~,x]=fast_mcf_noise_camera(lam*ones(n,1),1,0,800+j);
 r=struct('lambda',lam,'mean',mean(x),'variance',var(x), ...
  'integer_nonnegative',all(x>=0 & x==floor(x)));
 r.passed=r.integer_nonnegative && abs(r.mean-lam)<6*sqrt(lam/n)+1e-8 && ...
  abs(r.variance-lam)<0.10*lam+0.01;
 if j==1, result.cases=r; else, result.cases(j)=r; end
 result.passed=result.passed && r.passed;
end
[a,~,x]=fast_mcf_noise_camera(20*ones(64),1,0,91);
[b,~,y]=fast_mcf_noise_camera(20*ones(64),1,1,91);
result.paired_shot_counts=isequal(x,y); result.read_noise_changes_data=~isequal(a,b);
[c,~,~]=fast_mcf_noise_camera(20*ones(64),1,1,91);
result.repeatable=isequal(b,c);
result.passed=result.passed && result.paired_shot_counts && result.read_noise_changes_data && result.repeatable;
end
