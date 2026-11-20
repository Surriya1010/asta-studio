import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const origin=process.env.ASTA_TEST_URL||'http://127.0.0.1:8771';
const debugging=process.env.ASTA_CDP_URL||'http://127.0.0.1:9223';
const output=fileURLToPath(new URL('../examples/',import.meta.url));
const targets=await(await fetch(debugging+'/json')).json();
const ws=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);
await new Promise(resolve=>ws.addEventListener('open',resolve,{once:true}));
let sequence=0;const waiting=new Map(),exceptions=[];
ws.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.method==='Runtime.exceptionThrown')exceptions.push(message.params.exceptionDetails);if(message.id){const entry=waiting.get(message.id);waiting.delete(message.id);message.error?entry.reject(message.error):entry.resolve(message.result);}});
const call=(method,params={})=>new Promise((resolve,reject)=>{const id=++sequence;waiting.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
async function evaluate(expression){const answer=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(answer.exceptionDetails)throw Error(JSON.stringify(answer.exceptionDetails));return answer.result.value;}
async function wait(expression){const end=Date.now()+30000;while(Date.now()<end){if(await evaluate(expression))return;await new Promise(r=>setTimeout(r,80));}throw Error('Timed out: '+expression);}
async function assert(expression,message){if(!(await evaluate(expression)))throw Error(message);}
const cell=key=>`document.querySelector('[data-statistic="${key}"] td:nth-child(2)')`;
await call('Page.enable');await call('Runtime.enable');
await call('Emulation.setDeviceMetricsOverride',{width:1440,height:1100,deviceScaleFactor:1,mobile:false});
await call('Page.navigate',{url:origin});await wait('typeof state!=="undefined"');
await evaluate('localStorage.removeItem("asta-studio-v1")');await call('Page.reload');
await wait('typeof state!=="undefined"&&state.results.length===1&&!state.busy');
const requests=await evaluate('performance.getEntriesByType("resource").filter(r=>r.name.endsWith("/api/compute")).length');
await evaluate('document.getElementById("show-statistics").click()');
await assert('document.getElementById("statistics-dialog").open','Statistics did not open');
await assert('document.querySelectorAll("#time-statistics-table tbody tr").length===7','Time rows missing');
await assert('document.querySelectorAll("#frequency-statistics-table tbody tr").length===5','Frequency rows missing');
await assert(`${cell('time.overshoot_percent')}.dataset.rawValue===String(state.results[0].data.statistics.time.overshoot_percent)`,'Wrong metric mapping');
if(await evaluate('performance.getEntriesByType("resource").filter(r=>r.name.endsWith("/api/compute")).length')!==requests)throw Error('Opening statistics recalculated data');
// Non-unit DC gain exposes the distinction between absolute T peak and Mr.
await evaluate(`document.getElementById('auto-update').checked=false;
for(const [id,value] of Object.entries({'project-name':'P = 6 · non-unit final value','G-num':'1','G-den':'1 2 1',controller:'p',P:'6','R-num':'1','R-den':'1'}))document.getElementById(id).value=value;
setupController();markChanged();`);
await assert('document.getElementById("statistics-notice").textContent.includes("last calculated")','Stale results not identified');
await evaluate('update()');await wait('!state.busy&&state.statisticsRevision===state.revision');
await assert(`${cell('time.final_value')}.textContent==='0.857143'`,'Wrong final value');
await assert(`${cell('time.static_error_percent')}.textContent==='14.2857'`,'Wrong static error');
await assert('Math.abs(state.results[0].data.statistics.resonance_ratio_db-(state.results[0].data.statistics.T_peak_db-state.results[0].data.statistics.T_dc_db))<1e-12','Mr was confused with T peak');
await assert('document.getElementById("statistics-sampling").textContent.includes("1,201")','Sampling context missing');
await evaluate('document.getElementById("statistics-precision").value="full";document.getElementById("statistics-precision").dispatchEvent(new Event("change"))');
await assert(`${cell('time.final_value')}.textContent===String(state.results[0].data.statistics.time.final_value)`,'Full precision was truncated');
await evaluate('document.getElementById("statistics-precision").value="6";document.getElementById("statistics-precision").dispatchEvent(new Event("change"))');
await fs.writeFile(output+'studio_statistics.png',Buffer.from((await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true})).data,'base64'));
// Saved designs can be inspected independently of the active design.
await evaluate('document.getElementById("close-statistics").click();document.getElementById("remember").click()');
await wait('state.results.length===2&&!state.busy');
await evaluate('document.getElementById("P").value="3";document.getElementById("project-name").value="P = 3";markChanged();update()');
await wait('!state.busy');await evaluate('document.getElementById("show-statistics").click()');
await assert(`${cell('time.static_error_percent')}.textContent==='25'`,'Current design not selected');
await evaluate('document.getElementById("statistics-design").value="1";document.getElementById("statistics-design").dispatchEvent(new Event("change"))');
await assert(`${cell('time.static_error_percent')}.textContent==='14.2857'`,'Saved design statistics incorrect');
// CSV contains all twelve labels and full values, regardless of display precision.
const downloads=await fs.mkdtemp('/tmp/asta-statistics-downloads-');
await call('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloads});
await evaluate('document.getElementById("statistics-csv").click()');
for(let n=0;n<50;n++){try{await fs.stat(downloads+'/asta-statistics.csv');break;}catch{}await new Promise(r=>setTimeout(r,80));}
const csv=await fs.readFile(downloads+'/asta-statistics.csv','utf8');
if(csv.split('\n').length!==13||!csv.includes('"0.8571428571428571"')||!csv.includes('Static Error (%)')||!csv.includes('Mr (dB)'))throw Error('Incomplete statistics CSV');
// Escape closes the dialog and returns keyboard focus to its opener.
await call('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
await call('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});
await assert('!document.getElementById("statistics-dialog").open&&document.activeElement.id==="show-statistics"','Dialog keyboard dismissal/focus failed');
// Unstable responses must not appear to have valid steady-state metrics.
await evaluate('document.getElementById("G-den").value="1 -2";document.getElementById("P").value="1";markChanged();update()');
await wait('!state.busy');await evaluate('document.getElementById("show-statistics").click()');
await assert('document.getElementById("statistics-notice").textContent.includes("Unstable")','Unstable report warning missing');
await assert(`${cell('time.final_value')}.textContent==='—'&&${cell('time.static_error_percent')}.textContent==='—'`,'Undefined statistics misrepresented');
// Infinite dB values remain distinct from undefined metrics.
await evaluate('document.getElementById("G-num").value="1 0";document.getElementById("G-den").value="1 1";markChanged();update()');
await wait('!state.busy');
await assert(`${cell('T_dc_db')}.textContent==='−∞'&&${cell('resonance_ratio_db')}.textContent==='∞'`,'Infinity values were lost');
// Return to a representative design before checking the narrow-screen report.
await evaluate('document.getElementById("G-num").value="1";document.getElementById("G-den").value="1 2 1";document.getElementById("P").value="6";document.getElementById("project-name").value="P = 6 · non-unit final value";markChanged();update()');
await wait('!state.busy');
await call('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});
await new Promise(r=>setTimeout(r,100));
await assert('document.documentElement.scrollWidth<=innerWidth','Mobile report overflow');
await assert('document.getElementById("statistics-dialog").scrollWidth<=document.getElementById("statistics-dialog").clientWidth','Dialog overflow');
await fs.writeFile(output+'studio_statistics_mobile.png',Buffer.from((await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true})).data,'base64'));
if(exceptions.length)throw Error('Browser exceptions: '+JSON.stringify(exceptions));
console.log('PASS: MATLAB labels, exact metric mapping, static error, DC/Mr distinction, stale results, saved designs, precision, CSV, keyboard focus, unstable/infinite values and mobile layout.');
ws.close();
