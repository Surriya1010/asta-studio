function [project, session] = asta_load(filename)
  pkg load control;
  data = load(filename);
  if ~isfield(data, 'project'), error('ASTA:format', 'Not an ASTA Octave project file.'); end
  project = data.project;
  if ~isfield(project, 'format') || ~strcmp(project.format, 'asta-octave') || ...
     ~isfield(project,'version') || project.version ~= 1
    error('ASTA:format', 'Unsupported project format/version.');
  end
  asta_validate(project);
  session = [];
  if isfield(data,'session'), session = data.session; end
  if ~isempty(session)
    if ~isstruct(session) || ~all(isfield(session,{'snapshots','time','frequency','overlay'})) || ~iscell(session.snapshots)
      error('ASTA:format','Invalid saved session.');
    end
    for j = 1:numel(session.snapshots), asta_validate(session.snapshots{j}); end
  end
end
