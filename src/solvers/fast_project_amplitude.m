function v = fast_project_amplitude(u, amplitude)
% Common amplitude projection. At u=0 choose phase 0 (documented convention).
% A separately versioned numerical safeguard; frozen author code is unchanged.
v = amplitude .* exp(1i*angle(u));
end
