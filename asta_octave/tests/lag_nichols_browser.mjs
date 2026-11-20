import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const origin=process.env.ASTA_TEST_URL||'http://127.0.0.1:8771';
const debuggerURL=process.env.ASTA_CDP_URL||'http://127.0.0.1:9223';
const output=fileURLToPath(new URL('../examples/',import.meta.url));
const tabs=await(await fetch(debuggerURL+'/json')).json();
const ws=new WebSocket(tabs.find(tab=>tab.type==='page').webSocketDebuggerUrl);
await new Promise(resolve=>ws.addEventListener('open',resolve,{once:true}));
let id=0;const pending=new Map(),errors=[];
ws.addEventListener('message',event=>{const m=JSON.parse(event.data);if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}});
const call=(method,params={})=>new Promise((resolve,reject)=>{const next=++id;pending.set(next,{resolve,reject});ws.send(JSON.stringify({id:next,method,params}));});
async function evaluate(expression){const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function assert(expression,message){if(!(await evaluate(expression)))throw Error(message);}
async function wait(expression){const end=Date.now()+30000;while(Date.now()<end){if(await evaluate(expression))return;await new Promise(resolve=>setTimeout(resolve,80));}throw Error('Timed out: '+expression);}
await call('Page.enable');await call('Runtime.enable');
await call('Emulation.setDeviceMetricsOverride',{width:1440,height:1100,deviceScaleFactor:1,mobile:false});
await call('Page.navigate',{url:origin});await wait('typeof state!=="undefined"');
await evaluate('localStorage.removeItem("asta-studio-v1")');await call('Page.reload');
await wait('typeof state!=="undefined"&&state.results.length===1&&!state.busy');
await evaluate('setDomain("frequency","nichols")');await wait('!renderQueued');
await assert('nicholsReference.db===2.3 && document.querySelectorAll("[data-reference=m-circle]").length===1','Expected exactly one 2.3 dB reference');
await assert('nicholsReference.points.every(([phase,db])=>{const mag=10**(db/20),a=phase*Math.PI/180;return Math.abs(20*Math.log10(mag/Math.hypot(1+mag*Math.cos(a),mag*Math.sin(a)))-2.3)<1e-10})','Incorrect M-contour geometry');
function pixels(){return '(()=>{const data=ctx.getImageData(0,0,canvas.width,canvas.height).data;let count=0;for(let i=0;i<data.length;i+=4)if(data[i]>150&&data[i+1]<60&&data[i+2]>100)count++;return count})()';}
if(await evaluate(pixels())<500)throw Error('The contour is not visibly magenta');
await evaluate('document.getElementById("fit-m-circle").click()');await wait('!renderQueued');
await assert('zoom["nichols:0"] && document.getElementById("fit-m-circle").hidden===false','Fit M-circle did not zoom');
if(await evaluate(pixels())<1000)throw Error('Fitted contour is not visible');
// Configure a genuine lag compensator through the K(s) editor.
await evaluate(`document.getElementById('auto-update').checked=false;
for(const [key,value]of Object.entries({controller:'lag','project-name':'Lag · P = 2, Tz = 3 s, β = 5','G-num':'1','G-den':'1 1',P:'2','lag-zero':'3','lag-beta':'5'}))document.getElementById(key).value=value;
document.getElementById('controller').dispatchEvent(new Event('input'));document.getElementById('update').click();`);
await wait('!state.busy&&state.project.K.den[0]===15');
await assert('!document.getElementById("lag-parameters").hidden && document.getElementById("Ti-label").hidden && document.getElementById("Td-label").hidden','Wrong lag editor fields');
await assert('JSON.stringify(state.project.K.num)==="[6,2]" && JSON.stringify(state.project.K.den)==="[15,1]"','Wrong lag coefficients');
await assert('state.results[0].data.frequency.L.phase.some(p=>p<0)','No phase lag');
await assert('draft()["lag-zero"]==="3"&&draft()["lag-beta"]==="5"','Lag parameters missing from saved draft');
await evaluate('document.getElementById("fit-m-circle").click()');await wait('!renderQueued');
// Use the lab plant to show both the loop trajectory and contour in the preview.
await evaluate('document.getElementById("G-num").value="0.1";document.getElementById("G-den").value="1 2 1 0";document.getElementById("P").value="20";document.getElementById("project-name").value="Lag · P = 20, Tz = 3 s, β = 5";markChanged();update()');
await wait('!state.busy&&state.project.K.num[0]===60');
await evaluate('document.getElementById("fit-m-circle").click()');await wait('!renderQueued');
await fs.writeFile(output+'studio_lag_nichols.png',Buffer.from((await call('Page.captureScreenshot',{format:'png',captureBeyondViewport:true})).data,'base64'));
// Export must include the same single reference, not just the response curve.
const downloads=await fs.mkdtemp('/tmp/asta-lag-nichols-');await call('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloads});
await evaluate('document.getElementById("export-svg").click()');
for(let n=0;n<50;n++){try{await fs.stat(downloads+'/asta-nichols.svg');break;}catch{}await new Promise(resolve=>setTimeout(resolve,80));}
const svg=await fs.readFile(downloads+'/asta-nichols.svg','utf8');
if((svg.match(/data-m-circle-db="2.3"/g)||[]).length!==1||!svg.includes('stroke="#b21493"')||!svg.includes('M = 2.3 dB'))throw Error('SVG lost the single highlighted contour');
// Invalid settings leave the previous valid response intact.
await evaluate('document.getElementById("lag-beta").value="1";document.getElementById("update").click()');await wait('!state.busy');
await assert('document.getElementById("error").textContent.includes("beta") && state.project.K.den[0]===15','Invalid lag ratio not rejected');
await evaluate('document.getElementById("lag-beta").value="5";document.getElementById("lag-zero").value="0";document.getElementById("update").click()');await wait('!state.busy');
await assert('document.getElementById("error").textContent.includes("Tz")','Invalid lag zero time not rejected');
await evaluate('document.getElementById("lag-zero").value="3";document.getElementById("update").click()');await wait('!state.busy');
// Session round-trip and remembered designs retain their lag structure/settings.
await assert('(()=>{const saved=session();loadSession(JSON.parse(JSON.stringify(saved)));return document.getElementById("controller").value==="lag"&&document.getElementById("lag-zero").value==="3"&&document.getElementById("lag-beta").value==="5"})()','Lag session did not restore');
await evaluate('document.getElementById("update").click()');await wait('!state.busy');
await evaluate('document.getElementById("remember").click()');await wait('!state.busy&&state.snapshots.length===1');
await evaluate('document.getElementById("lag-beta").value="8";markChanged();update()');await wait('!state.busy&&state.project.K.den[0]===24');
await evaluate('document.querySelector(".comparison-row button").click()');await wait('!state.busy&&state.project.K.den[0]===15');
await assert('document.getElementById("lag-beta").value==="5"','Remembered lag settings did not restore');
await call('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await new Promise(resolve=>setTimeout(resolve,120));
await assert('document.documentElement.scrollWidth<=innerWidth','Nichols toolbar or lag editor overflows on mobile');
if(errors.length)throw Error(JSON.stringify(errors));
console.log('PASS: one visible magenta 2.3 dB contour, geometry, fit zoom, SVG, lag coefficients/editor, invalid inputs, saved designs and mobile layout.');ws.close();
