function y=fast_optics_project(v,a,b)
% Projection onto measured block norms BEFORE the pupil-range constraint.
mag=sqrt(fast_optics_bin(abs(v).^2,b));
ratio=zeros(size(mag)); positive=mag>0; ratio(positive)=a(positive)./mag(positive);
y=v.*repelem(ratio,b,b);
zero=(mag==0);
if any(zero(:))
 fill=repelem(zero.*(a/b),b,b); y=y+fill;
end
end
