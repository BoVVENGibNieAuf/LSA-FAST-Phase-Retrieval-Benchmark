function H=fast_mcf_transfer(n,dx,lambda,z)
% fft2-order angular-spectrum transfer; exp(i*k*z) carrier removed.
% Forward +z uses exp(+i*kz*z). Evanescent components are excluded.
assert(mod(n,2)==0 && dx>0 && lambda>0);
f=ifftshift((-n/2:n/2-1)/(n*dx)); [fx,fy]=meshgrid(f);
q=1-lambda^2*(fx.^2+fy.^2); valid=q>=0;
H=zeros(n); H(valid)=exp(1i*(2*pi/lambda)*z*(sqrt(q(valid))-1));
end
