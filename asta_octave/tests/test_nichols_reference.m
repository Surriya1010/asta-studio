function test_nichols_reference()
  % Analytic geometry of the single reference contour; no mesh approximation.
  root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
  f=figure('visible','off'); cleanup=onCleanup(@() close(f));
  ax=axes('parent',f); h=asta_nichols_grid(ax);
  assert(numel(findall(ax,'type','line'))==1);
  assert(strcmp(get(h,'tag'),'asta_m_circle_2_3'));
  assert(norm(get(h,'color')-[178 20 147]/255)<1e-12);
  phase=get(h,'xdata'); gain=get(h,'ydata');
  L=10.^(gain/20).*exp(1i*phase*pi/180);
  assert(max(abs(20*log10(abs(L./(1+L)))-2.3))<1e-10);
  assert(get(h,'linewidth')>=2.5);
  assert(numel(findall(ax,'tag','asta_m_circle_label'))==1);
  fprintf('PASS: one magenta M=2.3 dB contour with exact unity-feedback geometry.\n');
end
