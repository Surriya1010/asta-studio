function asta_studio(varargin)
  % Open ASTA Studio with a persistent Octave worker, without requiring Qt.
  % asta_studio('port', 8770, 'browser', false) changes the port and suppresses
  % opening a browser. Loading the package alone never starts a server.
  parser = inputParser();
  addParameter(parser,'port',8765,@(x) isnumeric(x) && isscalar(x) && isfinite(x) && x==fix(x) && x>=1024 && x<=65535);
  addParameter(parser,'browser',true,@(x) isscalar(x) && (islogical(x) || (isnumeric(x) && any(x==[0 1]))));
  parse(parser,varargin{:});
  if ~isunix(), error('ASTA:launcher','Run python3 studio/server.py from a terminal on this platform.'); end
  server = fullfile(fileparts(mfilename('fullpath')),'studio','server.py');
  apostrophe = char(39);
  quoted = [apostrophe strrep(server,apostrophe,[apostrophe char(34) apostrophe char(34) apostrophe]) apostrophe];
  command = sprintf('python3 %s --detach --port %d',quoted,parser.Results.port);
  if ~parser.Results.browser, command = [command ' --no-browser']; end
  [status,message] = system(command);
  if status ~= 0, error('ASTA:studio','Could not start ASTA Studio: %s',message); end
  fprintf('%s',message);
end
