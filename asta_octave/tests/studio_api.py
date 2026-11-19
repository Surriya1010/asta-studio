import json,time,urllib.request
url='http://127.0.0.1:8765/api/compute'
def request(v):
 started=time.perf_counter()
 with urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(v).encode(),headers={'Content-Type':'application/json'})) as r:
  result=json.load(r)
 assert result['ok'],result
 return result,(time.perf_counter()-started)*1000
p={'name':'Benchmark P '+str(time.time_ns()),'G':{'num':[.1],'den':[1,2,1,0]},'K':{'num':[4.8],'den':[1]},'R':{'num':[1],'den':[1]}}
g={'time_end':40,'time_samples':4001,'w_min':.001,'w_max':1000,'w_samples':4001}
req={'action':'analyze','project':p,'grid':g}
first,cold=request(req)
assert not first['cached']
warm=[]
for i in range(5):
 result,elapsed=request(req);warm.append(elapsed);assert result['cached']
assert first['data']==result['data']
print(json.dumps({'samples_per_domain':4001,'first_request_ms':round(cold,2),'cached_request_ms':[round(t,2) for t in warm],'engine_ms':first['elapsed_ms'],'identical_results':True},indent=2))
# Invalid ranges must be rejected; origin requests outside localhost must fail.
bad={**req,'grid':{**g,'w_min':0}}
with urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(bad).encode(),headers={'Content-Type':'application/json'})) as r: assert not json.load(r)['ok']
try:
 urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(req).encode(),headers={'Content-Type':'application/json','Origin':'https://unrelated.example'}))
 raise AssertionError('Foreign origin accepted')
except urllib.error.HTTPError as e: assert e.code==403
print('PASS: cache identity, invalid ranges and local-origin checks.')

# JSON transport preserves infinite margins separately from undefined values.
simple={**p,'name':'Infinite margin check','G':{'num':[1],'den':[1,1]},'K':{'num':[1],'den':[1]}}
result,_=request({'action':'analyze','project':simple,'grid':g})
assert result['data']['statistics']['gain_margin']=='Infinity'
print('PASS: infinite margins survive the JSON transport.')
