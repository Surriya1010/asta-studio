function fig = asta_plot(projects, kind, grid, fig)
  % A cell array overlays projects; all line data retain project provenance.
  if ~iscell(projects), projects = {projects}; end
  if nargin < 2, kind = 'closed'; end
  if nargin < 3, grid = []; end
  if nargin < 4 || isempty(fig), fig = figure('name',['ASTA - ' kind], 'numbertitle','off'); end
  figure(fig); clf(fig);
  names = cellfun(@(p) p.name, projects, 'uniformoutput', false);
  colors = lines(numel(projects));
  for j = 1:numel(projects)
    p = projects{j};
    switch lower(kind)
      case {'open','closed','control','reference'}
        keys = struct('open','G','closed','Y','control','U','reference','reference');
        r = asta_response(p, keys.(lower(kind)),grid);
        ax = gca(); hold(ax,'on');
        h = plot(ax,r.t,r.y,'color',colors(j,:),'linewidth',1.5,'displayname',names{j});
        set(h,'userdata',r); xlabel('Time (s)'); ylabel('Amplitude');
      case {'bode','nichols','nyquist','s','t','w'}
        channel = 'L'; if any(strcmpi(kind,{'s','t','w'})), channel = upper(kind); end
        r = asta_frequency(p,channel,grid);
        switch lower(kind)
          case 'bode'
            ax = subplot(2,1,1); hold(ax,'on');
            h = semilogx(ax,r.w,r.db,'color',colors(j,:),'linewidth',1.5,'displayname',names{j});
            set(ax,'xscale','log'); set(h,'userdata',r); ylabel('Magnitude (dB)');
            ax = subplot(2,1,2); hold(ax,'on');
            h = semilogx(ax,r.w,r.phase,'color',colors(j,:),'linewidth',1.5,'displayname',names{j});
            set(ax,'xscale','log'); ylabel('Phase (deg)'); xlabel('Angular frequency (rad/s)');
          case 'nichols'
            ax = gca(); hold(ax,'on');
            h = plot(ax,r.phase,r.db,'color',colors(j,:),'linewidth',1.5,'displayname',names{j});
            xlabel('Loop phase (deg)'); ylabel('Loop magnitude (dB)');
          case 'nyquist'
            ax = gca(); hold(ax,'on');
            h = plot(ax,real(r.response),imag(r.response),'color',colors(j,:),'linewidth',1.5,'displayname',names{j});
            plot(ax,real(r.response),-imag(r.response),'--','color',colors(j,:),'handlevisibility','off');
            plot(ax,-1,0,'r+','handlevisibility','off'); xlabel('Real'); ylabel('Imaginary'); axis equal;
          otherwise
            ax = gca(); hold(ax,'on');
            h = semilogx(ax,r.w,r.db,'color',colors(j,:),'linewidth',1.5,'displayname',names{j});
            set(ax,'xscale','log'); xlabel('Angular frequency (rad/s)'); ylabel([channel ' magnitude (dB)']);
        end
        set(h,'userdata',r);
      otherwise, error('ASTA:plot', 'Unknown plot type: %s', kind);
    end
  end
  axeslist = findall(fig,'type','axes');
  for j = 1:numel(axeslist), grid_on(axeslist(j)); end
  if strcmpi(kind,'nichols'), asta_nichols_grid(gca()); end
  setappdata(fig,'asta_projects',projects); setappdata(fig,'asta_kind',kind);
end
function grid_on(ax)
  grid(ax,'on'); lg = legend(ax,'show');
  set(lg,'location','northeast','autoupdate','off');
end
