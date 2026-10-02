function u = fast_support_step(old, candidate, mask, method, beta)
switch method
    case 'HIO'
        u = mask.*candidate + (1-mask).*(old-beta*candidate);
    case 'ER'
        u = mask.*candidate;
    otherwise
        error('FAST:Method','Unknown method: %s',method);
end
end
