"""Offline analysis of documented RGB888 captures. This is NOT an RTL replay or hardware measurement."""
import argparse,csv,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'model'))
from c9_reference import classify,parameters
from c5_reference import majority,geometry
from c6_reference import packet
from run_c2 import png


def analyze(manifest_path,out):
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    for key in ('provenance','capture_stage','lighting','distance_cm','source_revision','pixel_format','frames'):
        if key not in manifest:raise ValueError('missing metadata: '+key)
    if manifest['provenance'] not in ('synthetic','board_input','ordinary_photo'):raise ValueError('unknown provenance')
    if manifest['pixel_format']!='RGB888_R_G_B':raise ValueError('only interleaved R,G,B byte order is supported')
    out.mkdir(parents=True,exist_ok=True);last=None;rows=[];roi_reports=[]
    for i,frame in enumerate(manifest['frames']):
        w,h=frame['width'],frame['height'];cfg=frame['cfg_id'];fid=frame['source_frame_id'];color=frame['color'];limits=frame['limits']
        if not(16<=w<=1280 and 16<=h<=720 and 0<=fid<2**32 and 0<=cfg<65536 and color in (0,1,2) and len(limits)==3 and all(0<=v<=255 for v in limits)):
            raise ValueError('invalid frame dimensions or configuration')
        raw=(manifest_path.parent/frame['path']).read_bytes()
        if len(raw)!=w*h*3:raise ValueError('RGB file byte count must be width*height*3')
        mask=bytearray(classify(raw[j:j+3],color,*limits) for j in range(0,len(raw),3))
        filtered=majority(w,h,mask);g=geometry(w,filtered)
        candidate=packet(fid,cfg,color,g[1],g[2:6],w*h)
        publish=int(last is None or fid!=last)
        if publish:last=fid
        rows.append([i,publish]+candidate)
        png(out/('mask_%03d.png'%i),w,h,bytes(255 if b else 0 for b in filtered))
        rx,ry=(w-16)//2,(h-16)//2
        points=[raw[(y*w+x)*3:(y*w+x)*3+3] for y in range(ry,ry+16) for x in range(rx,rx+16)]
        sums=[sum(p[c] for p in points) for c in range(3)];means=[v//256 for v in sums]
        lows=[min(p[c] for p in points) for c in range(3)];highs=[max(p[c] for p in points) for c in range(3)]
        roi_reports.append(dict(index=i,frame_id=fid,count=256,sums=sums,means=means,minima=lows,maxima=highs,
                                proposed_calibration=parameters(True,256,means,lows,highs)))
    with (out/'candidate_results.csv').open('w',newline='') as f:
        writer=csv.writer(f);writer.writerow('index new_source frame_id cfg_id target_id valid area xmin ymin xmax ymax cx cy reason debug_count debug_xmin debug_ymin debug_xmax debug_ymax'.split());writer.writerows(rows)
    (out/'roi_statistics.json').write_text(json.dumps(roi_reports,indent=2)+'\n')
    (out/'analysis.json').write_text(json.dumps(dict(analysis='software_only_no_RTL_or_hardware_validation',
        provenance=manifest['provenance'],input_metadata=manifest,frames=len(rows),
        new_source_frames=sum(r[1] for r in rows),hardware_accuracy=None,hardware_fps=None),indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    return rows


def main():
    ap=argparse.ArgumentParser();ap.add_argument('manifest',type=Path);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
    rows=analyze(args.manifest.resolve(),args.output.resolve())
    print('PASS: offline software analysis of {} frames; no hardware acceptance claim'.format(len(rows)))

if __name__=='__main__':
    try:main()
    except Exception as exc:print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
