function bank=fast_mcf_circular_bank(cfg,out)
% Synthetic circular facets. Core packing, physical facet and support differ.
q=ceil(cfg.patch_radius/cfg.pitch)+1; xy=zeros(0,2);
for row=-q:q
 for col=-q:q
  v=cfg.pitch*[col+0.5*mod(row,2),sqrt(3)*row/2];
  if norm(v)<=cfg.patch_radius, xy(end+1,:)=v; end %#ok<AGROW>
 end
end
n=size(xy,1); saved=rng; guard=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(20261031,'twister'); random=zeros(n,2); accepted=0;
for trial=1:200000
 r=cfg.patch_radius*sqrt(rand); theta=2*pi*rand; v=r*[cos(theta),sin(theta)];
 if accepted==0 || all(vecnorm(random(1:accepted,:)-v,2,2)>=2.4e-6)
  accepted=accepted+1; random(accepted,:)=v;
  if accepted==n, break; end
 end
end
assert(accepted==n,'FAST:Packing','Failed fixed-seed constrained packing');
bank=struct('labels',{{'periodic','aperiodic'}},'coordinates',{{xy,random}}, ...
 'core_count',n,'stats',struct([]),'geometry_seed',20261031, ...
 'facet_radius',cfg.facet_radius,'support_radius',cfg.support_radius, ...
 'scope','synthetic circular facets, not measured fiber specifications');
for j=1:2
 v=bank.coordinates{j}; d=hypot(v(:,1)-v(:,1).',v(:,2)-v(:,2).'); d(1:n+1:end)=Inf;
 bank.stats(j).minimum_spacing=min(d(:));
 assert(bank.stats(j).minimum_spacing>cfg.core_diameter_nominal);
 assert(all(vecnorm(v,2,2)+cfg.core_diameter_nominal/2<cfg.facet_radius));
 assert(all(vecnorm(v,2,2)+3*cfg.mode_radius*(1+cfg.mode_width_variation)<cfg.facet_radius));
end
save(fullfile(out,'layout_bank.mat'),'bank');
f=figure('Visible','off'); c=onCleanup(@()close(f)); %#ok<NASGU>
t=linspace(0,2*pi,500);
for j=1:2
 subplot(1,2,j); hold on; v=bank.coordinates{j};
 for k=1:n
  plot((v(k,1)+cfg.core_diameter_nominal/2*cos(t))*1e6, ...
   (v(k,2)+cfg.core_diameter_nominal/2*sin(t))*1e6,'b-','HandleVisibility','off');
 end
 plot(cfg.facet_radius*cos(t)*1e6,cfg.facet_radius*sin(t)*1e6,'k-','DisplayName','Physical facet');
 plot(cfg.support_radius*cos(t)*1e6,cfg.support_radius*sin(t)*1e6,'r--','DisplayName','Solver support');
 axis equal; grid on; xlabel('um'); ylabel('um'); legend('Location','southoutside');
 title(sprintf('%s / %d cores',bank.labels{j},n));
end
set(f,'Position',[50 50 1050 550]); exportgraphics(f,fullfile(out,'circular_geometry.png'),'Resolution',160);
end
