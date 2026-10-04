function y=fast_optics_apply(x,op,adjoint)
H=op.transfer; if adjoint, H=conj(H); end
y=ifft2(fft2(x).*H);
end
