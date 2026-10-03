function [amplitude,info,counts]=fast_mcf_noise_camera(intensity,exposure,readSigma,seed)
% Exact Poisson sampling: product method below 10, Hormann PTRS above.
% Same camera units and negative-readout clipping as the previous pilot.
mu=intensity*exposure;
assert(all(isfinite(mu(:)))&&all(mu(:)>=0)&&exposure>0&&readSigma>=0&&max(mu(:))<1e12);
saved=rng; cleanup=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(seed,'twister'); counts=zeros(size(mu));
active=find(mu>0 & mu<10); product=ones(size(active)); threshold=exp(-mu(active));
while ~isempty(active)
 product=product.*rand(size(active)); keep=product>threshold;
 counts(active(keep))=counts(active(keep))+1;
 active=active(keep); product=product(keep); threshold=threshold(keep);
end
active=find(mu>=10); steps=0;
while ~isempty(active)
 steps=steps+1; assert(steps<10000,'FAST:Poisson','Poisson rejection loop exceeded bound');
 lam=mu(active); b=0.931+2.53*sqrt(lam); a=-0.059+0.02483*b;
 invAlpha=1.1239+1.1328./(b-3.4); vr=0.9277-3.6224./(b-2);
 u=rand(size(active))-0.5; v=rand(size(active)); us=max(0.5-abs(u),realmin);
 k=floor((2*a./us+b).*u+lam+0.43);
 accepted=k>=0 & us>=0.07 & v<=vr;
 test=~accepted & k>=0 & ~(us<0.013 & v>us);
 accepted(test)=log(v(test).*invAlpha(test)./(a(test)./us(test).^2+b(test))) <= ...
  -lam(test)+k(test).*log(lam(test))-gammaln(k(test)+1);
 counts(active(accepted))=k(accepted); active=active(~accepted);
end
readout=counts+readSigma*randn(size(mu)); clipped=max(readout,0);
amplitude=sqrt(clipped/exposure);
dark=mu<0.1;
info=struct('sampler','Poisson product/PTRS','seed',seed,'exposure',exposure, ...
 'read_sigma_electrons',readSigma,'expected_total_electrons',sum(mu(:)), ...
 'mean_expected_electrons',mean(mu(:)),'peak_expected_electrons',max(mu(:)), ...
 'clipped_fraction',mean(readout(:)<0),'clipping_added_electrons',sum(clipped(:)-readout(:)), ...
 'dark_pixel_fraction',mean(dark(:)),'dark_expected_total',sum(mu(dark)), ...
 'dark_clipped_total',sum(clipped(dark)));
end
