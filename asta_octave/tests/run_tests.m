function run_tests()
  root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
  pkg load control;
  scratch = tempname(); mkdir(scratch); cleanup = onCleanup(@() rmdir(scratch,'s'));
  G = tf(0.1,[1 2 1 0]);
  p = asta_project(G,tf(4.8),tf(1),'Lab P'); m = asta_models(p);
  w = logspace(-3,3,20000); t = linspace(0,40,8001);
  assert(max(abs(squeeze(freqresp(m.S+m.T,w))-1)) < 1e-10);
  assert(max(abs(squeeze(freqresp(m.U*G-m.Y,w)))) < 1e-10);
  a = asta_statistics(p,t,w);
  assert(abs(a.T_peak_db-2.32) < 0.06);
  assert(abs(a.T_peak_frequency-0.4473) < 0.001);
  assert(abs(a.bandwidth_3db-0.734) < 0.01);
  assert(abs(a.time.overshoot_percent-23.5) < 0.3);
  assert(abs(a.time.peak_time-6.9) < 0.1);
  assert(abs(a.time.settling_time_5_percent-14.2) < 0.15);
  assert(abs(a.time.settling_time_2_percent-15.7) < 0.15);
  assert(abs(a.control_peak_abs-4.8) < 1e-10);
  [K,R] = asta_controller('pd-output',10,1,0.9,0.09);
  pd = asta_project(G,K,R,'Lab PD'); a = asta_statistics(pd,t,w);
  assert(abs(a.T_peak_db-1.86) < 0.06);
  assert(abs(a.T_peak_frequency-0.7615) < 0.001);
  assert(abs(a.bandwidth_3db-1.3) < 0.03);
  assert(abs(a.time.overshoot_percent-11) < 0.3);
  assert(abs(a.time.peak_time-4.7) < 0.15);
  assert(abs(a.time.settling_time_5_percent-6) < 0.2);
  assert(abs(a.time.settling_time_2_percent-8.9) < 0.2);
  assert(abs(a.control_peak_abs-10) < 1e-8);
  % Independent state-space simulation of derivative-on-output architecture.
  % y'=v; v'=a; a'=0.1u-2a-v; yf'=(y-yf)/tau;
  % u=P(r-y)-P*Td*(y-yf)/tau.
  P=10; Td=.9; tau=.09;
  A=[0 1 0 0; 0 0 1 0; -.1*P*(1+Td/tau) -1 -2 .1*P*Td/tau; 1/tau 0 0 -1/tau];
  B=[0;0;.1*P;0]; C=[1 0 0 0]; independent=step(ss(A,B,C,0),t);
  response=asta_response(pd,'Y',t); assert(max(abs(independent-response.y)) < 1e-8);
  % Every supplied model: coefficients and byte-preserving export.
  files = dir(fullfile(root,'systeme','*.syst'));
  for j = 1:numel(files)
    filename = fullfile(root,'systeme',files(j).name);
    [h,info] = asta_read_system(filename);
    output = fullfile(scratch,files(j).name); asta_write_system(output,h,info);
    assert(strcmp(fileread(filename),fileread(output)));
    [copy,~] = asta_read_system(output);
    [n,d] = tfdata(h,'vector'); [nn,dd] = tfdata(copy,'vector');
    assert(isequal(n,nn) && isequal(d,dd));
  end
  % Double precision export, including coefficients beyond 6 digits.
  h=tf([pi eps],[1 sqrt(2) 0]); filename=fullfile(scratch,'precision.syst');
  asta_write_system(filename,h); copy=asta_read_system(filename);
  [n,d]=tfdata(h,'vector'); [nn,dd]=tfdata(copy,'vector'); assert(isequal(n,nn) && isequal(d,dd));
  p.metadata.arbitrary = struct('unknown_field',[pi eps],'notes','preserve me');
  filename=fullfile(scratch,'project.asta'); asta_save(filename,p); copy=asta_load(filename);
  assert(isequal(p.metadata,copy.metadata));
  for key={'G','K','R'}
    [n,d]=tfdata(p.(key{1}),'vector'); [nn,dd]=tfdata(copy.(key{1}),'vector');
    assert(isequal(n,nn) && isequal(d,dd));
  end
  session=struct('project',p,'snapshots',{{p,pd}},'time',t,'frequency',w,'overlay',true);
  asta_save(filename,p,session); [copy,restored]=asta_load(filename);
  assert(isequal(restored.time,t) && isequal(restored.frequency,w));
  assert(numel(restored.snapshots)==2 && isequal(restored.snapshots{1}.metadata,p.metadata));
  % Unstable dynamics never produce misleading settling/overshoot values.
  unstable=asta_project(tf(1,[1 -2]),tf(1),tf(1));
  a=asta_statistics(unstable,linspace(0,2,201),w);
  assert(~a.closed_loop_stable && isnan(a.time.overshoot_percent));
  % Unsampled settling must remain unknown.
  a=asta_statistics(p,linspace(0,1,101),w); assert(isnan(a.time.settling_time_2_percent));
  response=asta_response(p,'Y',t,ones(size(t)));
  reference=asta_response(p,'Y',t); assert(max(abs(response.y-reference.y))<1e-8);
  f=asta_frequency(p,'L',w); measurement=asta_measure(f,w(1),w(end));
  assert(abs(measurement.delta_db-(f.db(end)-f.db(1))) < 1e-10);
  filename=fullfile(scratch,'response.csv'); asta_export(filename,response);
  data=dlmread(filename,',',1,0); assert(isequal(data,[response.t response.y]));
  % Validate the parser rejects executable and malformed content.
  filename=fullfile(scratch,'bad.syst'); fid=fopen(filename,'w');
  fprintf(fid,'NS\nsystem("bad")\nDS\n1'); fclose(fid);
  failed=false; try, asta_read_system(filename); catch, failed=true; end; assert(failed);
  for type={'p','i','pi','pd','pid','pd-output','pid-output'}
    [k,r]=asta_controller(type{1},2,3,.4,.04); asta_validate(asta_project(G,k,r));
  end
  for spec={{'gain',2},{'integrator',2},{'first',2,3},{'second',2,3,.4},{'leadlag',2,3,4}}
    args=spec{1}; asta_template(args{:});
  end
  asta_model_cache('clear');
  first=asta_models(p); second=asta_models(p); info=asta_model_cache('info');
  assert(info.hits==1 && info.misses==1);
  for j=1:15, q=p; q.K=tf(j); asta_models(q); end
  info=asta_model_cache('info'); assert(info.entries<=12);
  changed=p; changed.K=tf(9); a=asta_models(changed);
  assert(abs(dcgain(a.K)-9)<eps*16);
  fprintf('PASS: lab P/PD, independent state-space model, %d legacy files, precision, projects, stability, inputs, exports, validation and templates.\n',numel(files));
end
