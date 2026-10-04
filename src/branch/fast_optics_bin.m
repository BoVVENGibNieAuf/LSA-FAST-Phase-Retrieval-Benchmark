function y=fast_optics_bin(x,b)
% SUM of intensity over detector pixels, never coherent field averaging.
n=size(x,1); assert(size(x,2)==n && mod(n,b)==0);
y=reshape(sum(sum(reshape(x,b,n/b,b,n/b),1),3),n/b,n/b);
end
