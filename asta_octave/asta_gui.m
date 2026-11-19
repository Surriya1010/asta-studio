function f = asta_gui()
  pkg load control;
  f = figure('name','ASTA for GNU Octave','numbertitle','off','menubar','none');
  state = struct('project',asta_project(),'snapshots',{{}},'time',linspace(0,40,4001), ...
                 'frequency',logspace(-3,3,4000),'overlay',true);
  setappdata(f,'asta_state',state);
  menu = uimenu(f,'label','Project');
  item(menu,'New',@() act(f,'new'));
  item(menu,'Load project...',@() act(f,'load'));
  item(menu,'Save project...',@() act(f,'save'));
  item(menu,'Rename...',@() act(f,'rename'));
  item(menu,'Close',@() close(f));
  for key = {'G','K','R'}
    k = key{1}; labels = struct('G','System G(s)','K','Controller K(s)','R','Precompensator R(s)');
    menu = uimenu(f,'label',labels.(k));
    item(menu,'Edit numerator / denominator...',@() act(f,'edit',k));
    item(menu,'Load NS/DS file...',@() act(f,'import',k));
    item(menu,'Save NS/DS file...',@() act(f,'export',k));
    if strcmp(k,'K')
      for type = {'p','i','pi','pd','pid','pd-output','pid-output'}
        v = type{1}; item(menu,upper(v),@() act(f,'controller',v));
      end
    else
      for type = {'gain','integrator','first','second','leadlag'}
        v = type{1}; item(menu,v,@() act(f,'template',k,v));
      end
    end
  end
  menu = uimenu(f,'label','Responses');
  for type = {'open','closed','control','reference','nichols','nyquist','bode','s','t','w'}
    v = type{1}; item(menu,v,@() act(f,'plot',v));
  end
  menu = uimenu(f,'label','Tools');
  item(menu,'Time range...',@() act(f,'time'));
  item(menu,'Frequency range...',@() act(f,'frequency'));
  item(menu,'Automatic ranges',@() act(f,'automatic'));
  item(menu,'Toggle superposition',@() act(f,'overlay'));
  item(menu,'Remember current project',@() act(f,'snapshot'));
  item(menu,'Plot manager...',@() act(f,'manager'));
  item(menu,'Statistics',@() act(f,'statistics'));
  menu = uimenu(f,'label','Help');
  item(menu,'Read instructions',@() act(f,'help'));
  redraw(f);
  if strcmp(graphics_toolkit(f),'gnuplot')
    warning('ASTA:graphics','Only gnuplot is active. The numerical API and plots work; interactive menus/dialogs require Octave with Qt graphics and a desktop display. See README.md.');
  end
end
function item(parent,label,fn)
  uimenu(parent,'label',label,'callback',@(~,~) guarded(fn));
end
function guarded(fn)
  try, fn(); catch err, errordlg(err.message,'ASTA'); end
