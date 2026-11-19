#!/usr/bin/env python3
"""Local ASTA Studio. Standard-library server; one persistent Octave worker."""
import argparse
import atexit
from collections import OrderedDict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import threading
import tempfile
import time
import webbrowser
import sys
import urllib.request

ROOT = Path(__file__).resolve().parent

class Engine:
    def __init__(self):
        self.lock = threading.Lock()
        self.cache = OrderedDict()
        self.process = None
        self.directory = tempfile.TemporaryDirectory(prefix="asta-studio-")
        self.request_path = Path(self.directory.name)/"request.json"
        self.response_path = Path(self.directory.name)/"response.json"
        self._start()

    def _start(self):
        self.request_path.unlink(missing_ok=True)
        self.response_path.unlink(missing_ok=True)
        expression = "asta_studio_worker('%s','%s')" % (self.request_path,self.response_path)
        self.process = subprocess.Popen(
            ['octave-cli', '--quiet', '--no-history', '--eval', expression],
            cwd=ROOT.parent, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)

    def close(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()

    def request(self, request):
        key = json.dumps(request, sort_keys=True, separators=(',', ':'), allow_nan=False)
        started = time.perf_counter()
        with self.lock:
            if key in self.cache:
                value = dict(self.cache.pop(key))
                self.cache[key] = value
                return {**value, 'cached': True, 'request_ms': (time.perf_counter()-started)*1000}
            if self.process.poll() is not None:
                self._start()
            try:
                temporary=self.request_path.with_suffix('.tmp')
                temporary.write_text(key)
                temporary.replace(self.request_path)
                deadline=time.monotonic()+30
                while not self.response_path.exists():
                    if self.process.poll() is not None:
                        raise RuntimeError('Octave stopped. Try updating the response again.')
                    if time.monotonic()>deadline:
                        raise TimeoutError()
                    time.sleep(.005)
                answer=json.loads(self.response_path.read_text())
                self.response_path.unlink()
            except TimeoutError as exc:
                self.close()
                raise RuntimeError('Calculation timed out. Reduce the model order or sample count and retry.') from exc
            if not isinstance(answer,dict):
                raise RuntimeError('Invalid response from Octave. Restart Studio and retry.')
            if answer.get('ok'):
                self.cache[key] = answer
                # Cache both entry count and serialized size (32 MiB total).
                while len(self.cache)>16 or sum(len(json.dumps(v)) for v in self.cache.values())>32*1024*1024:
                    self.cache.popitem(last=False)
            return {**answer, 'cached': False, 'request_ms': (time.perf_counter()-started)*1000}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def respond(self, status, body, mime='application/json'):
        if not isinstance(body, bytes):
            body=json.dumps(body, allow_nan=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', mime)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def allowed(self):
        host = self.headers.get('Host', '')
        origin = self.headers.get('Origin')
        return host in {f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'} and (not origin or origin in {f'http://{host}'})

    def do_GET(self):
        if not self.allowed():
            self.respond(403, {'error': 'Use the local Studio address.'}); return
        assets={'/':'index.html','/app.js':'app.js','/style.css':'style.css'}
        if self.path=='/api/health':
            self.respond(200, {'ok':True,'engine':'GNU Octave','persistent':True}); return
        if self.path not in assets:
            self.respond(404, {'error':'Not found'}); return
        path=ROOT/assets[self.path]
        mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8'}[path.suffix]
        self.respond(200,path.read_bytes(),mime)

    def do_POST(self):
        if not self.allowed():
            self.respond(403, {'error':'Use the local Studio address.'}); return
        if self.path!='/api/compute':
            self.respond(404, {'error':'Not found'}); return
        try:
            size=int(self.headers.get('Content-Length','0'))
            if not 0<size<=2*1024*1024:
                raise ValueError('Request must be smaller than 2 MiB.')
            request=json.loads(self.rfile.read(size))
            if not isinstance(request,dict) or request.get('action') not in {'analyze','controller','systems'}:
                raise ValueError('Unknown request.')
            self.respond(200,self.server.engine.request(request))
        except (ValueError,RuntimeError,TypeError,KeyError) as exc:
            self.respond(400,{'ok':False,'error':str(exc)})

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--port',type=int,default=8765)
    parser.add_argument('--no-browser',action='store_true')
    parser.add_argument('--detach',action='store_true',help='Start in the background, or reuse the running Studio.')
    args=parser.parse_args()
    if args.detach:
        url=f'http://127.0.0.1:{args.port}'
        opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
        def ready():
            try:
                with opener.open(url+'/api/health',timeout=.3) as response:
                    return json.load(response).get('engine')=='GNU Octave'
            except (OSError,ValueError):
                return False
        if not ready():
            log=tempfile.NamedTemporaryFile(prefix='asta-studio-',suffix='.log',delete=False)
            process=subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'--port',str(args.port),'--no-browser'],
                                     stdin=subprocess.DEVNULL,stdout=log,stderr=log,start_new_session=True)
            log.close()
            for _ in range(60):
                if ready(): break
                if process.poll() is not None:
                    raise SystemExit(f'Could not start Studio. See {log.name}')
                time.sleep(.1)
            else:
                raise SystemExit(f'Studio did not become ready. See {log.name}')
        print(f'ASTA Studio: {url}')
        if not args.no_browser: webbrowser.open(url)
        return
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    server.engine=Engine()
    atexit.register(server.engine.close)
    url=f'http://127.0.0.1:{server.server_port}'
    print(f'ASTA Studio: {url}',flush=True)
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.engine.close()
        server.server_close()

if __name__=='__main__':
    main()
