function out=fast_mcf_pixel_average(intensity,factor)
% Detector integrates INTENSITY, then divides by pixel area (mean units).
[n,m]=size(intensity); assert(mod(n,factor)==0 && mod(m,factor)==0);
a=reshape(intensity,factor,n/factor,factor,m/factor);
out=reshape(mean(mean(a,1),3),n/factor,m/factor);
end