end
function act(f,action,varargin)
  a = getappdata(f,'asta_state'); p = a.project;
  switch action
    case 'new', a.project = asta_project();
    case 'rename'
      v = inputdlg('Project name','Rename',1,{p.name}); if isempty(v), return; end
      a.project.name = v{1};
    case 'load'
      [name,path] = uigetfile('*.asta','Load ASTA Octave project'); if isequal(name,0), return; end
      [loaded,session] = asta_load(fullfile(path,name));
      if ~isempty(session), a = session; end
      a.project = loaded;
    case 'save'
      [name,path] = uiputfile('*.asta','Save ASTA Octave project'); if isequal(name,0), return; end
      asta_save(fullfile(path,name),p,a); return;
    case 'edit'
      key = varargin{1}; [n,d] = tfdata(tf(p.(key)),'vector');
      v = inputdlg({'Numerator (descending powers)','Denominator (descending powers)'},key,1, ...
                   {mat2str(n,17),mat2str(d,17)});
      if isempty(v), return; end
      a.project.(key) = tf(numbers(v{1}),numbers(v{2}));
    case 'import'
      [name,path] = uigetfile({'*.syst;*.txt','NS/DS models'},'Load model'); if isequal(name,0), return; end
      key = varargin{1}; [a.project.(key),info] = asta_read_system(fullfile(path,name));
      a.project.metadata.(key) = info;
    case 'export'
      [name,path] = uiputfile({'*.syst;*.txt','NS/DS models'},'Save model'); if isequal(name,0), return; end
      key = varargin{1}; info = struct();
      if isfield(p.metadata,key), info = p.metadata.(key); end
      asta_write_system(fullfile(path,name),p.(key),info); return;
    case 'controller'
      type = varargin{1};
      v = inputdlg({'P','Ti (s; positive)','Td (s)','Filter tau (s)'},type,1,{'1','1','0.9','0.09'});
      if isempty(v), return; end
      [a.project.K,a.project.R] = asta_controller(type,scalar(v{1}),scalar(v{2}),scalar(v{3}),scalar(v{4}));
      % Output-derivative controllers necessarily set their reference factor.
    case 'template'
      key = varargin{1}; type = varargin{2};
      prompts = struct('gain',{{'Gain'}},'integrator',{{'Gain'}}, ...
        'first',{{'Gain','Time constant'}},'second',{{'Gain','Natural frequency','Damping ratio'}}, ...
        'leadlag',{{'Gain','Zero time constant','Pole time constant'}});
      v = inputdlg(prompts.(type),type,1,repmat({'1'},1,numel(prompts.(type))));
      if isempty(v), return; end
      values = cellfun(@scalar,v,'uniformoutput',false);
      a.project.(key) = asta_template(type,values{:});
    case {'time','frequency'}
      if strcmp(action,'time'), defaults = {'40','4001'}; prompts = {'Final time (s)','Samples'};
      else, defaults = {'0.001','1000','4000'}; prompts = {'Minimum rad/s','Maximum rad/s','Samples'}; end
      v = inputdlg(prompts,action,1,defaults); if isempty(v), return; end
      values = cellfun(@scalar,v);
      count = values(end); assert(count >= 2 && count == fix(count) && count <= 1e6,'Use 2 to 1,000,000 samples.');
      if strcmp(action,'time')
        assert(values(1)>0,'Final time must be positive.'); a.time = linspace(0,values(1),count);
      else
        assert(values(1)>0 && values(2)>values(1),'Invalid frequency limits.');
        a.frequency = logspace(log10(values(1)),log10(values(2)),count);
      end
    case 'automatic', a.time = []; a.frequency = [];
    case 'overlay', a.overlay = ~a.overlay;
    case 'snapshot', a.snapshots{end+1} = p;
    case 'manager'
      if isempty(a.snapshots), msgbox('Remember a project in Tools first.'); return; end
      names = cellfun(@(q) q.name,a.snapshots,'uniformoutput',false);
      [idx,ok] = listdlg('liststring',names,'selectionmode','multiple','promptstring','Select saved projects');
      if ~ok, return; end
      choices = {'Plot in time domain','Plot in frequency domain','Restore first selected','Remove selected'};
      [op,ok] = listdlg('liststring',choices,'selectionmode','single'); if ~ok, return; end
      if op <= 2
        kinds = {'closed','nichols'}; ranges = {a.time,a.frequency};
        fig = asta_plot(a.snapshots(idx),kinds{op},ranges{op}); plot_tools(fig); return;
      elseif op == 3, a.project = a.snapshots{idx(1)};
      else, a.snapshots(idx) = []; end
    case 'plot'
      projects = {p}; if a.overlay, projects = [a.snapshots {p}]; end
      type = varargin{1}; range = a.frequency;
      if any(strcmp(type,{'open','closed','control','reference'})), range = a.time; end
      fig = asta_plot(projects,type,range); plot_tools(fig); return;
    case 'statistics', disp(asta_statistics(p,a.time,a.frequency)); msgbox('Statistics printed in the Octave command window.'); return;
    case 'help', disp(fileread(fullfile(fileparts(mfilename('fullpath')),'README.md'))); return;
  end
  asta_validate(a.project); setappdata(f,'asta_state',a); redraw(f);
end
function redraw(f)
  a = getappdata(f,'asta_state'); figure(f);
  ax = findobj(f,'type','axes'); delete(ax);
  axes('parent',f,'position',[0.06 0.05 0.9 0.9]); axis off;
  text(0,0.92,['ASTA  |  ' a.project.name],'fontsize',18,'interpreter','none');
  text(0,0.79,'r -> R -> (reference - y) -> K -> G -> y','fontsize',12,'interpreter','none');
  y = 0.62;
  for key = {'G','K','R'}
    [n,d] = tfdata(tf(a.project.(key{1})),'vector');
    text(0,y,sprintf('%s(s):  %s / %s',key{1},mat2str(n,6),mat2str(d,6)), ...
      'interpreter','none','fontsize',11); y = y-0.13;
  end
  text(0,0.13,sprintf('Saved comparisons: %d    Superposition: %d',numel(a.snapshots),a.overlay));
  text(0,0.04,'Use the menus to edit, analyse, compare and save.');
