function asta_validate(p)
  pkg load control;
  if ~isstruct(p) || ~all(isfield(p, {'G','K','R'}))
    error('ASTA:project', 'Project must contain G, K and R.');
  end
  for key = {'G','K','R'}
    h = p.(key{1});
    if ~isa(h, 'lti') || ~isequal(size(h), [1 1]) || get(h, 'tsam') ~= 0
      error('ASTA:model', '%s must be a continuous-time SISO model.', key{1});
    end
    [n,d] = tfdata(tf(h), 'vector');
    if any(~isfinite([n d])) || ~any(d)
      error('ASTA:coefficients', 'Coefficients must be finite with nonzero denominator.');
    end
  end
end
