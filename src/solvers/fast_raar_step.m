function next=fast_raar_step(u,v,mask,beta)
% Luke (2005), beta/2*(R_S R_M + I) + (1-beta)*P_M.
% v=P_M(u); S is complex support ONLY, with no positivity constraint.
rM=2*v-u;
rSrM=2*mask.*rM-rM;
next=beta/2*(rSrM+u)+(1-beta)*v;
end
