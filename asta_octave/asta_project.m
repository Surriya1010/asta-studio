function p = asta_project(G, K, R, name)
  % Create a continuous-time SISO ASTA project. Coefficients are not reduced.
  pkg load control;
  if nargin < 1, G = tf(0.1, [1 2 1 0]); end
  if nargin < 2, K = tf(1); end
  if nargin < 3, R = tf(1); end
  if nargin < 4, name = 'Untitled'; end
  p = struct('format', 'asta-octave', 'version', 1, 'name', name, ...
             'G', G, 'K', K, 'R', R, 'metadata', struct());
  asta_validate(p);
end
