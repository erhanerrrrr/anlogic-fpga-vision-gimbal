"""Full-frame ModelSim mask verification. Standard library, Python 3.7+."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from c1_reference import classify


def reference_rgb(c,x,y,seed):
    p=c['pattern']
    if p in (0,1):
        return ((200,40,40) if p==0 else (40,200,40)) if x in range(100,141) and y in range(80,111) else (0,0,0)
    if p==2:
        return [(200,40,40),(40,200,40),(40,40,200),(0,0,0),(255,255,255),(128,128,128)][x*6//c['width']]
    if p==3:
        return (200,40,40) if x<9 and y<7 else (0,0,0)
    if p==4:
        word=((y*c['width']+x+seed)*1664525+1013904223) % (2**32)
        return (word//(2**24),word//(2**16)%256,word//256%256)
    if p==5:
        return (40,200,40)
    raise ValueError('unknown pattern')


def png(path,width,height,data):
    def chunk(kind,payload):
        return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',zlib.crc32(kind+payload)&0xffffffff)
    raw=b''.join(b'\0'+bytes(data[y*width:(y+1)*width]) for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,0,0,0,0))+
                     chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))


def run(command,work,log):
    result=subprocess.run(command,cwd=str(work),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=300)
    text=result.stdout.decode('utf-8',errors='replace')
    log.write_text(text,encoding='utf-8')
    if result.returncode:
        raise RuntimeError('tool failed: '+str(log))
    return text


def verify(out,cases,seed,inject=False):
    results=[]; total=0
    with (out/'actual.hex').open() as f:
        for c in cases:
            w,h=c['width'],c['height']
            count=c.get('abort_at',w*h)
            pixels=bytearray(); diff=bytearray(); ones=0; flags=[0,0,0]
            for index in range(count):
                line=f.readline()
                if not line: raise ValueError('missing output pixel')
                value=int(line,16)
                fid=value & 0xffffffff
                y=(value>>32)&2047; x=(value>>43)&2047
                eof=(value>>54)&1; eol=(value>>55)&1; sof=(value>>56)&1; mask=(value>>57)&1
                ey,ex=divmod(index,w)
                control=(fid,x,y,sof,eol,eof)
                expected=(c['frame_id'],ex,ey,int(index==0),int(ex==w-1),int(index==w*h-1))
                if control!=expected: raise ValueError('metadata mismatch {} pixel {}'.format(c['name'],index))
                want=classify(reference_rgb(c,ex,ey,seed),c['color'])
                if inject and total==0: want^=1
                pixels.append(mask*255); diff.append(255 if mask!=want else 0)
                if mask!=want: raise ValueError('mask mismatch {} pixel {}'.format(c['name'],index))
                ones+=mask; total+=1
                flags=[flags[0]+sof,flags[1]+eol,flags[2]+eof]
            if 'ones' in c and ones!=c['ones']: raise ValueError('literal anchor count mismatch')
            if 'abort_at' not in c:
                png(out/(c['name']+'_rtl.png'),w,h,pixels)
                png(out/(c['name']+'_diff.png'),w,h,diff)
            results.append({'case':c['name'],'frame_id':c['frame_id'],'pixels':count,'ones':ones,
                            'sof_eol_eof_counts':flags,'aborted':'abort_at' in c})
        if f.read().strip(): raise ValueError('unexpected extra output')
    return total,results


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check-only',action='store_true')
    parser.add_argument('--inject-error',action='store_true'); args=parser.parse_args()
    fixture=json.loads((ROOT/'tests/fixtures/c2/cases.json').read_text(encoding='utf-8'))
    out=ROOT/'reports/c2/generated'; out.mkdir(parents=True,exist_ok=True)
    if args.check_only:
        total,results=verify(out,fixture['cases'],fixture['seed'],args.inject_error)
        print('PASS: existing RTL output verified, {} pixels'.format(total)); return
    summary={'stage':'C2','result':'FAIL','interface_version':'c2-draft-1','seed':fixture['seed']}
    (out/'summary.json').write_text(json.dumps(summary),encoding='utf-8')
    executables={t:shutil.which(t) for t in ('vlib','vlog','vsim')}
    if not all(executables.values()): raise RuntimeError('ModelSim not on PATH')
    with tempfile.TemporaryDirectory(prefix='fpga_c2_') as temp:
        work=Path(temp)
        for rel in ('rtl/recognition/color_classifier.v','rtl/recognition/color_mask_stream.v','sim/c2/tb_color_mask_stream.v'):
            shutil.copy2(str(ROOT/rel),str(work/Path(rel).name))
        with (work/'cases.txt').open('w',encoding='ascii') as f:
            for c in fixture['cases']:
                f.write('{} {} {:08x} {} {} {}\n'.format(c['width'],c['height'],c['frame_id'],c['color'],c['pattern'],c.get('abort_at',-1)))
        shutil.copy2(str(work/'cases.txt'),str(out/'cases.txt'))
        (work/'run.do').write_text('onerror {quit -f -code 1}\nonbreak {quit -f -code 1}\nrun -all\nquit -f -code 0\n',encoding='ascii')
        version=run([executables['vsim'],'-version'],work,out/'tool_version.log').strip()
        run([executables['vlib'],'work'],work,out/'vlib.log')
        run([executables['vlog'],'-sv','color_classifier.v','color_mask_stream.v','tb_color_mask_stream.v'],work,out/'compile.log')
        print('C2: running full-frame ModelSim simulation...',flush=True)
        log=run([executables['vsim'],'-c','work.tb_color_mask_stream','-do','run.do'],work,out/'simulation.log')
        if 'C2_SIM_COMPLETE' not in log: raise RuntimeError('simulation incomplete')
        shutil.copy2(str(work/'actual.hex'),str(out/'actual.hex'))
    total,results=verify(out,fixture['cases'],fixture['seed'],args.inject_error)
    try: verify(out,fixture['cases'],fixture['seed'],True)
    except ValueError as exc: (out/'checker_selftest.log').write_text('EXPECTED FAILURE: '+str(exc),encoding='utf-8')
    else: raise RuntimeError('checker accepted wrong expected mask')
    summary.update(result='PASS',modelsim=version,valid_pixels=total,cases=results,pixel_mismatches=0,
                   metadata_mismatches=0,latency_registers=1,td='see separate TD report',hardware='not_tested',
                   team_interface_acceptance='pending_A_B')
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print('PASS: {} cases, {} RTL pixels; all masks and metadata match'.format(len(results),total))


if __name__=='__main__':
    try: main()
    except Exception as exc:
        print('FAIL: '+str(exc),file=sys.stderr); sys.exit(1)
