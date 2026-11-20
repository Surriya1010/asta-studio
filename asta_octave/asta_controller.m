function [K, R] = asta_controller(kind, P, Ti, Td, tau)
  % Standard ideal-form PI/PID, with filtered derivative when tau > 0.
  % pd-output / pid-output put derivative on measured output, not error.
  % Lag: asta_controller('lag', P, Tzero, beta), beta>1, Tzero>0.
  % K = P*(1+Tzero*s)/(1+beta*Tzero*s); R = 1.
  pkg load control;
  if nargin < 2, P = 1; end
  if nargin < 3, Ti = 1; end
  if nargin < 4, Td = 0; end
  if nargin < 5, tau = 0; end
  if ~isscalar(P) || ~isreal(P) || ~isfinite(P), error('ASTA:P', 'P must be finite and real.'); end
  if strcmpi(kind,'lag')
    if ~isscalar(Ti) || ~isreal(Ti) || ~isfinite(Ti) || Ti<=0
      error('ASTA:lag','Zero time Tz must be finite and positive.');
    end
    if ~isscalar(Td) || ~isreal(Td) || ~isfinite(Td) || Td<=1
      error('ASTA:lag','Lag ratio beta must be finite and greater than 1.');
    end
    if ~isfinite(Td*Ti) || ~isfinite(P*Ti)
      error('ASTA:lag','Lag coefficients overflowed. Reduce the gain or time constant.');
    end
    K=P*tf([Ti 1],[Td*Ti 1]); R=tf(1); return;
  end
  if ~isscalar(Ti) || ~isreal(Ti) || ~isfinite(Ti) || Ti <= 0
    error('ASTA:Ti', 'Ti must be finite and positive.');
  end
  if any(~isfinite([Td tau])) || ~isscalar(Td) || ~isscalar(tau) || ~isreal([Td tau]) || Td < 0 || tau < 0
    error('ASTA:derivative', 'Td and tau must be finite and nonnegative.');
  end
  s = tf('s'); R = tf(1); base = tf(1);
  switch lower(kind)
    case 'p', K = tf(P); return;
    case 'i', K = P/(Ti*s); return;
    case {'pi','pid','pid-output'}, base = 1 + 1/(Ti*s);
    case {'pd','pd-output'}
    otherwise, error('ASTA:controller', 'Unknown controller: %s', kind);
  end
  if any(strcmpi(kind, {'pd','pid','pd-output','pid-output'}))
    D = Td*s/(1+tau*s);
  else
    D = tf(0);
  end
  K = P*(base+D);
  if any(strcmpi(kind, {'pd-output','pid-output'}))
    if P == 0, error('ASTA:controller', 'Output derivative requires nonzero P.'); end
    R = minreal(base/(base+D));
  end
end
