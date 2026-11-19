function r = asta_response(p, channel, t, u)
  % channel: G (open loop), Y (closed loop), U (control), reference, S/T/W/L.
  m = asta_models(p);
  if ~isfield(m, channel) || ~isa(m.(channel), 'lti'), error('ASTA:channel', 'Unknown channel.'); end
  h = m.(channel);
  if nargin < 3 || isempty(t), [~, t] = step(h); end
  t = t(:);
  if numel(t) < 2 || any(~isfinite(t)) || t(1) ~= 0 || any(diff(t) <= 0) || ...
     max(abs(diff(t)-mean(diff(t)))) > 1e-8*max(1,mean(diff(t)))
    error('ASTA:time', 'Time must start at zero and be finite, increasing, and uniformly spaced.');
  end
  if nargin < 4
    [y, tout] = step(h,t);
  else
    u = u(:);
    if numel(u) ~= numel(t) || any(~isfinite(u)), error('ASTA:input', 'Input must match the time vector.'); end
    [y, tout] = lsim(h,u,t);
  end
  r = struct('t', tout(:), 'y', y(:), 'channel', channel, 'project', p);
end
