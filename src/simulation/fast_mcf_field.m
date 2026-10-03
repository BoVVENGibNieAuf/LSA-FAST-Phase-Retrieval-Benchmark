function [u,coeff]=fast_mcf_field(cfg,g,n,dx,scene,coeff)
% Normalized scalar modes psi=sqrt(2/pi)/w * exp(-r^2/w^2).
% Coupling is integral of incident object field times conjugate(psi).
% Optional coefficients permit identical coupling on multiple output grids.
x=((0:n-1)-(n-1)/2)*dx; u=complex(zeros(n));
calculate=nargin<6;
if calculate, coeff=complex(zeros(g.core_count,1)); end
for j=1:g.core_count
 w=g.width(j); rmax=cfg.mode_truncation_radii*w;
 ix=find(abs(x-g.xy(j,1))<=rmax); iy=find(abs(x-g.xy(j,2))<=rmax);
 [xx,yy]=meshgrid(x(ix),x(iy)); r2=(xx-g.xy(j,1)).^2+(yy-g.xy(j,2)).^2;
 psi=sqrt(2/pi)/w*exp(-r2/w^2).*(r2<=rmax^2);
 if calculate
  xn=xx/cfg.patch_radius; yn=yy/cfg.patch_radius; a=ones(size(xx));
  switch scene
   case 'blank', phi=zeros(size(xx));
   case 'step', phi=0.8*double(xx>0);
   case 'smooth', phi=0.8*exp(-((xn+0.15).^2+(yn-0.1).^2)/0.12);
   case 'mixed'
    phi=0.55*sin(3*pi*xn).*cos(2*pi*yn);
    a=0.55+0.45*exp(-(xn.^2+yn.^2)/0.20);
   otherwise, error('FAST:Scene','Unknown MCF scene');
  end
  coeff(j)=sum(a.*exp(1i*phi).*psi,'all')*dx^2;
 end
 u(iy,ix)=u(iy,ix)+g.gain(j)*exp(1i*g.phase(j))*coeff(j)*psi;
end
end
