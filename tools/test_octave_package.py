#!/usr/bin/env python3
"""Install/test/uninstall in an isolated registry; exercise the installed server."""
import argparse
import json
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import urllib.request

ROOT=Path(__file__).resolve().parents[1]

def literal(path):
    return "'"+str(path).replace("'","''")+"'"

def octave(code):
    subprocess.run(['octave-cli','--quiet','--no-history','--eval',code],check=True,cwd='/tmp')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('archive',type=Path)
    args=parser.parse_args()
    archive=args.archive.resolve()
    with tempfile.TemporaryDirectory(prefix='astastudio-install-') as temporary:
        directory=Path(temporary)
        registry=directory/'packages'; prefix=directory/'installed'; info=directory/'info.json'
        setup=f"pkg('local_list',{literal(registry)}); pkg('prefix',{literal(prefix)}); "
        octave(f"old=pkg('local_list'); if exist(old,'file'), copyfile(old,{literal(registry)}); end; "+setup+
               f"pkg('install','-local',{literal(archive)}); pkg('load','astastudio'); "+
               "assert(strcmp(astastudio('version'),'1.0.0')); "+
               f"assert(strncmp(which('astastudio'),{literal(prefix)},length({literal(prefix)}))); "+
               "assert(astastudio('test')); assert(test('astastudio','quiet')); "+
               "pkg('unload','astastudio'); assert(isempty(which('astastudio'))); pkg('load','astastudio'); "+
               f"fid=fopen({literal(info)},'w'); fprintf(fid,'%s',jsonencode(astastudio('info'))); fclose(fid);")
        installed=json.loads(info.read_text())
        process=subprocess.Popen([sys.executable,installed['server'],'--port','0','--no-browser'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            line=process.stdout.readline().strip()
            assert line.startswith('ASTA Studio: '),line
            url=line.removeprefix('ASTA Studio: ')
            opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
            def request(data):
                req=urllib.request.Request(url+'/api/compute',data=json.dumps(data).encode(),headers={'Content-Type':'application/json'})
                with opener.open(req,timeout=30) as response: result=json.load(response)
                assert result['ok'],result
                return result['data']
            assert len(request({'action':'systems'}))==19
            p={'name':'Installed package P','G':{'num':[.1],'den':[1,2,1,0]},'K':{'num':[4.8],'den':[1]},'R':{'num':[1],'den':[1]}}
            grid={'time_end':40,'time_samples':4001,'w_min':.001,'w_max':1000,'w_samples':4001}
            data=request({'action':'analyze','project':p,'grid':grid})
            assert abs(data['statistics']['time']['overshoot_percent']-23.584)<.1
            assert data['statistics']['closed_loop_stable']
            port=int(url.rsplit(':',1)[1])
            octave(setup+f"pkg('load','astastudio'); astastudio('open','port',{port},'browser',false);")
            print('PASS: installed browser server, 19 models, lab response and Octave launcher.')
        finally:
            process.send_signal(signal.SIGINT)
            try: process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait()
        octave(setup+"pkg('uninstall','astastudio'); assert(isempty(which('astastudio')));")
        print('PASS: isolated install, dependency loading, self-tests, unload/reload and uninstall.')

if __name__=='__main__':
    main()
