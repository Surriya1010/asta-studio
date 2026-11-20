function h = asta_nichols_grid(ax)
  % Show only the highlighted 2.3 dB |L/(1+L)| reference contour.
  if nargin < 1, ax = gca(); end
  m = 10^(2.3/20);
  T = m*exp(1i*linspace(-pi,pi,1601));
  L = T./(1-T);
  phase = angle(L)*180/pi; phase(phase>0) = phase(phase>0)-360;
  gain = 20*log10(abs(L));
  color = [178 20 147]/255;
  old = ishold(ax); hold(ax,'on');
  h = plot(ax,phase,gain,'color',color,'linewidth',2.7,'linestyle','--', ...
           'handlevisibility','off','tag','asta_m_circle_2_3');
  set(h,'userdata',struct('magnitude_db',2.3));
  [~,j] = max(gain);
  text(ax,phase(j)+2,gain(j),'M = 2.3 dB','color',color, ...
       'backgroundcolor','white','fontweight','bold','fontsize',10, ...
       'verticalalignment','bottom','interpreter','none', ...
       'tag','asta_m_circle_label','handlevisibility','off');
  if ~old, hold(ax,'off'); end
end
