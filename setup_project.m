function root = setup_project()
% Session-local paths; frozen inputs and evaluation truth are excluded.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src','operators'),fullfile(root,'src','solvers'), ...
    fullfile(root,'src','metrics'),fullfile(root,'configs'), ...
    fullfile(root,'tools'),fullfile(root,'tests'));
fprintf('FAST project: %s\nRun env = check_environment; next.\n',root);
end

