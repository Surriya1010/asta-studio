function asta_save(filename, project, session)
  % Save models/metadata; optional GUI session includes snapshots and ranges.
  asta_validate(project);
  if nargin < 3, session = []; end
  save('-binary', filename, 'project', 'session');
end
