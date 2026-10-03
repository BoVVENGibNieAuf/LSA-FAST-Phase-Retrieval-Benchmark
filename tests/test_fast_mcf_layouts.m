function result=test_fast_mcf_layouts(bankpath)
b=load(bankpath,'bank'); b=b.bank; cfg=fast_mcf_config; cfg.layout_bank=bankpath;
result=struct('equal_count',true,'common_radius',true,'paired_parameters',true,'seed_changes_phase',true);
first=[];
for s=[20261003 20261004]
 cfg.seed=s;
 for j=1:numel(b.labels)
  cfg.layout=b.labels{j}; g=fast_mcf_layout_geometry(cfg);
  result.equal_count=result.equal_count && g.core_count==127;
  result.common_radius=result.common_radius && abs(max(vecnorm(g.xy,2,2))-19.2e-6)<1e-12;
  if j==1
   base=g;
   if isempty(first), first=g.phase;
   else, result.seed_changes_phase=~isequal(first,g.phase); end
  else
   result.paired_parameters=result.paired_parameters && isequal(g.width,base.width) && ...
    isequal(g.gain,base.gain) && isequal(g.phase,base.phase);
  end
 end
end
result.hex_sixfold=b.stats(1).global_sixfold_order;
result.hex_spacing_cv=b.stats(1).spacing_cv;
result.measured_spacing_cv=b.stats(3).spacing_cv;
result.measured_sixfold=b.stats(3).global_sixfold_order;
result.distinct_layouts=~isequal(b.coordinates{1},b.coordinates{2}) && ~isequal(b.coordinates{1},b.coordinates{3});
result.passed=result.equal_count && result.common_radius && result.paired_parameters && ...
 result.seed_changes_phase && result.distinct_layouts && result.hex_sixfold>1-1e-10 && result.hex_spacing_cv<1e-10;
end
