function run_fast_reproduction
% Author FAST demo with logging; frozen legacy files are never modified.
% Full resolution/double precision, one GPU at most, 2-hour loop wall cap.
root = fileparts(fileparts(mfilename('fullpath')));
run_id = ['author_' char(datetime('now','Format','yyyyMMdd_HHmmss'))];
out = fullfile(root,'runs','pilot',run_id);
assert(~isfolder(out),'Run directory already exists.'); mkdir(out);
oldpath = path; olddir = pwd; oldvis = get(groot,'defaultFigureVisible');
cleanup = onCleanup(@()restore_environment(oldpath,olddir,oldvis)); %#ok<NASGU>
addpath(fullfile(root,'legacy_fast'),fullfile(root,'data','raw'),fullfile(root,'tools'));
cd(out); set(groot,'defaultFigureVisible','off');
diary(fullfile(out,'matlab.log')); diary on;
max_wall_seconds = 7200; seed = 0; rng(seed,'twister');
t_all = tic; stage = 'preflight';
status_write(out,stage,0,0,toc(t_all),'running');
try
    environment = check_environment(true);
    assert(isempty(environment.missing_functions),'FAST:Dependencies','Missing author dependencies.');
    environment.gpu = [];
    if gpuDeviceCount > 0
        gd = gpuDevice;
        environment.gpu = struct('name',gd.Name,'index',gd.Index, ...
            'total_memory',gd.TotalMemory,'available_memory',gd.AvailableMemory);
    end
    save(fullfile(out,'environment.mat'),'environment','seed','max_wall_seconds');
    original = fileread(fullfile(root,'legacy_fast','main.m'));
    original = strrep(original,sprintf('\r\n'),sprintf('\n'));
    source = strrep(original,sprintf('clear;\nclose all;clc'), ...
        '% Logging wrapper retains its state and does not close user figures.');
    assert(~strcmp(source,original),'FAST:SourceChanged','Unexpected author source header.');
    marker = '%% Reconstruct the phase of the sample';
    assert(numel(strfind(source,marker))==1,'Unexpected sample boundary.');
    source = strrep(source,marker,sprintf([ ...
        'U_reference = gather(Uo); phase_reference = gather(phase_ref);\n' ...
        'calibration_seconds = toc(t_all);\n' ...
        'save(fullfile(out,''reference.mat''),''U_reference'',''phase_reference'',''mask'',''amp_cc'',''zs'',''dp'',''lambda'',''b'',''-v7.3'');\n' ...
        'clear U_reference phase_reference;\n' ...
        'stage = ''sample'';\n' marker]));
    marker = '    Uo = mean(Un,3);';
    assert(numel(strfind(source,marker))==1,'Unexpected reference loop.');
    source = strrep(source,marker,sprintf([marker '\n' ...
        '    if mod(k-1,20)==0 || k==2 || k==2501\n' ...
        '        assert(gather(all(isfinite(Uo(:)))),''FAST:Nonfinite'',''Nonfinite reference field.'');\n' ...
        '        status_write(out,''calibration'',k-1,2500,toc(t_all),''running'');\n' ...
        '    end\n' ...
        '    if mod(k-1,500)==0\n' ...
        '        checkpoint = gather(Uo);\n' ...
        '        save(fullfile(out,''calibration_checkpoint.mat''),''checkpoint'',''k'',''mask'',''-v7.3''); clear checkpoint;\n' ...
        '    end\n' ...
        '    assert(toc(t_all)<max_wall_seconds,''FAST:TimeCap'',''Two-hour wall cap reached; checkpoint retained.'');']));
    marker = '    if mod(k,10) == 0';
    assert(numel(strfind(source,marker))==1,'Unexpected sample display hook.');
    source = strrep(source,marker,sprintf([ ...
        '    assert(gather(all(isfinite(Uo(:)))),''FAST:Nonfinite'',''Nonfinite sample field.'');\n' ...
        '    status_write(out,''sample'',k-1,40,toc(t_all),''running'');\n' ...
        '    assert(toc(t_all)<max_wall_seconds,''FAST:TimeCap'',''Two-hour wall cap reached.'');\n' ...
        '    if k==40, U_sample39 = gather(Uo); end\n' marker]));
    fid=fopen(fullfile(out,'executed_main.m'),'w','n','UTF-8'); fwrite(fid,source,'char'); fclose(fid);
    copyfile(fullfile(root,'legacy_fast','VERSION.json'),fullfile(out,'source_version.json'));
    copyfile(fullfile(root,'data_manifest.json'),fullfile(out,'input_manifest.json'));
    stage = 'calibration'; eval(source);
    stage = 'export';
    % Original phase_sam is deliberately NOT recomputed: it is iteration 39.
    U_sample40 = gather(Uo); phase_ref = gather(phase_ref);
    phase_sam = gather(phase_sam); phase_target = gather(phase_target);
    phase_med_mcf = gather(phase_med_mcf); mask = gather(mask);
    phase40_raw = wrapToPi(angle(U_sample40)-phase_ref);
    phase40_display = medfilt2(wrapToPi(phase40_raw+4.1).*mask,[11 11]);
    save(fullfile(out,'sample.mat'),'U_sample39','U_sample40','phase_ref', ...
        'phase_sam','phase_target','phase_med_mcf','phase40_raw','phase40_display', ...
        'mask','zs','dp','lambda','b','N','-v7.3');
    raw = load(fullfile(root,'data','raw','data.mat'));
    ref = load(fullfile(out,'reference.mat'),'U_reference');
    metrics = struct;
    metrics.calibration_iterations = 2500; metrics.sample_iterations = 40;
    metrics.author_display_sample_iteration = 39;
    metrics.algorithm_propagations = 2500*4+40*2;
    metrics.calibration_seconds = calibration_seconds;
    metrics.mask_fraction = nnz(mask)/numel(mask);
    metrics.facet_amplitude_correlation = corr2(abs(ref.U_reference),raw.amp_facet_ref);
    metrics.reference_amplitude_nrmse_a = amplitude_error(ref.U_reference,raw.amp_far_ref_a,zs(1),dp,lambda);
    metrics.reference_amplitude_nrmse_b = amplitude_error(ref.U_reference,raw.amp_far_ref_b,zs(2),dp,lambda);
    metrics.sample_amplitude_nrmse39 = amplitude_error(U_sample39,raw.amp_far_sam,zs(1),dp,lambda);
    metrics.sample_amplitude_nrmse40 = amplitude_error(U_sample40,raw.amp_far_sam,zs(1),dp,lambda);
    metrics.sample_outside_energy_fraction40 = sum(abs(U_sample40(~mask)).^2)/sum(abs(U_sample40(:)).^2);
    dphi=angle(U_sample40.*conj(U_sample39));
    metrics.phase_change39_to40_rms_in_mask_rad=sqrt(mean(dphi(mask).^2));
    metrics.independent_phase_ground_truth_available = false;
    metrics.extra_validation_propagations = 4;
    export_map(out,'01_reference_facet_amplitude',raw.amp_facet_ref,'Reference facet amplitude','gray');
    export_map(out,'02_support_mask',mask,'Support mask','gray');
    export_map(out,'03_sample_detector_amplitude',raw.amp_far_sam,'Measured sample amplitude','gray');
    export_map(out,'04_reference_recovered_amplitude',abs(ref.U_reference),'Recovered reference amplitude','gray');
    export_map(out,'05_reference_phase',phase_ref,'Recovered reference phase (rad)','parula');
    export_map(out,'06_sample_output_amplitude40',abs(U_sample40),'Sample output amplitude, iteration 40','gray');
    export_map(out,'07_corrected_phase40_raw',phase40_raw,'Corrected phase, iteration 40 (rad)','parula');
    export_map(out,'08_author_display39',phase_med_mcf,'Author display: iteration 39, +4.1 rad, median 11x11','parula');
    export_map(out,'09_final_iteration40_display',phase40_display,'Iteration 40, same display processing','parula');
    f=figure('Visible','off'); valid_k=19:20:2499;
    plot(valid_k,amp_cc(valid_k)); xlabel('Completed reference iterations'); ylabel('Facet amplitude correlation'); grid on;
    exportgraphics(f,fullfile(out,'10_calibration_convergence.png'),'Resolution',150); close(f);
    metrics.total_seconds=toc(t_all); metrics.stop_reason='author_fixed_iteration_counts_completed';
    fid=fopen(fullfile(out,'metrics.json'),'w'); fwrite(fid,jsonencode(metrics,PrettyPrint=true),'char'); fclose(fid);
    save(fullfile(out,'metrics.mat'),'metrics');
    fast_write_run_report(out,metrics,environment);
    status_write(out,'completed',40,40,toc(t_all),'completed');
    fprintf('\nCompleted: %s\n',out); diary off;
