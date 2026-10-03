function g=fast_mcf_layout_geometry(cfg)
b=load(cfg.layout_bank,'bank'); b=b.bank;
j=find(strcmp(b.labels,cfg.layout)); assert(numel(j)==1);
saved=rng; c=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(cfg.seed,'twister'); n=b.core_count;
g=struct('xy',b.coordinates{j},'width',cfg.mode_radius*(1+cfg.mode_width_variation*(2*rand(n,1)-1)), ...
 'gain',cfg.gain_range(1)+diff(cfg.gain_range)*rand(n,1),'phase',2*pi*rand(n,1)-pi, ...
 'core_count',n,'minimum_spacing',b.stats(j).minimum_spacing,'layout',cfg.layout);
assert(max(vecnorm(g.xy,2,2)+3*g.width)<cfg.support_radius);
end
