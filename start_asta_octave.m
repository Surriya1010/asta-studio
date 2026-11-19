% Open ASTA Studio: a browser workspace with persistent Octave calculations.
asta_octave_root = fullfile(fileparts(mfilename('fullpath')), 'asta_octave');
addpath(asta_octave_root);
asta_studio();
% To use the earlier native window instead, call asta().
