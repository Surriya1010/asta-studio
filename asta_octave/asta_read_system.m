function [h, info] = asta_read_system(filename)
  % Strict NS / DS parser; never evaluates file content as Octave code.
  pkg load control;
  raw = fileread(filename);
  lines = regexp(strrep(raw, char(13), ''), '\n', 'split');
  n = []; d = []; target = ''; seen = {};
  for j = 1:numel(lines)
    line = strtrim(lines{j});
    if isempty(line), continue; end
    if any(strcmp(line, {'NS','DS'}))
      if any(strcmp(seen, line)), error('ASTA:file', 'Duplicate %s marker.', line); end
      target = line; seen{end+1} = line; continue;
    end
    if isempty(target), error('ASTA:file', 'Expected an NS or DS marker.'); end
    tokens = regexp(line, '\s+', 'split'); values = zeros(1,numel(tokens));
    for k = 1:numel(tokens)
      if isempty(regexp(tokens{k}, '^[+-]?(\d+(\.\d*)?|\.\d+)([eEdD][+-]?\d+)?$', 'once'))
        error('ASTA:file', 'Invalid coefficient: %s', tokens{k});
      end
      values(k) = str2double(regexprep(tokens{k}, '[dD]', 'e'));
    end
    if any(~isfinite(values)), error('ASTA:file', 'Nonfinite coefficient.'); end
    if strcmp(target,'NS'), n = [n values]; else, d = [d values]; end
  end
  if isempty(n) || isempty(d) || ~any(d), error('ASTA:file', 'Missing numerator or valid denominator.'); end
  h = tf(n,d);
  [model_n,model_d] = tfdata(h,'vector');
  info = struct('filename', filename, 'original_text', raw, 'numerator', n, 'denominator', d, ...
                'model_numerator',model_n,'model_denominator',model_d);
end
