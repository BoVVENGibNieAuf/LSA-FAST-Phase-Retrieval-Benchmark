function [f,g]=fast_optics_objective(x,a,mask,op,epsilon)
% Exact gradient of pixel-INTEGRATED amplitude likelihood surrogate.
% Still an amplitude LS objective, NOT a Poisson likelihood.
idx=logical(mask); n=nnz(idx); u=complex(zeros(size(mask)));
u(idx)=complex(x(1:n),x(n+1:end)); v=fast_optics_apply(u,op,false);
mag=sqrt(fast_optics_bin(abs(v).^2,op.bin)+epsilon^2);
r=mag-a; f=0.5*sum(r(:).^2);
w=fast_optics_apply(v.*repelem(r./mag,op.bin,op.bin),op,true);
g=[real(w(idx));imag(w(idx))];
end
