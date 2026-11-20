'use strict';

// Labels match MATLAB ASTA; values come from Octave, never from rounded cards.
const statisticsRows = {
  time: [
    {label: 'Y infini', key: 'time.final_value', unit: '', meaning: 'Final output y(∞)'},
    {label: 'Static Error (%)', key: 'time.static_error_percent', unit: '%', meaning: '100 × (1 − y(∞)), for a unit reference'},
    {label: 'Y max', key: 'time.maximum_output', unit: '', meaning: 'Maximum sampled output'},
    {label: 'Mp (%)', key: 'time.overshoot_percent', unit: '%', meaning: 'Overshoot relative to the final output'},
    {label: 'Tp (s)', key: 'time.peak_time', unit: 's', meaning: 'Time of the directional response peak'},
    {label: 'Ts (5%) (s)', key: 'time.settling_time_5_percent', unit: 's', meaning: 'Observed settling within ±5% of final output'},
    {label: 'Ts (2%) (s)', key: 'time.settling_time_2_percent', unit: 's', meaning: 'Observed settling within ±2% of final output'}
  ],
  frequency: [
    {label: '|T(jω)| max (dB)', key: 'T_peak_db', unit: 'dB', meaning: 'Absolute maximum complementary-sensitivity magnitude'},
    {label: 'Wr (rad/s)', key: 'T_peak_frequency', unit: 'rad/s', meaning: 'Frequency of the sampled T peak'},
    {label: '|T(0)| (dB)', key: 'T_dc_db', unit: 'dB', meaning: 'DC magnitude: 20 log₁₀|T(0)|'},
    {label: 'Mr (dB)', key: 'resonance_ratio_db', unit: 'dB', meaning: 'T peak above its DC magnitude'},
    {label: 'Wc (rad/s)', key: 'bandwidth_3db', unit: 'rad/s', meaning: 'Bandwidth at 3 dB below the DC magnitude'}
  ]
};
let statisticsSelection = 0;

function statisticValue(statistics, key) {
  return key.split('.').reduce((value, part) => value?.[part], statistics);
}

function statisticText(value) {
  if (value === 'Infinity' || value === Infinity) return '∞';
  if (value === '-Infinity' || value === -Infinity) return '−∞';
  if (typeof value !== 'number' || !Number.isFinite(value)) return '—';
  const precision = $('statistics-precision').value;
  return precision === 'full' ? String(value) : String(Number(value.toPrecision(Number(precision))));
}

function statisticsDesigns() {
  const select = $('statistics-design');
  select.replaceChildren(...state.results.map((result, index) =>
    new Option(result.data.name + (index ? ` · saved ${index}` : ' · current'), String(index))));
  if (statisticsSelection >= state.results.length) statisticsSelection = 0;
  select.value = String(statisticsSelection);
}

function renderStatistics() {
  const result = state.results[statisticsSelection];
  if (!result) return;
  const a = result.data.statistics;
  for (const domain of ['time', 'frequency']) {
    const body = $(domain + '-statistics-table').querySelector('tbody');
    body.replaceChildren(...statisticsRows[domain].map(row => {
      const tr = document.createElement('tr');
      tr.dataset.statistic = row.key;
      const label = document.createElement('td'); label.textContent = row.label;
      const cell = document.createElement('td');
      const value = statisticValue(a, row.key);
      cell.textContent = statisticText(value);
      cell.dataset.rawValue = String(value);
      cell.title = `${row.meaning}. Full value: ${value}${row.unit ? ' ' + row.unit : ''}`;
      const meaning = document.createElement('td'); meaning.textContent = row.meaning;
      tr.append(label, cell, meaning);
      return tr;
    }));
  }
  const notices = [];
  if (state.statisticsRevision !== state.revision) notices.push('Showing the last calculated response. Update response to include your edits.');
  if (!a.closed_loop_stable) notices.push('Unstable closed loop: steady-state, overshoot and settling statistics are undefined. Y max is only the maximum within the sampled horizon.');
  if (a.T_peak_at_grid_boundary) notices.push('The T peak is at the frequency-range boundary. Expand the range to check the resonance.');
  const notice = $('statistics-notice');
  notice.textContent = notices.length ? notices.join(' ') : `Calculated statistics for ${result.data.name}.`;
  notice.classList.toggle('warning', notices.length > 0);
  const time = result.data.time, omega = result.data.omega;
  $('statistics-sampling').textContent = `Sampling: 0–${time[time.length - 1]} s (${time.length.toLocaleString()} points); ${omega[0]}–${omega[omega.length - 1]} rad/s (${omega.length.toLocaleString()} points). Peaks and settling times depend on this sampling.`;
  $('statistics-refresh').disabled = state.busy;
}

function openStatistics() {
  if (!state.results.length) { error('Update the response before opening statistics.'); return; }
  statisticsDesigns(); renderStatistics();
  if (!$('statistics-dialog').open) $('statistics-dialog').showModal();
}

function exportStatistics() {
  const result = state.results[statisticsSelection];
  if (!result) return;
  const d = result.data;
  const rows = [['domain', 'matlab_label', 'value', 'unit', 'meaning', 'design', 'time_end_s', 'time_samples', 'omega_min_rad_s', 'omega_max_rad_s', 'frequency_samples']];
  for (const domain of ['time', 'frequency']) {
    for (const row of statisticsRows[domain]) {
      rows.push([domain, row.label, statisticValue(d.statistics, row.key), row.unit, row.meaning, d.name,
        d.time[d.time.length - 1], d.time.length, d.omega[0], d.omega[d.omega.length - 1], d.omega.length]);
    }
  }
  // Values use full round-trip precision independently of the display selector.
  const escape = value => '"' + String(value ?? '').replaceAll('"', '""') + '"';
  download('asta-statistics.csv', rows.map(row => row.map(escape).join(',')).join('\n'), 'text/csv');
}

function bindStatistics() {
  $('show-statistics').onclick = openStatistics;
  $('close-statistics').onclick = () => $('statistics-dialog').close();
  $('statistics-dialog').addEventListener('close', () => $('show-statistics').focus());
  $('statistics-design').onchange = () => { statisticsSelection = Number($('statistics-design').value); renderStatistics(); };
  $('statistics-precision').onchange = () => { renderStatistics(); persist(); };
  $('statistics-csv').onclick = exportStatistics;
  $('statistics-refresh').onclick = update;
  $('statistics-dialog').addEventListener('click', event => {
    if (event.target !== $('statistics-dialog')) return;
    const bounds = event.target.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom) event.target.close();
  });
}
