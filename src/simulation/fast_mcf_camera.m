function [amplitude,info]=fast_mcf_camera(intensity,exposure,readSigma,seed)
% Exact Poisson product sampler, bounded peak <=650 photoelectrons.
% Avoids a Statistics Toolbox dependency; negative readouts clip before sqrt.
assert(all(isfinite(intensity(:))) && all(intensity(:)>=0));
mu=intensity*exposure; assert(max(mu(:))<=650 && exposure>0 && readSigma>=0);
saved=rng; guard=onCleanup(@()rng(saved)); %#ok<NASGU>
rng(seed,'twister');
counts=zeros(size(mu)); product=ones(size(mu)); threshold=exp(-mu);
active=find(mu>0);
while ~isempty(active)
 product(active)=product(active).*rand(size(active));
 active=active(product(active)>threshold(active));
 counts(active)=counts(active)+1;
end
readout=counts+readSigma*randn(size(mu));
info=struct('exposure',exposure,'peak_mean_electrons',max(mu(:)), ...
 'read_sigma_electrons',readSigma,'seed',seed,'clipped_fraction',mean(readout(:)<0));
amplitude=sqrt(max(readout,0)/exposure);
end
