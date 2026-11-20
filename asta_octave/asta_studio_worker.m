function asta_studio_worker(request_file, response_file)
  % Persistent line protocol. stdout is reserved for prefixed JSON responses.
  pkg load control;
  while true
    if nargin==2
      while ~exist(request_file,'file'), pause(0.015); end
      line=fileread(request_file); unlink(request_file);
    else
      line=fgetl(stdin); if ~ischar(line), return; end
    end
    started=tic;
    try
      req=jsondecode(line);
      switch req.action
        case 'analyze'
          p=decode_project(req.project); g=req.grid;
          validate_grid(g);
          t=linspace(0,g.time_end,g.time_samples); w=logspace(log10(g.w_min),log10(g.w_max),g.w_samples);
          out=struct('name',p.name,'time',t,'omega',w,'curves',struct(),'frequency',struct());
          for key={'G','Y','U','reference'}
            r=asta_response(p,key{1},t); out.curves.(key{1})=r.y;
          end
          for key={'L','S','T','W'}
            r=asta_frequency(p,key{1},w);
            out.frequency.(key{1})=struct('real',real(r.response),'imag',imag(r.response),'db',r.db,'phase',r.phase);
          end
          a=asta_statistics(p,t,w); a=rmfield(a,{'time_grid','frequency_grid'});
          out.statistics=a;
        case 'controller'
          if strcmpi(req.kind,'lag')
            [K,R]=asta_controller('lag',req.P,req.Tzero,req.beta);
          else
            [K,R]=asta_controller(req.kind,req.P,req.Ti,req.Td,req.tau);
          end
          out=struct('K',encode_model(K),'R',encode_model(R));
        case 'systems'
          directory=fullfile(fileparts(mfilename('fullpath')),'systeme'); files=dir(fullfile(directory,'*.syst'));
          out=cell(1,numel(files));
          for j=1:numel(files)
            [h,info]=asta_read_system(fullfile(directory,files(j).name));
            out{j}=struct('name',files(j).name,'model',encode_model(h),'original',info);
          end
        otherwise, error('ASTA:request','Unknown action.');
      end
      answer=struct('ok',true,'data',{out},'elapsed_ms',toc(started)*1000);
    catch err
      answer=struct('ok',false,'error',err.message);
    end
    if nargin==2
      temporary=[response_file '.tmp']; fid=fopen(temporary,'w');
      fprintf(fid,'%s',jsonencode(wire_value(answer))); fclose(fid);
      movefile(temporary,response_file,'f');
    else
      fprintf(stdout,'ASTA_JSON:%s\n',jsonencode(wire_value(answer))); fflush(stdout);
    end
  end
end
function p=decode_project(v)
  p=asta_project(decode_model(v.G),decode_model(v.K),decode_model(v.R),v.name);
end
function h=decode_model(v)
  assert(isnumeric(v.num) && isvector(v.num) && all(isfinite(v.num)) && numel(v.num)<=128,'Invalid numerator (maximum 128 coefficients).');
  assert(isnumeric(v.den) && isvector(v.den) && all(isfinite(v.den)) && any(v.den) && numel(v.den)<=128,'Invalid denominator (maximum 128 coefficients).');
  h=tf(v.num(:).',v.den(:).');
end
function v=encode_model(h)
  [n,d]=tfdata(h,'vector'); v=struct('num',n,'den',d);
end
function validate_grid(g)
  assert(isscalar(g.time_end) && isfinite(g.time_end) && g.time_end>0 && g.time_end<=1e8,'Final time must be positive and at most 1e8 seconds.');
  assert(isscalar(g.w_min) && isscalar(g.w_max) && isfinite(g.w_min) && isfinite(g.w_max) && g.w_min>0 && g.w_max>g.w_min,'Enter positive, increasing frequency limits.');
  for n=[g.time_samples g.w_samples]
    assert(isscalar(n) && isfinite(n) && n==fix(n) && n>=101 && n<=50001,'Use 101 to 50,001 samples.');
  end
end

function v=wire_value(v)
  % JSON cannot represent IEEE exceptional values; preserve their distinctions.
  if isstruct(v)
    fields=fieldnames(v);
    for j=1:numel(v)
      for k=1:numel(fields), v(j).(fields{k})=wire_value(v(j).(fields{k})); end
    end
  elseif iscell(v)
    for j=1:numel(v), v{j}=wire_value(v{j}); end
  elseif isnumeric(v) && any(~isfinite(v(:)))
    items=num2cell(v);
    for j=1:numel(v)
      if isnan(v(j)), items{j}='NaN';
      elseif isinf(v(j)) && v(j)>0, items{j}='Infinity';
      elseif isinf(v(j)), items{j}='-Infinity'; end
    end
    if isscalar(v), v=items{1}; else, v=items; end
  end
end
