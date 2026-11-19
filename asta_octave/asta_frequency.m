function r = asta_frequency(p, channel, w)
  m = asta_models(p);
  if nargin < 2, channel = 'L'; end
  if ~isfield(m,channel) || ~isa(m.(channel),'lti'), error('ASTA:channel', 'Unknown channel.'); end
  if nargin < 3 || isempty(w)
    [~,~,w] = bode(m.(channel));
    if numel(w)>1, w = logspace(log10(min(w)),log10(max(w)),4000); end
  end
  if ~isvector(w) || any(~isfinite(w)) || any(w<=0) || any(diff(w)<=0)
    error('ASTA:frequency', 'Frequencies must be finite, positive and increasing.');
  end
  z = reshape(freqresp(m.(channel),w),[],1);
  r = struct('w', w(:), 'response', z, 'magnitude', abs(z), ...
    'db', 20*log10(abs(z)), 'phase', unwrap(angle(z))*180/pi, ...
    'channel', channel, 'project', p);
end
