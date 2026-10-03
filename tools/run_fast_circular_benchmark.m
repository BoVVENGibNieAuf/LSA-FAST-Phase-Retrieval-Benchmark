function run_fast_circular_benchmark
% Self-contained synthetic benchmark; no raw author data download required.
root=fileparts(fileparts(mfilename('fullpath'))); setup_project;
addpath(fullfile(root,'src','simulation'));
pilot=fullfile(root,'runs','pilot'); if ~isfolder(pilot), mkdir(pilot); end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
out=fullfile(pilot,['circular_' stamp]); mkdir(out);
put(fullfile(out,'status.json'),struct('state','running','stage','geometry'));
try
cfg=fast_mcf_config; cfg.patch_radius=22e-6; cfg.facet_radius=26e-6;
cfg.support_radius=29e-6; cfg.reference_power=1e-9; cfg.reference_photons=200000;
cfg.scenes={'mixed'}; cfg.geometry='synthetic full circular facet; explicit cladding disk';
bank=fast_mcf_circular_bank(cfg,out);
assert(bank.core_count==163,'FAST:CircularCount','Unexpected circular lattice count');
cfg.layout_bank=fullfile(out,'layout_bank.mat'); cfg.layout_bank_sha256=filehash(cfg.layout_bank);
geometry_checks=struct('core_count',bank.core_count,'passed',true,'outside_facet_energy',zeros(1,2));
for j=1:2
 cfg.layout=bank.labels{j}; g=fast_mcf_layout_geometry(cfg);
 u=fast_mcf_field(cfg,g,cfg.n,cfg.dx,'blank');
 x=((0:cfg.n-1)-(cfg.n-1)/2)*cfg.dx; [xx,yy]=meshgrid(x);
 geometry_checks.outside_facet_energy(j)=sum(abs(u(hypot(xx,yy)>cfg.facet_radius)).^2);
 assert(geometry_checks.outside_facet_energy(j)==0,'FAST:FacetLeak','Field outside physical facet');
end
put(fullfile(out,'geometry_checks.json'),geometry_checks);
put(fullfile(out,'protocol.json'),struct('state','frozen_before_solver_results', ...
 'scope','engineering pilot; one fixed paired transmission seed; no hyperparameter search', ...
 'geometry_seed',bank.geometry_seed,'transmission_seed',cfg.seed, ...
 'layouts',{bank.labels},'core_count',bank.core_count,'facet_radius_m',cfg.facet_radius, ...
 'support_radius_m',cfg.support_radius,'reference_photons',cfg.reference_photons, ...
 'independent_measured_reference',false,'test_split','not a generalization study', ...
 'failure_rule','retain all failed runs; do not rank incomplete methods'));
put(fullfile(out,'status.json'),struct('state','running','stage','input_generation'));
 sources=cell(1,2);
 for j=1:2
  cfg.layout=bank.labels{j}; cfg.version='circular-mcf-v1';
  cfg.run_id=sprintf('mcf_%s_%02d',stamp,j);
  sources{j}=run_fast_mcf_pilot('',cfg);
 end
 four=fast_four_solver_config; four.source_runs=sources; four.layouts=bank.labels;
 four.version='circular-four-solvers-v2'; four.scope='synthetic periodic and aperiodic circular facets';
 id=run_fast_four_solvers('',four);
 put(fullfile(out,'status.json'),struct('state','completed','source_runs',{sources},'four_run',id));
 put(fullfile(root,'runs','latest_circular.json'),struct('batch',['circular_' stamp],'four_run',id,'source_runs',{sources}));
 fprintf('CIRCULAR_BENCHMARK_COMPLETE: %s\n',id);
catch err
 put(fullfile(out,'status.json'),struct('state','failed','message',err.message));
 rethrow(err)
end
end
function put(p,v)
f=fopen(p,'w','n','UTF-8'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,unicode2native(jsonencode(v,'PrettyPrint',true),'UTF-8'),'uint8');
end
function h=filehash(p)
f=fopen(p,'rb'); assert(f>=0); c=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
