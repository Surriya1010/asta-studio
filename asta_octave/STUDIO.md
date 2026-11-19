# ASTA Studio

The default launcher now opens a local browser workspace. GNU Octave still
computes the models, responses and statistics; Python serves the interface and
coordinates one persistent Octave process. Qt graphics are not required.

As an installed Octave package:

```octave
pkg load astastudio
astastudio
```

Use `astastudio('test')` for self-tests and `astastudio('info')` for installed
paths. `pkg unload astastudio` removes its functions from the Octave path; an
already running browser server continues until its process is stopped. See the
repository README for the installation URL and package requirements.

From a source checkout in Octave (the CLACO folder in the original workspace):

```octave
start_asta_octave
```

From a terminal in the CLACO folder:

```sh
python3 asta_octave/studio/server.py
```

The terminal command opens `http://127.0.0.1:8765`. Keep it running; Ctrl+C stops
it. Use `--no-browser` to print the address without opening a tab, or `--port 8770`
if the default port is occupied. The Octave launcher starts the service in the
background and reuses an existing Studio on port 8765. Its automatic launcher is
implemented for Linux/macOS; on other platforms use the Python terminal command.
Requires Python 3 and `octave-cli` with the control package, both available here.
No JavaScript packages, external servers, accounts or CDNs are needed.

## Workspace

- **Left:** edit the plant and controller directly, load any of the 19 supplied
  models, and optionally add a reference prefilter. P/PI/PD/PID and derivative
  on output are available. Custom rational controllers use numerator/denominator
  fields. Coefficients accept decimal and scientific notation.
- **Centre:** switch between all ten time/frequency responses without recalculating.
  Nichols includes closed-loop magnitude contours and the 2.3 dB contour.
  Nyquist includes both branches and the critical point. Bode shows magnitude
  and phase together. Drag a rectangle to zoom; Reset zoom restores the range.
  Hover for sampled coordinates. Click two points on the same design to measure
  differences in time/frequency, ordinate, gain and phase.
- **Right:** stable/unstable indication, overshoot, observed settling and rise time,
  control peak, gain/phase/delay margins, T resonance and bandwidth. Expand All
  statistics for the full result. Infinity and undefined values remain distinct
  in exported statistics (`Infinity`, `-Infinity`, `NaN` strings).
- **Below:** control sampling and retain up to 12 comparison designs. Remember
  current requires an up-to-date response. Comparisons can be hidden, restored
  or removed. The current design and saved designs are labelled in the legend.

Changes automatically update after a 500 ms pause. Turn off Update after edits
for manual operation. Ctrl/Cmd+Enter updates; Ctrl/Cmd+S downloads a project.
Invalid edits retain the last valid response and show an actionable error.
The layout adapts to narrow screens and supports keyboard focus and reduced motion.

## Performance and precision

A persistent worker avoids starting Octave on each update. Model assemblies use
an exact-value LRU cache of 12 entries; unchanged analyses use a separate result
cache bounded to 16 entries / 32 MiB. The original transfer functions and state-
space realizations are retained in the numerical API. No model-order reduction
was added for speed. View switching, zoom and hover happen locally in the browser.

Sampling presets are explicit: 1,201 points (Fast), 4,001 (Detailed), 20,001 (Fine),
or 101–50,001 custom points per domain. Response metrics depend on this grid;
select Fine to compare with the original lab calculations. Large curves are drawn
using extrema-preserving display buckets; all calculated points remain available
in memory and in CSV exports. This display optimization does not alter model
coefficients or sampled data. SVG exports use all points; PNG captures the
currently displayed chart. SVG exports contain data curves and axes; PNG also
includes the Nichols background contours.

A local benchmark with 4,001 samples in each domain measured a first request of
671 ms and repeat cached requests of 65–82 ms, returning identical numerical data
(about 8–10× faster for this repeated request). The measured Octave portion was
411 ms. These are measurements on this machine, not a comparison against MATLAB;
timing varies with model order, sampling, cache state and hardware.

## Saving and importing

Save project downloads `.json` containing the full editable draft, exact numeric
coefficients, original imported plant text, sampling settings and comparison
projects. Open loads that format. An editable draft is also stored in this
browser's local storage; download a project to keep a portable copy. JSON uses
JavaScript/IEEE double round-trip serialization. Numeric data are not rounded
for storage or CSV export. Only displayed labels are rounded.

Import/Export under Plant handles the original NS/DS `.syst`/`.txt` format.
Unchanged files are exported with their original text, including CRLF endings.
All 19 original library models remain available. Controller/reference models
can be edited directly; the original native APIs also retain their model export
functions. The extra prefilter in the editor multiplies the automatically generated
reference factor for derivative-on-output controllers.

CSV exports the **current design** and selected response at full sampled precision.
SVG and PNG export the displayed comparisons. Frequency CSV contains omega,
real/imaginary response, magnitude, dB and phase. Saved Studio projects preserve
comparisons; exported CSV/figures are separate analysis outputs.

Studio JSON is a new workspace format. Existing `.asta` binary projects remain
supported through `asta_load`, `asta_save` and the native interface (`asta()`);
Studio does not import those binary files. Arbitrary-input `lsim` simulation and
less common plant templates also remain available through the Octave API. The
native GUI still requires Qt. The protected original MATLAB `.p` code is unchanged;
full original feature parity is still not established.

## Verification

- Existing `run_tests` numerical/legacy-model suite: passed after optimization.
- `tests/studio_api.py`: timings, identical cached data, invalid ranges and local
  request-origin restrictions.
- `tests/studio_browser.mjs`: Chrome DevTools test against a local browser on port
  9222. Checks both lab controllers, all ten views, view changes without network
  calls, 19 library models, comparisons, restoration, session round trips, invalid
  edits, real drag zoom, two-point measurement, CSV/SVG/PNG/project downloads,
  unchanged CRLF model export, and 390 px mobile layout without horizontal overflow.

Desktop and mobile screenshots are in `examples/studio_desktop.png` and
`examples/studio_mobile.png`. Browser tests use an isolated testing profile and
write downloads to a new temporary directory.
