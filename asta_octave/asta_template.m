function h = asta_template(kind, varargin)
  % gain(k), integrator(k), first(k,tau), second(k,wn,zeta), leadlag(k,tz,tp)
  pkg load control;
  a = varargin;
  if any(~cellfun(@(v) isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v), a))
    error('ASTA:template', 'Template parameters must be finite real scalars.');
  end
  switch lower(kind)
    case 'gain', h = tf(a{1});
    case 'integrator', h = tf(a{1}, [1 0]);
    case 'first'
      assert(a{2} > 0, 'Time constant must be positive.'); h = tf(a{1}, [a{2} 1]);
    case 'second'
      assert(a{2} > 0 && a{3} >= 0, 'Invalid frequency or damping.');
      h = tf(a{1}*a{2}^2, [1 2*a{3}*a{2} a{2}^2]);
    case 'leadlag'
      assert(a{2} >= 0 && a{3} > 0, 'Invalid time constants.');
      h = tf(a{1}*[a{2} 1], [a{3} 1]);
    otherwise, error('ASTA:template', 'Unknown template: %s', kind);
  end
end
