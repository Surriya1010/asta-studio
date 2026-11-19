function asta_nichols_grid(ax)
  % Contours of |L/(1+L)| and phase(L/(1+L)), including lab's 2.3 dB.
  if nargin < 1, ax = gca(); end
  [phase,db] = meshgrid(linspace(-360,0,721),linspace(-50,50,501));
  L = 10.^(db/20).*exp(1i*phase*pi/180);
  T = L./(1+L);
  old = ishold(ax); hold(ax,'on');
  [c,h] = contour(ax,phase,db,20*log10(abs(T)),[-12 -6 -3 0 1 2.3 3 6 12], ...
                  'linestyle',':','linecolor',[0.55 0.55 0.55]);
  clabel(c,h,'fontsize',8);
  contour(ax,phase,db,angle(T)*180/pi,[-150 -120 -90 -60 -30], ...
          'linestyle','--','linecolor',[0.8 0.8 0.8]);
  if ~old, hold(ax,'off'); end
end
