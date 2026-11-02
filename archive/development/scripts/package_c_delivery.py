"""Build and verify a local portable C-stage delivery archive. Does not upload anything."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def digest(data):return hashlib.sha256(data).hexdigest()

def main():
    out=ROOT/'reports/c10/generated'
    for name in ('summary.json','regression_summary.json','td/summary.json'):
        if json.loads((out/name).read_text())['result']!='PASS':raise ValueError('missing passed check: '+name)
    regress=json.loads((out/'regression_summary.json').read_text())['stages']
    if not set('C%d'%i for i in range(1,10)).issubset({r['stage'] for r in regress if r['exit_code']==0}):raise ValueError('prior-stage regression incomplete')
    clean=(out/'clean_directory.log').read_text(encoding='utf-8')
    if 'exit=0 expected=0' not in clean or 'exit=1 expected=1' not in clean:raise ValueError('clean reproduction evidence missing')
    for rel,expected in json.loads((out/'source_manifest.json').read_text()).items():
        if digest((ROOT/rel).read_bytes())!=expected:raise ValueError('RTL changed after verification: '+rel)
    selected=[ROOT/'README.md',ROOT/'.gitignore']
    for folder in ('rtl','model','sim','scripts','synth','tests','docs'):
        selected.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc')
    selected.extend(p for p in (ROOT/'reports').glob('*/acceptance.md'))
    for p in out.rglob('*'):
        if p.is_file() and 'delivery' not in p.relative_to(out).parts and p.suffix in ('.json','.csv','.png','.log','.area'):
            selected.append(p)
    trace=out/'recovery/calibration_trace.vcd'
    if trace.is_file():selected.append(trace)
    selected=sorted(set(selected));manifest={str(p.relative_to(ROOT)).replace('\\','/'):digest(p.read_bytes()) for p in selected}
    directory=out/'delivery';directory.mkdir(exist_ok=True);archive=directory/'fpga_c_S0-C10_20261006.zip'
    metadata=dict(format_version=1,scope='C-only software/RTL/synthesis verification',B_integration='pending',hardware='not_tested',sha256=manifest)
    with zipfile.ZipFile(str(archive),'w',zipfile.ZIP_DEFLATED) as z:
        for p in selected:z.write(str(p),'fpga_c_delivery/'+str(p.relative_to(ROOT)).replace('\\','/'))
        z.writestr('fpga_c_delivery/DELIVERY_MANIFEST.json',json.dumps(metadata,indent=2,ensure_ascii=False)+'\n')
    with zipfile.ZipFile(str(archive)) as z:
        for rel,sha in manifest.items():
            if digest(z.read('fpga_c_delivery/'+rel))!=sha:raise ValueError('archive checksum mismatch: '+rel)
    (directory/'package_verification.json').write_text(json.dumps(dict(result='PASS',files=len(manifest),bytes=archive.stat().st_size,archive_sha256=digest(archive.read_bytes()),archive=archive.name),indent=2)+'\n')
    print('PASS: {} files packaged and SHA256 verified: {}'.format(len(manifest),archive))

if __name__=='__main__':main()
