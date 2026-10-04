function op=fast_optics_operator(n,dx,lambda,z,NA,bin)
% Object-space ideal coherent relay of a defocused plane.
% M enters dx=p_camera/M; axial z is explicitly object-space, NOT legacy zs.
assert(mod(n,bin)==0 && mod(n,2)==0);
f=ifftshift((-n/2:n/2-1)/(n*dx)); [fx,fy]=meshgrid(f);
H=fast_mcf_transfer(n,dx,lambda,z);
pupil=hypot(fx,fy)<=NA/lambda;
op=struct('n',n,'dx',dx,'lambda',lambda,'z_object',z,'NA',NA,'bin',bin, ...
 'transfer',H.*pupil,'pupil',pupil);
end
