# Verification and remaining parity work

Date: 19 November 2026.

Evidence: `ASTA_Help_M1_CORO_2627.pdf`, the original `liste_uimenu.txt`, supplied
NS/DS files, and the equations in the lab guide. The original `asta.hlp` is a
Windows Help binary; its embedded labels confirm the three-window structure but
it is not a complete executable specification. Protected `.p` files were not
translated or decrypted. No claim of complete parity is made.

## Numerical lab comparison

Time vector: 0 to 40 s, step 0.005 s. Frequency vector: 20,000 logarithmically
spaced points, 0.001 to 1000 rad/s. Peak values below are sampled estimates.

| Metric | Guide P=4.8 | Rebuild P=4.8 | Guide PD-output | Rebuild PD-output |
|---|---:|---:|---:|---:|
| T peak (dB) | 2.32 | 2.3408 | 1.86 | 1.8612 |
| Resonance frequency (rad/s) | 0.461 | 0.4473 | 0.752 | 0.7615 |
| T bandwidth, -3 dB (rad/s) | 0.734 | 0.7305 | 1.3 | 1.3083 |
| Overshoot (%) | 23.5 | 23.584 | 11.0 | 11.095 |
| Peak time (s) | 6.9 | 6.885 | 4.7 | 4.755 |
| Settling, 5% (s) | 14.2 | 14.200 | 6.0 | 6.075 |
| Settling, 2% (s) | 15.7 | 15.785 | 8.9 | 8.920 |
| Peak absolute control | 4.8 | 4.8 | 10 | 10 |

The guide's frequency values do not exactly follow its printed equations at the
stated controller values. Tests use the stated equations and explicit tolerances;
they do not adjust the model to reproduce the rounded table. PD-output is also
checked against a separately assembled four-state plant/filter realization.

## Checks

`tests/run_tests.m` checks:

- Feedback identities S+T=1 and G*U=Y.
- Both lab controllers and their time/frequency characteristics.
- Independent state-space simulation of derivative on measured output.
- All 19 supplied system files, coefficient equality and byte-identical re-export.
- Double-precision coefficient round trips through text files.
- Binary project model/metadata round trips and GUI comparison-session storage.
- Unstable loops and insufficient time horizons do not get fabricated settling metrics.
- Arbitrary-input simulation agrees with the unit step for an all-ones input.
- Frequency measurements, CSV data precision, invalid file rejection, presets.

Main-window construction and all ten response plot types were additionally
smoke-tested with the available gnuplot backend. Five lab plots were exported.
Interactive menu/dialog behavior is implemented but awaits testing with Qt.

## Feature coverage

| Documented feature | Rebuild | Verification |
|---|---|---|
| G, K, R polynomial entry | GUI and API | Core validation; desktop dialog untested |
| Classical model/controller structures | Common presets plus arbitrary rational entry | Preset creation tested; original full preset list unknown |
| PD derivative on measured output | Equivalent K/R factorization | Independent simulation tested |
| Plant text load/save | Strict NS/DS parser/writer | All supplied files tested |
| Time-domain open/closed/control/reference | Plot and response API | Lab and plot checks |
| Nichols, Nyquist, Bode, S/T/W | Plot and frequency API | All plot types constructed |
| Nichols contours, including 2.3 dB | Magnitude and phase contours | Static export generated |
| Statistics | Margins, peaks, time metrics | Numerical lab checks; finite-grid limits documented |
| Superposition/plot manager/domain transfer | Project snapshots and menus | Overlay export and session storage tested; interactive actions untested |
| Point cursor/gain/phase/time measurements | Menus plus sampled-data API | Measurement API tested; mouse selection untested |
| Zoom/legend/ranges/figure export | Menus and plot API | Static plotting/export tested; mouse zoom untested |
| Project save/load | Rebuild's native .asta format | Model/metadata/session round trips tested |
| Original MATLAB project formats | Unknown | Not supported without samples/specification |
| Original protected helper API and exact layout | Not replicated | Original source/reference required |
| Other undocumented functionality | Unknown | Cannot assert parity |

## To establish full parity

Obtain original unprotected `.m` files or run an original MATLAB reference and
record its complete menus, presets, data formats and numerical behavior. Compare
callbacks and edge cases, validate legacy saved projects, and exercise the Octave
GUI on Qt. The existing original files are retained so they can be used for this
work later.

## Studio UI and performance update

ASTA Studio adds a local browser interface backed by persistent Octave calculations.
The original native and command interfaces remain available. The complete numerical
suite passes after bounded model caching and removal of a duplicate T frequency
calculation. Browser interactions were exercised in Chrome at desktop and mobile
widths, including actual zoom/measurement gestures and downloaded files. See
STUDIO.md for exact test coverage, measured timings and format compatibility.
This resolves the Qt requirement for the new Studio UI; it does not establish
parity with the protected original MATLAB implementation.

## MATLAB-labelled statistics (version 1.1.0)

A new Statistics dialog displays all twelve time/frequency labels from the
provided MATLAB ASTA screenshot, in separate tables. It adds signed unit-reference
static error, explicitly sampled maximum/minimum output and DC magnitude in dB.
Tests verify final value 6/7 and static error 100/7 for a non-unit-gain example;
reference-prefilter effects; the T-peak-minus-DC definition of Mr; zero/negative
outputs; and infinite/undefined cases. The example screenshot is illustrative,
not a numerical reproduction of a MATLAB run with unknown model coefficients.

Browser checks cover all twelve label mappings, current/saved design selection,
6/10/full display precision, full-precision CSV, stale-result messages, keyboard
focus/dismissal and mobile layout. The existing plotting workflow and isolated
Octave install/load/launch/unload/uninstall checks pass.
