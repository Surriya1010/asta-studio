#!/usr/bin/env python3
"""Build an installable Octave tarball from the canonical runtime sources."""
import argparse
import gzip
import hashlib
import io
from pathlib import Path
import re
import tarfile

ROOT = Path(__file__).resolve().parents[1]

def build(output):
    description=(ROOT/'packaging/DESCRIPTION').read_text()
    version=re.search(r'^Version: (.+)$',description,re.M).group(1)
    name=re.search(r'^Name: (.+)$',description,re.M).group(1)
    prefix=f'{name}-{version}'
    files={}
    for source in sorted((ROOT/'packaging').iterdir()):
        if source.is_file(): files[source.name]=source.read_bytes()
    runtime=ROOT/'asta_octave'
    for source in sorted(runtime.rglob('*')):
        if not source.is_file(): continue
        relative=source.relative_to(runtime)
        if any(part in {'__pycache__','.git','tests'} for part in relative.parts): continue
        if source.name=='octave-workspace' or source.suffix in {'.pyc','.pyo','.log'}: continue
        files[str(Path('inst')/relative)]=source.read_bytes()
    # Keep internal self-tests private, rather than adding a generic run_tests
    # command to the user's Octave namespace when the package loads.
    tests=(runtime/'tests/run_tests.m').read_text().replace('function run_tests()', 'function astastudio_run_tests()',1)
    files['inst/private/astastudio_run_tests.m']=tests.encode()
    files['doc/README.md']=(ROOT/'README.md').read_bytes()
    files['inst/COPYING']=(ROOT/'packaging/COPYING').read_bytes()
    output.mkdir(parents=True,exist_ok=True)
    archive=output/f'{prefix}.tar.gz'
    with archive.open('wb') as raw, gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=0) as compressed:
        with tarfile.open(fileobj=compressed,mode='w') as tar:
            for path,data in sorted(files.items()):
                info=tarfile.TarInfo(f'{prefix}/{path}')
                info.size=len(data); info.mode=0o644; info.mtime=0
                tar.addfile(info,io.BytesIO(data))
    digest=hashlib.sha256(archive.read_bytes()).hexdigest()
    checksum=output/'SHA256SUMS'
    checksum.write_text(f'{digest}  {archive.name}\n')
    print(archive)
    print(checksum)
    return archive

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ROOT/'dist')
    build(parser.parse_args().output)
