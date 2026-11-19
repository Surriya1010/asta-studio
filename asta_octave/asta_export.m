function asta_export(filename,r)
  % CSV is an analysis export. MAT projects retain models and metadata.
  if isfield(r,'t')
    header = 'time_s,response'; data = [r.t r.y];
  else
    header = 'omega_rad_s,real,imaginary,magnitude,db,phase_deg';
    data = [r.w real(r.response) imag(r.response) r.magnitude r.db r.phase];
  end
  fid = fopen(filename,'w');
  if fid < 0, error('ASTA:file', 'Cannot write export.'); end
  cleanup = onCleanup(@() fclose(fid));
  fprintf(fid,'%s\n',header);
  fmt = [repmat('%.17g,',1,size(data,2)-1) '%.17g\n'];
  fprintf(fid,fmt,data.');
end
