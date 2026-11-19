function m = asta_measure(r, x1, x2)
  % Nearest sampled points by time or omega; frequency ratios use magnitudes.
  if isfield(r,'t'), x = r.t; else, x = r.w; end
  if any(~isfinite([x1 x2])) || any([x1 x2] < min(x)) || any([x1 x2] > max(x))
    error('ASTA:measurement','Points must lie in the sampled range.');
  end
  [~,a] = min(abs(x-x1)); [~,b] = min(abs(x-x2));
  m = struct('x1',x(a),'x2',x(b),'delta_x',x(b)-x(a));
  if isfield(r,'t')
    m.y1 = r.y(a); m.y2 = r.y(b); m.delta_y = r.y(b)-r.y(a);
  else
    m.gain_ratio = r.magnitude(b)/r.magnitude(a);
    m.delta_db = r.db(b)-r.db(a); m.delta_phase_deg = r.phase(b)-r.phase(a);
    m.response1 = r.response(a); m.response2 = r.response(b);
  end
end
