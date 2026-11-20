import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const artifactDir=fileURLToPath(new URL('../examples/',import.meta.url));
const targets=await(await fetch((process.env.ASTA_CDP_URL||'http://127.0.0.1:9222')+'/json')).json();
const ws=new WebSocket(targets.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise(r=>ws.addEventListener('open',r,{once:true}));
let seq=0;const pending=new Map();ws.addEventListener('message',e=>{const m=JSON.parse(e.data);if(m.id){const {resolve,reject}=pending.get(m.id)||{};pending.delete(m.id);m.error?reject(m.error):resolve(m.result);}});
function call(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});}
async function evaluate(expression){const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function wait(expression,timeout=30000){const end=Date.now()+timeout;while(Date.now()<end){if(await evaluate(expression))return;await new Promise(r=>setTimeout(r,100));}throw Error('Timed out: '+expression);}
await call('Page.enable');await call('Runtime.enable');await call('Emulation.setDeviceMetricsOverride',{width:1440,height:1100,deviceScaleFactor:1,mobile:false});await call('Page.navigate',{url:process.env.ASTA_TEST_URL||'http://127.0.0.1:8765'});
await wait('typeof state!=="undefined"');
await evaluate('localStorage.removeItem("asta-studio-v1")');await call('Page.reload');
await wait('typeof state!=="undefined" && state.results.length===1 && !state.busy');
if(!(await evaluate('state.systems.length===19 && document.getElementById("library").options.length===20')))throw Error('Model library did not load');
console.log('Initial:',await evaluate('({overshoot:document.getElementById("m-overshoot").textContent,error:document.getElementById("error").textContent,engine:document.getElementById("performance").textContent})'));
await evaluate('document.getElementById("remember").click()');await wait('state.results.length===2&&!state.busy');
await evaluate('document.getElementById("controller").value="pd-output";document.getElementById("P").value="10";document.getElementById("project-name").value="Lab · PD on output";setupController();state.revision++;update()');await wait('!state.busy && state.project.K.num[0]>9');
console.log('PD:',await evaluate('({overshoot:document.getElementById("m-overshoot").textContent,settling:document.getElementById("m-settle").textContent,comparisons:state.snapshots.length,error:document.getElementById("error").textContent})'));
if(!(await evaluate('Math.abs(state.results[0].data.statistics.time.overshoot_percent-11.095)<.2')))throw Error('Wrong PD response');
const networkBefore=await evaluate('performance.getEntriesByType("resource").filter(e=>e.name.endsWith("/api/compute")).length');
const views=['open','closed','control','reference','nichols','nyquist','bode','s','t','w'];
for(const view of views){await evaluate(`setDomain(${JSON.stringify(['open','closed','control','reference'].includes(view)?'time':'frequency')},${JSON.stringify(view)})`);await new Promise(r=>setTimeout(r,80));if(!(await evaluate('panels.length>0&&panels[0].series.length===2')))throw Error('View failed '+view);}
if(await evaluate('performance.getEntriesByType("resource").filter(e=>e.name.endsWith("/api/compute")).length')!==networkBefore)throw Error('View changes made network calls');
await evaluate('setDomain("time","closed")');await new Promise(r=>setTimeout(r,150));
await fs.writeFile(artifactDir+'studio_desktop.png',Buffer.from((await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true})).data,'base64'));
// Invalid edits retain the previous valid result.
await evaluate('document.getElementById("G-den").value="0";state.revision++;update()');await wait('!state.busy');if(!(await evaluate('document.getElementById("error").textContent.includes("denominator")&&state.results.length===2')))throw Error('Invalid input not handled');
await evaluate('document.getElementById("G-den").value="1 2 1 0";state.revision++;update()');await wait('!state.busy');
// Restore a saved design via its visible control.
await evaluate('document.querySelector(".comparison-row button").click()');await wait('!state.busy');if(!(await evaluate('Math.abs(state.results[0].data.statistics.control_peak_abs-4.8)<1e-8')))throw Error('Restore failed');
// Session round-trip and exact imported model text.
if(!(await evaluate('(()=>{const v=session();loadSession(JSON.parse(JSON.stringify(v)));return JSON.stringify(session())===JSON.stringify(v)})()')))throw Error('Session mismatch');
if(!(await evaluate('(()=>{const t="NS\\r\\n0.1 \\r\\nDS\\r\\n1 2 1 0";return parseSystem(t).den.length===4})()')))throw Error('NS/DS parser failed');
// Exercise drag zoom and two-point measurement with real pointer events.
const plot=await evaluate('(()=>{const b=canvas.getBoundingClientRect(),p=panels[0];return {x:b.left+p.x,y:b.top+p.y,w:p.w,h:p.h}})()');
async function mouse(type,x,y,pressed=false){await call('Input.dispatchMouseEvent',{type,x,y,button:type==='mouseMoved'?'none':'left',buttons:pressed?1:0,clickCount:1});}
await mouse('mousePressed',plot.x+plot.w*.2,plot.y+plot.h*.2,true);
await mouse('mouseMoved',plot.x+plot.w*.8,plot.y+plot.h*.8,true);
await mouse('mouseReleased',plot.x+plot.w*.8,plot.y+plot.h*.8);
await new Promise(r=>setTimeout(r,80));
if(!(await evaluate('Object.keys(zoom).length===1')))throw Error('Drag zoom failed');
await evaluate('document.getElementById("reset-zoom").click()');await new Promise(r=>setTimeout(r,80));
for(const f of [.2,.4]){await mouse('mousePressed',plot.x+plot.w*f,plot.y+plot.h*.5,true);await mouse('mouseReleased',plot.x+plot.w*f,plot.y+plot.h*.5);}
if(!(await evaluate('document.getElementById("measurement").textContent.includes("Δt")')))throw Error('Point measurement failed');
// Download actual sampled data, figures, a session and unchanged imported bytes.
const downloads=await fs.mkdtemp('/tmp/asta-downloads-');
await call('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloads});
for(const id of ['export-csv','export-svg','export-png','save-session'])await evaluate(`document.getElementById(${JSON.stringify(id)}).click()`);
for(let j=0;j<50;j++){if((await fs.readdir(downloads)).filter(n=>!n.endsWith('.crdownload')).length>=4)break;await new Promise(r=>setTimeout(r,100));}
for(const name of ['asta-closed.csv','asta-closed.svg','asta-closed.png','asta-project.json'])if(!(await fs.stat(downloads+'/'+name)).size)throw Error('Empty export '+name);
const csv=await fs.readFile(downloads+'/asta-closed.csv','utf8');if(!csv.startsWith('time_s,response\n')||csv.split('\n').length<1202)throw Error('CSV export lost samples');
const original=fileURLToPath(new URL('../systeme/ath3.syst',import.meta.url));
const doc=await call('DOM.getDocument');const input=await call('DOM.querySelector',{nodeId:doc.root.nodeId,selector:'#model-file'});
await call('DOM.setFileInputFiles',{nodeId:input.nodeId,files:[original]});
await wait('!state.busy && state.metadata.G?.filename==="ath3.syst"');
await evaluate('document.getElementById("export-model").click()');
for(let j=0;j<50;j++){try{await fs.stat(downloads+'/ath3.syst');break;}catch{}await new Promise(r=>setTimeout(r,100));}
if(!(await fs.readFile(original)).equals(await fs.readFile(downloads+'/ath3.syst')))throw Error('Imported bytes were changed');
await evaluate('document.getElementById("reset-project").click()');await wait('!state.busy');
// Small viewport must not overflow horizontally.
await call('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await new Promise(r=>setTimeout(r,200));
console.log('Mobile overflow:',await evaluate('document.documentElement.scrollWidth>innerWidth'));
if(await evaluate('document.documentElement.scrollWidth>innerWidth'))throw Error('Mobile overflow');
await fs.writeFile(artifactDir+'studio_mobile.png',Buffer.from((await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true})).data,'base64'));
console.log('PASS: browser startup, P/PD, comparisons, all 10 views, errors, restore, sessions, model library, model parser, drag zoom, measurement, file exports, unchanged import bytes and mobile layout.');
ws.close();
