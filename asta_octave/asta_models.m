function m = asta_models(p)
  % Unity negative feedback, with a reference precompensator R.
  key={p.G,p.K,p.R};
  m=asta_model_cache('get',key);
  if ~isempty(m), return; end
  asta_validate(p);
  m.G = p.G; m.K = p.K; m.R = p.R;
  m.L = p.K * p.G;
  m.S = feedback(tf(1), m.L);
  m.T = feedback(m.L, tf(1));
  m.W = feedback(p.K, p.G); % magnitude of sensor noise -> control (signed map is -W)
  m.Y = p.R * m.T;
  m.U = p.R * m.W;
  m.reference = p.R;
  m.noise_to_control = -m.W;
  % Keep unreduced internal dynamics to avoid hiding unstable cancellations.
  m.internal_closed_loop = feedback(ss(p.G), ss(p.K));
  m.closed_loop_stable = isstable(m.internal_closed_loop);
  asta_model_cache('put',key,m);
end
