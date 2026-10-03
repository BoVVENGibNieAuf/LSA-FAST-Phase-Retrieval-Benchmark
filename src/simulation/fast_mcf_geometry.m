function g=fast_mcf_geometry(cfg)
saved=rng; guard=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(cfg.seed,'twister');
q=ceil(cfg.patch_radius/cfg.pitch)+1; xy=zeros(0,2);
for row=-q:q
 for col=-q:q
  p=cfg.pitch*[col+0.5*mod(row,2),sqrt(3)*row/2];
  p=p+cfg.jitter_fraction*cfg.pitch*(2*rand(1,2)-1);
  if norm(p)<=cfg.patch_radius, xy(end+1,:)=p; end %#ok<AGROW>
 end
end
k=size(xy,1);
g=struct('xy',xy,'width',cfg.mode_radius*(1+cfg.mode_width_variation*(2*rand(k,1)-1)), ...
 'gain',cfg.gain_range(1)+diff(cfg.gain_range)*rand(k,1), ...
 'phase',2*pi*rand(k,1)-pi,'core_count',k);
% Pairwise distances: enforce separated cores for diagonal-mode approximation.
d=hypot(xy(:,1)-xy(:,1).',xy(:,2)-xy(:,2).'); d(1:k+1:end)=Inf;
g.minimum_spacing=min(d(:));
assert(g.minimum_spacing>cfg.core_diameter_nominal,'FAST:Geometry','Overlapping nominal cores');
assert(max(hypot(xy(:,1),xy(:,2))+cfg.mode_truncation_radii*g.width)<cfg.support_radius);
end
