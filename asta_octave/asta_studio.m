function asta_studio()
  % Open the local browser workspace backed by a persistent Octave process.
  % The original native interface remains available with asta().
  if ~isunix(), error('ASTA:launcher','Run python3 studio/server.py from a terminal on this platform.'); end
  server=fullfile(fileparts(mfilename('fullpath')),'studio','server.py');
  apostrophe=char(39);
  quoted=[apostrophe strrep(server,apostrophe,[apostrophe char(34) apostrophe char(34) apostrophe]) apostrophe];
  [status,message]=system(['python3 ' quoted ' --detach']);
  if status~=0, error('ASTA:studio','Could not start ASTA Studio: %s',message); end
  fprintf('%s',message);
end
