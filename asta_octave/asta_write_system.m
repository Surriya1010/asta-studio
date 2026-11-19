function asta_write_system(filename, h, info)
  % IEEE double round-trip precision. Optionally reproduce original bytes.
  pkg load control;
  [n,d] = tfdata(tf(h), 'vector');
  fid = fopen(filename, 'wb');
  if fid < 0, error('ASTA:file', 'Cannot write %s.', filename); end
  cleanup = onCleanup(@() fclose(fid));
  if nargin >= 3 && all(isfield(info, {'original_text','model_numerator','model_denominator'})) && ...
      isequal(n, info.model_numerator) && isequal(d, info.model_denominator)
    fwrite(fid, info.original_text, 'char');
  else
    fprintf(fid, 'NS\n'); fprintf(fid, '%.17g ', n);
    fprintf(fid, '\nDS\n'); fprintf(fid, '%.17g ', d); fprintf(fid, '\n');
  end
end
