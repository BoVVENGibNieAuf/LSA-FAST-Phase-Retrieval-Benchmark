function audit=fast_mcf_noise_generate(out,truthdir,cfg)
% Reuse frozen geometry, fields and integrated clean measurements.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
source=fullfile(root,'runs','pilot',cfg.source_run_id);
manifest=jsondecode(fileread(fullfile(source,'data_manifest.json')));
for label={'blank_clean','mixed_clean'}
 m=manifest(strcmp({manifest.case},label{1})); assert(numel(m)==1);
 assert(strcmp(digest(fullfile(source,[label{1} '_input.mat'])),m.input_sha256));
end
m=manifest(strcmp({manifest.case},'mixed_clean'));
p=fullfile(root,'evaluation_only',cfg.source_run_id,'mixed_truth.mat');
assert(strcmp(digest(p),m.truth_sha256)); copyfile(p,fullfile(truthdir,'mixed_truth.mat'));
blank=load(fullfile(source,'blank_clean_input.mat'),'amplitude');
d=load(fullfile(source,'mixed_clean_input.mat'));
exposure=cfg.reference_photons/sum(blank.amplitude(:).^2);
[amplitude,camera]=fast_mcf_noise_camera(d.amplitude.^2,exposure,cfg.read_noise_electrons,cfg.noise_seed);
mask=d.mask; calibration=d.calibration; %#ok<NASGU>
save(fullfile(out,'mixed_shot_read_input.mat'),'amplitude','mask','calibration','camera');
audit=jsondecode(fileread(fullfile(source,'generation_audit.json')));
audit.generation_propagations=0; audit.source_run_id=cfg.source_run_id;
audit.source_generation_reused=true; audit.reference_photons=cfg.reference_photons;
audit.exposure_electrons_per_intensity=exposure; audit.camera=camera;
copyfile(fullfile(source,'MCF_model.png'),fullfile(out,'MCF_model.png'));
f=fopen(fullfile(out,'camera_audit.json'),'w'); assert(f>=0); guard=onCleanup(@()fclose(f)); %#ok<NASGU>
fwrite(f,jsonencode(camera,'PrettyPrint',true),'char');
end
function h=digest(p)
f=fopen(p,'rb'); assert(f>=0); cleanup=onCleanup(@()fclose(f)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(f), b=fread(f,1048576,'*uint8'); d.update(typecast(b,'int8')); end
h=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
