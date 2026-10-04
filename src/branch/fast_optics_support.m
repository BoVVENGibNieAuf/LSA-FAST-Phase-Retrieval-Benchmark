function [mask,info]=fast_optics_support(reference_amplitude,dx,kind)
% Reference ONLY, no sample truth; same mask supplied to every algorithm.
% FAST code uses absolute .02 on its stored amplitude scale. In this
% synthetic arm amplitude is max-normalized explicitly (an adaptation).
n=size(reference_amplitude,1); x=((0:n-1)-(n-1)/2)*dx; [xx,yy]=meshgrid(x);
a=reference_amplitude/max(reference_amplitude(:));
radius=2.2e-6; % 10 author camera pixels / M10 = 2.2 um; conditional mapping.
if strcmp(kind,'legacy_disk')
 mask=hypot(xx,yy)<=29e-6;
elseif strcmp(kind,'reference_close')
 mask=imclose(a>0.02,strel('disk',max(1,round(radius/dx)),0));
elseif strcmp(kind,'reference_threshold')
 mask=a>0.02; % ablation, NOT the author's closed support.
else
 error('FAST:Mask','Unknown support');
end
info=struct('kind',kind,'threshold_amplitude_fraction',0.02, ...
 'closing_radius_m',radius,'area_m2',nnz(mask)*dx^2, ...
 'reference_energy_excluded',sum(reference_amplitude(~mask).^2)/sum(reference_amplitude(:).^2));
end
