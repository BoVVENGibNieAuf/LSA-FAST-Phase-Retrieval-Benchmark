function [nrmse, phase_rmse, theta] = fast_field_error(recon, reference, mask)
% Synthetic/reference-only scorer. No gain fit, tilt removal or pixel shifts.
assert(any(mask(:)) && norm(reference(mask))>0,'Invalid reference ROI');
a = reference(mask); b = recon(mask);
theta = angle(sum(conj(a).*b));
b = b.*exp(-1i*theta);
nrmse = norm(b-a)/norm(a);
phase_rmse = sqrt(mean(angle(b.*conj(a)).^2));
end
