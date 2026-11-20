function a = asta_statistics(p, t, w)
  % Time/peak metrics are sampled estimates; grids are returned for audit.
  m = asta_models(p);
  if nargin < 2 || isempty(t), [~, t] = step(m.Y); end
  if nargin < 3 || isempty(w), w = logspace(-5,5,20000); end
  a = struct();
  a.closed_loop_stable = m.closed_loop_stable;
  [gm,pm,wg,wp] = margin(m.L);
  a.gain_margin = gm; a.gain_margin_db = 20*log10(gm);
  a.phase_margin_deg = pm; a.gain_margin_frequency = wg;
  a.phase_margin_frequency = wp;
  a.delay_margin_s = NaN;
  if m.closed_loop_stable && isfinite(pm) && pm > 0 && isfinite(wp) && wp > 0
    a.delay_margin_s = (pm*pi/180)/wp;
  end
  for key = {'S','T','W'}
    f = asta_frequency(p,key{1},w);
    if strcmp(key{1},'T'), tfrequency=f; end
    [peak,j] = max(f.magnitude);
    a.([key{1} '_peak']) = peak; a.([key{1} '_peak_db']) = 20*log10(peak);
    a.([key{1} '_peak_frequency']) = f.w(j);
    a.([key{1} '_peak_at_grid_boundary']) = j == 1 || j == numel(w);
  end
  a.T_dc = dcgain(m.T);
  a.T_dc_db = 20*log10(abs(a.T_dc));
  a.resonance_ratio = a.T_peak / abs(a.T_dc);
  a.resonance_ratio_db = 20*log10(a.resonance_ratio);
  f = tfrequency;
  a.bandwidth_3db = NaN;
  threshold = abs(a.T_dc)/sqrt(2);
  j = find(f.magnitude <= threshold,1);
  if j > 1 && isfinite(threshold) && threshold > 0
    a.bandwidth_3db = exp(interp1(f.db(j-1:j),log(f.w(j-1:j)),20*log10(threshold)));
  end
  r = asta_response(p,'Y',t);
  a.time = time_metrics(r, m.Y, m.closed_loop_stable);
  u = asta_response(p,'U',t);
  a.control_peak_abs = max(abs(u.y));
  a.time_grid = r.t; a.frequency_grid = w(:);
end

function a = time_metrics(r,h,stable)
  a = struct('final_value', NaN, 'static_error_percent', NaN, ...
     'maximum_output', max(r.y), 'minimum_output', min(r.y), ...
     'peak', NaN, 'peak_time', NaN, ...
     'overshoot_percent', NaN, 'rise_time_10_90', NaN, ...
     'settling_time_5_percent', NaN, 'settling_time_2_percent', NaN, ...
     'settling_is_observed_estimate', true);
  if ~stable || ~isstable(h), return; end
  final = dcgain(h); a.final_value = final;
  if isfinite(final), a.static_error_percent = 100*(1-final); end
  if ~isfinite(final) || final == 0, return; end
  z = r.y / final;
  [peak,j] = max(z); a.peak = r.y(j); a.peak_time = r.t(j);
  a.overshoot_percent = max(0,(peak-1)*100);
  t10 = crossing(r.t,z,0.1); t90 = crossing(r.t,z,0.9);
  a.rise_time_10_90 = t90-t10;
  a.settling_time_5_percent = settling(r.t,z,0.05);
  a.settling_time_2_percent = settling(r.t,z,0.02);
end
function v = crossing(t,y,level)
  j = find(y >= level,1); v = NaN;
  if isempty(j), return; end
  if j == 1, v = t(1); else, v = interp1(y(j-1:j),t(j-1:j),level); end
end
function v = settling(t,y,tol)
  j = find(abs(y-1)>tol,1,'last');
  if isempty(j), v = t(1); elseif j == numel(t), v = NaN; else, v = t(j+1); end
end
