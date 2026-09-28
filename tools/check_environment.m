function report = check_environment(probeGPU)
% Read-only preflight; never executes reconstruction.
if nargin < 1, probeGPU = false; end
root = fileparts(fileparts(mfilename('fullpath')));
report.matlab_version = version;
report.computer = computer;
report.toolboxes = ver;
names = {'imbinarize','imclose','strel','corr2','medfilt2', ...
    'gpuDeviceCount','gpuArray','gather','wrapToPi'};
report.missing_functions = {};
for k=1:numel(names)
    p = which(names{k});
    report.functions.(names{k}) = p;
    if isempty(p), report.missing_functions{end+1} = names{k}; end
end
p = fullfile(root,'data','raw','data.mat');
assert(isfile(p),'Missing author data.mat');
report.data_variables = whos('-file',p);
expected = {'amp_facet_ref','amp_far_ref_a','amp_far_ref_b','amp_far_sam','zs'};
actual = {report.data_variables.name};
assert(all(ismember(expected,actual)),'Required variables missing');
for k=1:4
    v = report.data_variables(strcmp(actual,expected{k}));
    assert(isequal(v.size,[1920 2560]) && strcmp(v.class,'double'), ...
        'Unexpected data shape or class');
end
dist = load(p,'zs');
report.zs = dist.zs;
report.gpu_status = 'not probed';
if probeGPU && ~isempty(which('gpuDeviceCount'))
    try
        report.gpu_count = gpuDeviceCount;
        report.gpu_status = 'queried';
    catch err
        report.gpu_status = err.message;
    end
end
disp(report);
if ~isempty(report.missing_functions)
    warning('Missing dependencies: %s',strjoin(report.missing_functions,', '));
end
fprintf('Preflight only; no reconstruction or numerical tests executed.\n');
end

