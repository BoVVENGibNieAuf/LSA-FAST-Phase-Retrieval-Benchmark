function bank=fast_mcf_layout_bank(rawpath,out)
% Detect core centroids from the public reference AMPLITUDE image.
% Geometry selection uses the reference alone, before any reconstruction.
assert(isfile(rawpath),'FAST:MissingData','Public data/raw/data.mat required');
d=load(rawpath,'amp_facet_ref'); A=double(d.amp_facet_ref);
assert(ismatrix(A)&&all(isfinite(A(:)))&&max(A(:))>0);
B=imgaussfilt(A,1); peak=max(B(:));
[y,x]=find(B>0.10*peak); center=[mean(x) mean(y)];
cx=round(center(1)); cy=round(center(2)); half=256;
xr=max(1,cx-half):min(size(A,2),cx+half); yr=max(1,cy-half):min(size(A,1),cy+half);
patch=B(yr,xr); background=imopen(patch,strel('disk',7,0));
candidate=imregionalmax(patch)&patch>0.12*peak&(patch-background)>0.05*peak;
candidate([1:8 end-7:end],:)=false; candidate(:,[1:8 end-7:end])=false;
[py,px]=find(candidate); val=patch(candidate); [~,order]=sort(val,'descend');
points=zeros(0,2); brightness=[];
for k=reshape(order,1,[])
 p=[px(k) py(k)];
 if ~isempty(points)&&min(vecnorm(points-p,2,2))<6, continue; end
 ix=p(1)+(-3:3); iy=p(2)+(-3:3); weights=max(patch(iy,ix)-background(iy,ix),0);
 [xx,yy]=meshgrid(ix,iy); p=[sum(xx.*weights,'all') sum(yy.*weights,'all')]/sum(weights,'all');
 if ~isempty(points)&&min(vecnorm(points-p,2,2))<6, continue; end
 points(end+1,:)=p; brightness(end+1,1)=val(k); %#ok<AGROW>
end
points=points+[xr(1)-1 yr(1)-1];
% A six-ring hexagon contains 127 cores, chosen before image processing.
ncores=127; radius=19.2e-6; pitch=3.2e-6;
assert(size(points,1)>=ncores,'FAST:CoreDetection','Fewer than 127 reference cores detected');
[~,order]=sort(vecnorm(points-center,2,2)); chosen=order(1:ncores);
measured_pixels=points(chosen,:); measured=measured_pixels-mean(measured_pixels,1);
scale=radius/max(vecnorm(measured,2,2)); measured=measured*scale;
hex=zeros(0,2);
for q=-6:6
 for r=-6:6
  if max(abs([q r q+r]))<=6, hex(end+1,:)=pitch*[q+r/2 sqrt(3)*r/2]; end %#ok<AGROW>
 end
end
assert(size(hex,1)==ncores);
saved=rng; guard=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(71003,'twister'); jitter=hex+0.12*pitch*(2*rand(size(hex))-1);
jitter=jitter-mean(jitter,1); jitter=jitter*radius/max(vecnorm(jitter,2,2));
% Stable radial/angular indexing for paired per-core mode and phase draws.
layouts={'hex','jitter','measured'}; coordinates={hex,jitter,measured};
bank=struct('labels',{layouts},'coordinates',{coordinates},'core_count',ncores, ...
 'radius',radius,'source_pixels',measured_pixels,'detected_pixels',points, ...
 'selected_brightness',brightness(chosen),'image_center_pixels',center, ...
 'synthetic_meters_per_source_pixel',scale,'source_path',rawpath, ...
 'selection','127 closest detected cores to fixed reference bright-region centroid', ...
 'scale_policy','uniform rescale of measured patch to common 19.2um outer core radius', ...
 'detector_settings',struct('smooth_sigma_pixels',1,'min_separation_pixels',6, ...
 'amplitude_fraction',0.12,'prominence_fraction',0.05,'background_disk_pixels',7));
bank.stats=repmat(stats(hex),1,3);
for j=1:3
 xy=coordinates{j}; [~,o]=sortrows([vecnorm(xy,2,2),atan2(xy(:,2),xy(:,1))],[1 2]); xy=xy(o,:);
 bank.coordinates{j}=xy; bank.stats(j)=stats(xy);

end
save(fullfile(out,'layout_detection_candidate.mat'),'bank');
f=figure('Visible','off'); c=onCleanup(@()close(f)); %#ok<NASGU>
subplot(1,2,1); imagesc(xr,yr,A(yr,xr)); axis image; colormap gray; hold on;
plot(points(:,1),points(:,2),'c.'); plot(measured_pixels(:,1),measured_pixels(:,2),'ro','MarkerSize',4);
xlim([min(xr) max(xr)]); ylim([min(yr) max(yr)]); title('Detected cores (cyan), selected 127 (red)');
subplot(1,2,2); imagesc(xr,yr,A(yr,xr)); axis image; hold on;
plot(measured_pixels(:,1),measured_pixels(:,2),'ro','MarkerSize',6);
xlim([min(measured_pixels(:,1))-10 max(measured_pixels(:,1))+10]);
ylim([min(measured_pixels(:,2))-10 max(measured_pixels(:,2))+10]); title('Selected patch: check for merged/missed cores');
set(f,'Position',[50 50 1400 650]); exportgraphics(f,fullfile(out,'core_detection_overlay.png'),'Resolution',180);
f2=figure('Visible','off'); c2=onCleanup(@()close(f2)); %#ok<NASGU>
for j=1:3
 subplot(1,3,j); xy=bank.coordinates{j}; scatter(xy(:,1)*1e6,xy(:,2)*1e6,14,'filled');
 axis equal; xlim([-22 22]); ylim([-22 22]); title(sprintf('%s: 127 cores, NN CV %.3f',layouts{j},bank.stats(j).spacing_cv));
 xlabel('um'); ylabel('um');
end
set(f2,'Position',[50 50 1350 450]); exportgraphics(f2,fullfile(out,'layout_comparison.png'),'Resolution',150);
for j=1:3
 assert(bank.stats(j).minimum_spacing>1.6e-6,'FAST:CoreDetection','Unresolved close peaks: inspect saved overlay');
 assert(bank.stats(j).minimum_spacing/bank.stats(j).median_spacing>0.55, ...
  'FAST:CoreDetection','Possible duplicate peaks: inspect saved overlay');
end
save(fullfile(out,'layout_bank.mat'),'bank');
end
function s=stats(xy)
n=size(xy,1); D=hypot(xy(:,1)-xy(:,1).',xy(:,2)-xy(:,2).'); D(1:n+1:end)=Inf;
[nn,idx]=min(D,[],2); delta=xy(idx,:)-xy; theta=atan2(delta(:,2),delta(:,1));
s=struct('minimum_spacing',min(nn),'median_spacing',median(nn),'spacing_cv',std(nn)/mean(nn), ...
 'global_sixfold_order',abs(mean(exp(6i*theta))),'max_radius',max(vecnorm(xy,2,2)));
end
