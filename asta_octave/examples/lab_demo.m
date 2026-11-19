% Run from any directory: run('/absolute/path/asta_octave/examples/lab_demo.m')
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
pkg load control;
G = tf(0.1,[1 2 1 0]);
p = asta_project(G,tf(4.8),tf(1),'P = 4.8');
[K,R] = asta_controller('pd-output',10,1,0.9,0.09);
pd = asta_project(G,K,R,'PD on output');
t = linspace(0,40,8001); w = logspace(-3,3,20000);
for q = {p,pd}
  disp(q{1}.name); a = asta_statistics(q{1},t,w); disp(a.time);
  disp(struct('T_peak_db',a.T_peak_db,'resonance_rad_s',a.T_peak_frequency, ...
              'bandwidth_rad_s',a.bandwidth_3db,'Umax',a.control_peak_abs));
end
for kind = {'closed','control','nichols','bode','t'}
  range = w; if any(strcmp(kind{1},{'closed','control'})), range = t; end
  f = asta_plot({p,pd},kind{1},range);
  print(f,fullfile(root,'examples',['lab_' kind{1} '.png']),'-dpng','-r120');
  close(f);
end
asta_save(fullfile(root,'examples','lab_proportional.asta'),p);
asta_save(fullfile(root,'examples','lab_pd_output.asta'),pd);