end
function x = numbers(v)
  v = strtrim(regexprep(v,'[\[\],;]',' ')); tokens = regexp(v,'\s+','split');
  x = cellfun(@str2double,tokens);
  assert(~isempty(x) && all(isfinite(x)) && isreal(x),'Enter finite numeric coefficients.');
end
function x = scalar(v)
  x = numbers(v); assert(isscalar(x),'Enter one number.');
end
function plot_tools(f)
  menu = uimenu(f,'label','ASTA tools');
  item(menu,'Statistics for plotted projects',@() plot_action(f,'statistics'));
  item(menu,'Point coordinates',@() plot_action(f,'cursor'));
  item(menu,'Measure two points',@() plot_action(f,'measure'));
  item(menu,'Zoom on',@() zoom(f,'on')); item(menu,'Zoom off',@() zoom(f,'off'));
  item(menu,'Export selected curve CSV...',@() plot_action(f,'csv'));
  item(menu,'Save figure...',@() plot_action(f,'image'));
  item(menu,'Send projects to time domain',@() plot_action(f,'time'));
  item(menu,'Send projects to frequency domain',@() plot_action(f,'frequency'));
end
function plot_action(f,action)
  projects = getappdata(f,'asta_projects'); figure(f);
  if any(strcmp(action,{'time','frequency'}))
    type = 'closed'; if strcmp(action,'frequency'), type = 'nichols'; end
    fig = asta_plot(projects,type); plot_tools(fig); return;
  end
  if strcmp(action,'statistics')
    for j = 1:numel(projects), disp(projects{j}.name); disp(asta_statistics(projects{j})); end
    return;
  end
  if strcmp(action,'image')
    [n,p] = uiputfile({'*.png','PNG';'*.pdf','PDF'},'Export figure'); if isequal(n,0), return; end
    [~,~,ext] = fileparts(n); device = '-dpng'; if strcmpi(ext,'.pdf'), device = '-dpdf'; end
    print(f,fullfile(p,n),device); return;
  end
  curves = findall(f,'type','line'); valid = false(size(curves));
  for j = 1:numel(curves), r = get(curves(j),'userdata'); valid(j) = isstruct(r) && isfield(r,'project'); end
  curves = curves(valid); labels = get(curves,'displayname');
  if ischar(labels), labels = {labels}; end
  [idx,ok] = listdlg('liststring',labels,'selectionmode','single','promptstring','Select curve');
  if ~ok, return; end
  h = curves(idx); r = get(h,'userdata');
  if strcmp(action,'csv')
    [n,p] = uiputfile('*.csv','Export sampled curve'); if ~isequal(n,0), asta_export(fullfile(p,n),r); end
    return;
  end
  ax = get(h,'parent'); axes(ax); count = 1; if strcmp(action,'measure'), count = 2; end
  [x,y] = ginput(count); if numel(x) ~= count, return; end
  xd = get(h,'xdata'); yd = get(h,'ydata');
  % Distance in normalized displayed axes coordinates, respecting log axes.
  if strcmp(get(ax,'xscale'),'log'), xd = log10(xd); x = log10(x); end
  if strcmp(get(ax,'yscale'),'log'), yd = log10(yd); y = log10(y); end
  selected = zeros(1,count);
  for j = 1:count
    dist = ((xd-x(j))/max(eps,max(xd)-min(xd))).^2 + ((yd-y(j))/max(eps,max(yd)-min(yd))).^2;
    [~,selected(j)] = min(dist);
  end
  if isfield(r,'t'), coordinates = r.t; else, coordinates = r.w; end
  if count == 2
    disp(asta_measure(r,coordinates(selected(1)),coordinates(selected(2))));
  elseif isfield(r,'t')
    disp(struct('time_s',r.t(selected),'response',r.y(selected)));
  else
    disp(struct('omega_rad_s',r.w(selected),'magnitude',r.magnitude(selected), ...
      'db',r.db(selected),'phase_deg',r.phase(selected)));
  end
end
