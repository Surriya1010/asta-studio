# ASTA for GNU Octave

A documentation-based rebuild of the SISO control teaching tool in this workspace.
The requested name “ASTRA” is interpreted as **ASTA**, because the supplied program
and lab guide both use ASTA. This is a working replacement, **not a certified
feature-identical port**. The supplied executable code is protected MATLAB `.p`
code; no original `.m` implementation or runnable MATLAB reference was provided.

## Start with the improved workspace

From the CLACO folder in Octave, run `start_asta_octave`. This now opens **ASTA
Studio**, a local browser interface with inline editors, live plots, comparison
designs and visible statistics. Octave performs all numerical calculations in a
persistent worker. This interface works without Qt. See [STUDIO.md](STUDIO.md)
for controls, measured performance, saving and limitations.

Alternatively, run `python3 asta_octave/studio/server.py` in a terminal from CLACO.

## Earlier native Octave interface

In Octave, from the CLACO folder:

```octave
addpath('asta_octave')
asta
```

Or, from this folder:

```octave
addpath(pwd)
asta
```

Requires GNU Octave and its `control` package. The numerical work was tested with
the installed control 4.2.1. Menus, dialogs and interactive measurements require
an Octave desktop with **Qt graphics**. The current environment exposes only
gnuplot, so numerical computations, window construction and static plots were
tested here; interactive clicks and dialogs were not tested. The launcher selects
Qt when available. No package or system configuration was changed.

For a complete headless lab example:

```octave
run('asta_octave/examples/lab_demo.m') % from CLACO
```

It prints metrics and writes five comparison PNGs and two saved projects into
`examples`. Run numerical tests with:

```octave
addpath('asta_octave/tests')
run_tests
```

## Features and equations

The unity negative-feedback architecture is:

```
r -> R -> [error = filtered reference - measured output] -> K -> G -> y
```

- Edit numerator/denominator coefficients in descending powers of s.
- Gain, integrator, first-order, second-order and lead/lag model presets.
- P, I, PI, PD and PID controllers, including filtered derivative on output.
- Import/export the supplied NS/DS `.syst` files, also with a `.txt` extension.
- Open-loop, closed-loop, control and filtered-reference step responses.
- Arbitrary-input simulations through the scripting API.
- Nichols, Nyquist, Bode and sensitivity magnitude plots.
- Nichols magnitude contours including 2.3 dB, plus phase contours.
- Saved project comparisons, time/frequency transfer, editable sampling ranges.
- Point coordinates, two-point measurements, zoom, legends, figure/CSV export.
- Gain, phase and delay margins; sampled S/T/W peaks and resonance ratio;
  overshoot, peak time, 10–90% rise time and 2%/5% settling-time estimates.
- Complete project and GUI comparison-session save/reload in Octave binary format.

The API computes:

```
L = K*G
S = 1/(1+L)
T = L/(1+L)
W = K/(1+L)
Y = R*T
U = R*W
```

`W` is the magnitude convention used by the guide. The signed sensor-noise-to-
control map is `-W`, exposed as `noise_to_control`. Stability is checked using a
state-space plant/controller feedback interconnection, avoiding misleading poles
introduced by redundant polynomial multiplication. Models stored in projects are
not automatically reduced.

## Example: the lab controllers

```octave
pkg load control
G = tf(0.1, [1 2 1 0]);
p = asta_project(G, tf(4.8), tf(1), 'Proportional');
[K, R] = asta_controller('pd-output', 10, 1, 0.9, 0.09);
pd = asta_project(G, K, R, 'PD on output');
asta_plot({p, pd}, 'closed', linspace(0, 40, 8001));
a = asta_statistics(pd, linspace(0, 40, 8001), logspace(-3, 3, 20000));
disp(a.time)
```

The controller argument order is `(kind, P, Ti, Td, tau)`. `Ti` is unused for P
and PD. Standard PI/PID use `P*(1 + 1/(Ti*s) + Td*s/(1+tau*s))`, omitting unused
terms. Output derivative uses `K=P*(B+D)` and `R=B/(B+D)`, with `B=1` for PD
or `B=1+1/(Ti*s)` for PID, and `D=Td*s/(1+tau*s)`. This implements derivative
on measured output, including the correct reference response. Selecting a
controller preset sets both K and R; apply any additional reference prefilter
by multiplying R afterward. A positive tau makes derivative action proper;
an ideal derivative can have an impulsive control step response and may be
rejected by the underlying simulation routines.

## Comparisons and saved data

Use **Tools > Remember current project** before changing a controller. Subsequent
plots include remembered projects while superposition is enabled. **Plot manager**
lets you select, restore, remove or send remembered projects to either domain.
Each response window has an **ASTA tools** menu for statistics, coordinates,
measurement, CSV export, figure export and domain transfer.

```octave
[h, original] = asta_read_system('asta_octave/systeme/ath3.syst');
asta_write_system('ath3_copy.syst', h, original);
p = asta_project(h, tf(1), tf(1), 'Imported plant');
p.metadata.G = original;
asta_save('plant.asta', p);
p = asta_load('plant.asta');
r = asta_response(p, 'Y', linspace(0, 500, 5001));
asta_export('response.csv', r);
```

Projects use `.asta`, an **Octave native binary file**, rather than MATLAB MAT
object serialization: MAT serialization of the installed control-package objects
failed validation here. `.asta` is intended for this Octave rebuild. Save/reload
preserves model objects, metadata and, when saved from the GUI, comparisons and
sampling settings. It does not store already rendered figures or CSV exports.
The project's `name` and `metadata` may contain additional information.

For unchanged imports, passing `original` reproduces the original file bytes,
including CRLF endings and coefficient spelling. Edited coefficients are written
with 17 significant digits for double-precision round trips. All **19 supplied
system files** are included unchanged. The untouched MATLAB distribution remains
in the adjacent `asta_matlab_GBp` folder. `original_manifest.json` records its
file hashes. CSV exports are sampled analysis data; save the project as well if
you want the underlying models and metadata.

## Limits and interpretation

Exact behavior of hidden `.p` functions, undocumented features, original GUI
layout, original callback APIs and legacy project formats cannot be verified.
Only the documented NS/DS plant-file format is imported; unknown formats are
rejected instead of guessed. This rebuild does not execute protected `.p` files.

Peak frequency, bandwidth, rise and settling metrics depend on the sampling
range/resolution. Peak-at-grid-boundary flags warn when a peak may lie outside the
range. Settling is an observed finite-horizon estimate; NaN means it was not
observed, or a steady-state metric is undefined/unstable. Increase the time range
to assess later excursions. A single reported delay margin is computed as
phase-margin radians divided by its crossover frequency only for stable loops
with positive finite phase margin; it is not a general delay-robustness certificate
for systems with multiple crossovers.

The lab's rounded time-domain numbers are reproduced. The equations give slightly
different frequency numbers from its table. See PORTING_REPORT.md for measured
results and the scope of verification. Full lossless equivalence requires the
original MATLAB source or black-box comparison runs of the original application.

Official references:
- https://docs.octave.org/latest/Status-of-Variables.html (no `.p` support)
- https://gnu-octave.github.io/pkg-control/ (control package)
- https://octave.sourceforge.io/control/function/margin.html (margin units)