catch err
    failure=struct('stage',stage,'identifier',err.identifier,'message',err.message, ...
        'elapsed_seconds',toc(t_all),'report',getReport(err,'extended','hyperlinks','off'));
    fid=fopen(fullfile(out,'failure.json'),'w'); fwrite(fid,jsonencode(failure,PrettyPrint=true),'char'); fclose(fid);
    status_write(out,stage,0,0,toc(t_all),'failed');
    fprintf(2,'%s\n',failure.report); diary off; rethrow(err);
end
end

function e=amplitude_error(u,a,z,dp,lambda)
p=prop(u,dp,dp,lambda,z); r=abs(p)-a;
e=norm(r(:))/norm(a(:));
end

function export_map(out,name,a,label,cmap)
f=figure('Visible','off','Color','w'); imagesc(a); axis image off;
colormap(f,cmap); colorbar; title(label,'Interpreter','none');
exportgraphics(f,fullfile(out,[name '.png']),'Resolution',150); close(f);
end

function status_write(out,stage,n,total,elapsed,state)
s=struct('stage',stage,'completed_iterations',n,'total_iterations',total, ...
    'elapsed_seconds',elapsed,'state',state,'updated',char(datetime('now')));
fid=fopen(fullfile(out,'status.json'),'w'); fwrite(fid,jsonencode(s),'char'); fclose(fid);
fprintf('[%s] %s %d/%d, %.1f seconds\n',state,stage,n,total,elapsed); drawnow;
end

function restore_environment(oldpath,olddir,oldvis)
path(oldpath); cd(olddir); set(groot,'defaultFigureVisible',oldvis);
end

