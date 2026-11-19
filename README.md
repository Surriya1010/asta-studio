# ASTA Studio

A local control-design workspace for GNU Octave. Edit SISO plants and controllers,
compare designs, and inspect time/frequency responses in a browser. Octave performs
the calculations in a persistent worker; the interface works without Qt graphics.

![ASTA Studio](asta_octave/examples/studio_desktop.png)

## Run

Requires Python 3, GNU Octave (`octave-cli`) and the Octave `control` package.
Tested with Octave 11.1.0 and control 4.2.1. No JavaScript dependencies or external
services are required.

From the repository folder, run:

```sh
python3 asta_octave/studio/server.py
```

Or, in Octave from the repository folder:

```octave
start_asta_octave
```

Open the printed local address, normally http://127.0.0.1:8765. The terminal server
stops with Ctrl+C. The Octave launcher starts it in the background. Use `--port 8770`
for a different port, or `--no-browser` to avoid automatically opening a tab.

## Features

- Inline plant and controller editing; P, I, PI, PD and PID presets.
- Filtered derivative on output and optional reference prefilter.
- Open/closed-loop, control and reference step responses.
- Nichols, Nyquist, Bode, sensitivity and complementary-sensitivity plots.
- Visible response metrics and stability margins.
- Comparison snapshots, drag zoom, point inspection and measurements.
- CSV/SVG/PNG export, JSON workspace save/load, and original NS/DS model import/export.
- Persistent Octave engine, bounded caches, and view switching without recalculation.
- Responsive desktop/mobile layout and 19 supplied example plant models.

Numerical coefficients and sampled exports retain double precision. Displayed
statistics are sampled estimates; choose a finer grid for more precise values.
A measured 4,001-point request took 671 ms initially and 65–82 ms from cache on the
development machine, with identical numerical results. This is a cache comparison,
not a MATLAB performance benchmark.

## Tests

Run the numerical checks from the repository folder:

```sh
octave --no-gui --quiet --eval "addpath('asta_octave/tests'); run_tests"
```

With Studio running, test the API:

```sh
python3 asta_octave/tests/studio_api.py
```

`asta_octave/tests/studio_browser.mjs` provides browser interaction checks using
an isolated Chrome instance with remote debugging on local port 9222.

## Documentation and scope

See [Studio controls and performance](asta_octave/STUDIO.md),
[Octave API and native interface](asta_octave/README.md), and
[verification and feature coverage](asta_octave/PORTING_REPORT.md).

This is a documentation-based rebuild of the ASTA SISO teaching tool. The original
MATLAB implementation was supplied as protected `.p` files. It has not been
translated or decrypted, and complete original feature parity is not established.
Original protected code and course PDFs are not included in this repository.
The original asset hash manifest is retained for provenance. Studio JSON projects
and native Octave `.asta` projects are distinct formats; see the documentation.
