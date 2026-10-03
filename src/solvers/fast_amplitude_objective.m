function [f,g]=fast_amplitude_objective(x,amplitude,mask,H,epsilon)
% Supported complex field represented by [real;imag]. Two propagations/call.
% Smooth amplitude residual: .5*sum((sqrt(|P u|^2+eps^2)-a).^2).
% Inputs are scaled by detector RMS by the caller; no regularization/prior.
idx=logical(mask); n=nnz(idx); assert(numel(x)==2*n);
u=complex(zeros(size(mask))); u(idx)=complex(x(1:n),x(n+1:end));
v=ifft2(fft2(u).*H); mag=sqrt(abs(v).^2+epsilon^2); residual=mag-amplitude;
f=0.5*sum(residual(:).^2);
w=ifft2(fft2((residual./mag).*v).*conj(H));
g=[real(w(idx));imag(w(idx))];
end
