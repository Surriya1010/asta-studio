function result = astastudio(action, varargin)
  % ASTASTUDIO Launch or inspect the ASTA Studio Octave package.
  %
  % astastudio() opens the browser workspace.
  % astastudio('open', 'port', 8770, 'browser', false) starts without a tab.
  % astastudio('version') returns the installed version.
  % astastudio('info') returns package paths and example-model information.
  % astastudio('test') runs the numerical, project and legacy-file self-tests.
  %
  % Install the release archive with pkg install, then pkg load astastudio.
  if nargin < 1, action = 'open'; end
  root = fileparts(mfilename('fullpath'));
  switch lower(action)
    case {'open','start'}
      asta_studio(varargin{:}); result = [];
    case 'version'
      result = '1.0.0';
    case 'info'
      models = dir(fullfile(root,'systeme','*.syst'));
      result = struct('name','astastudio','version','1.0.0','root',root, ...
        'model_directory',fullfile(root,'systeme'),'model_count',numel(models), ...
        'server',fullfile(root,'studio','server.py'), ...
        'repository','https://github.com/Surriya1010/asta-studio');
    case 'test'
      if exist(fullfile(root,'private','astastudio_run_tests.m'),'file')
        astastudio_run_tests();
      else
        previous = path(); restore = onCleanup(@() path(previous));
        addpath(fullfile(root,'tests')); run_tests();
      end
      result = true;
    otherwise
      error('ASTA:action','Use astastudio(), or astastudio(''version''/''info''/''test'').');
  end
  if nargout == 0 && ~isempty(result), disp(result); end
end

%!test
%! assert(strcmp(astastudio('version'), '1.0.0'));
%! info = astastudio('info');
%! assert(info.model_count, 19);
%! assert(exist(info.server, 'file'), 2);
%! assert(exist(fullfile(info.root, 'studio', 'app.js'), 'file'), 2);

%!test
%! pkg load control;
%! p = asta_project(tf(0.1,[1 2 1 0]), tf(4.8), tf(1));
%! m = asta_models(p);
%! assert(m.closed_loop_stable);
%! assert(dcgain(m.T), 1, 1e-10);
%! assert(max(abs(squeeze(freqresp(m.S+m.T,[0.1 1 10]))-1)) < 1e-10);
