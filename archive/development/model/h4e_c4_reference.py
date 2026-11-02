"""Bounded-memory RGB/majority/flood-fill reference and annotation metrics."""
from array import array
import hashlib,json,math
from pathlib import Path

ENTRY='fixed_wb_rgb888_before_gamma_gray_osd'
GEOM=('area','cx','cy','xmin','xmax','ymin','ymax')
def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(65536),b''):h.update(block)
    return h.hexdigest()
def integer(v,lo,hi,name):
    if type(v)!=int or not lo<=v<=hi:raise ValueError(name+' out of range/type')
    return v
def file_under(root,name,size,sha):
    if not isinstance(name,str) or Path(name).is_absolute():raise ValueError('relative file required')
    p=(root/name).resolve()
    if not p.is_relative_to(root) or not p.is_file():raise ValueError('file escapes dataset or missing')
    if p.stat().st_size!=size:raise ValueError('wrong byte count: '+name)
    if not isinstance(sha,str) or len(sha)!=64 or digest(p)!=sha.lower():raise ValueError('SHA256 mismatch: '+name)
    return p

def validate(path):
    path=Path(path).resolve();root=path.parent
    m=json.loads(path.read_text(encoding='utf-8'))
    if m.get('schema')!='h4e-rgb-replay-v1':raise ValueError('unknown schema')
    if m.get('entry')!=ENTRY or m.get('identity_profile')!='capture-v1':raise ValueError('wrong pixel entry or identity profile')
    if m.get('source_kind') not in ('synthetic','camera'):raise ValueError('source_kind required')
    w=integer(m['width'],18,1280,'width');h=integer(m['height'],18,720,'height')
    if m['source_kind']=='camera' and (w,h)!=(1280,720):raise ValueError('camera export must be complete 720p')
    if m['source_kind']=='camera':
        bit=m.get('bit_sha256')
        if not isinstance(bit,str) or len(bit)!=64 or any(c not in '0123456789abcdef' for c in bit):raise ValueError('camera bit_sha256 required')
    if not isinstance(m.get('exposure'),str) or not m['exposure'].strip() or not isinstance(m.get('lighting'),str) or not m['lighting'].strip():raise ValueError('exposure/lighting required, explicit unknown allowed')
    if not isinstance(m.get('frames'),list) or not m['frames']:raise ValueError('frames required')
    previous=None
    for frame in m['frames']:
        for key,lo,hi in [('frame_id',0,2**32-1),('epoch',0,2**32-1),('cfg_id',0,65535),('target_id',0,2),('hblank_cycles',0,65535)]:integer(frame[key],lo,hi,key)
        t=frame['thresholds']
        if not isinstance(t,list) or len(t)!=3:raise ValueError('three thresholds required')
        for v in t:integer(v,0,255,'threshold')
        file_under(root,frame['rgb_file'],w*h*3,frame['rgb_sha256'])
        ann=frame.get('annotation')
        if ann is not None:
            if type(ann.get('target_present'))!=bool:raise ValueError('target_present must be bool')
            if ann.get('origin')!=('synthetic_geometry' if m['source_kind']=='synthetic' else 'human'):raise ValueError('annotation provenance required')
            box=ann.get('primary_bbox')
            if ann['target_present']:
                if not isinstance(box,list) or len(box)!=4:raise ValueError('primary bbox required')
                for v,hi in zip(box,(w-1,h-1,w-1,h-1)):integer(v,0,hi,'bbox')
                if box[0]>box[2] or box[1]>box[3]:raise ValueError('inverted bbox')
            elif box is not None:raise ValueError('absent target must have null bbox')
            if ann.get('mask_file') is not None:
                mask=file_under(root,ann['mask_file'],w*h,ann['mask_sha256']).read_bytes()
                if any(v not in (0,1) for v in mask):raise ValueError('mask must contain only 0/1 bytes')
                if bool(any(mask))!=ann['target_present']:raise ValueError('mask/presence disagreement')
                if box and not any(mask[y*w+x] for y in range(box[1],box[3]+1) for x in range(box[0],box[2]+1)):raise ValueError('primary bbox does not intersect mask')
        if previous:
            same=(frame['epoch'],frame['frame_id'])==(previous['epoch'],previous['frame_id'])
            config=(frame['target_id'],t);old=(previous['target_id'],previous['thresholds'])
            if same and (config!=old or frame['cfg_id']!=previous['cfg_id'] or frame['rgb_sha256']!=previous['rgb_sha256']):raise ValueError('same source identity changed pixels/config')
            if frame['cfg_id']==previous['cfg_id'] and config!=old:raise ValueError('changed parameters need a new cfg_id')
        reason=frame.get('expected_structural_reason')
        if reason is not None and (m['source_kind']!='synthetic' or type(reason)!=int or reason not in (3,5)):raise ValueError('structural expectation is synthetic-only E3/E5')
        previous=frame
    return m

def masks(rgb,w,h,color,thresholds):
    classified=bytearray(w*h);main,d1,d2=thresholds;others=[i for i in range(3) if i!=color]
    for i in range(w*h):
        p=i*3;c=rgb[p+color]
        classified[i]=int(c>=main and c-rgb[p+others[0]]>=d1 and c-rgb[p+others[1]]>=d2)
    masked=bytearray(classified)
    masked[:w*4]=bytes(w*4);masked[(h-4)*w:]=bytes(w*4)
    filtered=bytearray(w*h)
    for y in range(1,h-1):
        for x in range(1,w-1):
            j=y*w+x
            filtered[j]=int(sum(masked[j+dy*w+dx] for dy in (-1,0,1) for dx in (-1,0,1))>=5)
    return classified,filtered

def geometry(mask,w,h):
    # One byte visited map and packed integer stack, not a Python set of tuples.
    todo=bytearray(mask);best=None;components=0
    for start in range(w*h):
        if not todo[start]:continue
        todo[start]=0;stack=array('I',[start]);area=0;xmin=xmax=start%w;ymin=ymax=start//w
        while stack:
            i=stack.pop();x=i%w;y=i//w;area+=1
            xmin=min(xmin,x);xmax=max(xmax,x);ymin=min(ymin,y);ymax=max(ymax,y)
            for yy in range(max(0,y-1),min(h,y+2)):
                for xx in range(max(0,x-1),min(w,x+2)):
                    j=yy*w+xx
                    if todo[j]:todo[j]=0;stack.append(j)
        components+=1;r=dict(area=area,xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,cx=(xmin+xmax)//2,cy=(ymin+ymax)//2)
        if best is None or (-area,ymin,xmin)<(-best['area'],best['ymin'],best['xmin']):best=r
    if best is None:return dict(target_valid=0,reject_reason=1,**dict.fromkeys(GEOM,0))
    if best['area']<256:return dict(target_valid=0,reject_reason=2,**dict.fromkeys(GEOM,0))
    return dict(target_valid=1,reject_reason=0,**best)

def confusion(actual,label):
    return dict(tp=sum(a and b for a,b in zip(actual,label)),fp=sum(a and not b for a,b in zip(actual,label)),
                fn=sum(not a and b for a,b in zip(actual,label)),tn=sum(not a and not b for a,b in zip(actual,label)))
def overlap(a,b):
    inter=max(0,min(a[2],b[2])-max(a[0],b[0])+1)*max(0,min(a[3],b[3])-max(a[1],b[1])+1)
    area=lambda v:(v[2]-v[0]+1)*(v[3]-v[1]+1)
    return inter/(area(a)+area(b)-inter)
def metrics(records):
    result=dict(total_replay_events=len(records),duplicates_excluded=0,unique_events=0,structural_failures=0,unannotated=0,
                evaluated_frames=0,tp=0,fp=0,fn=0,tn=0,positive_frames=0,negative_frames=0,localization=[],pixel_frames=0,
                classified_pixels=dict(tp=0,fp=0,fn=0,tn=0),filtered_pixels=dict(tp=0,fp=0,fn=0,tn=0))
    for r in records:
        if not r['rtl']['new_observation']:result['duplicates_excluded']+=1;continue
        result['unique_events']+=1
        if r['rtl']['reject_reason'] in (3,5):result['structural_failures']+=1;continue
        ann=r['annotation']
        if ann is None:result['unannotated']+=1;continue
        result['evaluated_frames']+=1;truth=ann['target_present'];pred=bool(r['rtl']['target_valid'])
        result['positive_frames' if truth else 'negative_frames']+=1
        result['tp' if pred and truth else 'fp' if pred else 'fn' if truth else 'tn']+=1
        if pred and truth:
            a=[r['rtl'][k] for k in ('xmin','ymin','xmax','ymax')];b=ann['primary_bbox']
            result['localization'].append(dict(index=r['index'],bbox_iou=overlap(a,b),center_error_px=math.hypot(r['rtl']['cx']-(b[0]+b[2])//2,r['rtl']['cy']-(b[1]+b[3])//2)))
        if 'pixel_metrics' in r:
            result['pixel_frames']+=1
            for name in ('classified_pixels','filtered_pixels'):
                for k,v in r['pixel_metrics'][name].items():result[name][k]+=v
    result['false_positive_rate']=result['fp']/result['negative_frames'] if result['negative_frames'] else None
    result['false_negative_rate']=result['fn']/result['positive_frames'] if result['positive_frames'] else None
    result['pixel_denominator']=sum(result['classified_pixels'].values())
    for name in ('classified_pixels','filtered_pixels'):
        c=result[name];c['precision']=c['tp']/(c['tp']+c['fp']) if c['tp']+c['fp'] else None;c['recall']=c['tp']/(c['tp']+c['fn']) if c['tp']+c['fn'] else None
    result['note']='Synthetic geometry or human labels are separate from RTL equivalence. E3/E5 excluded from detection rates and counted explicitly; repeat observations excluded. TP presence does not imply correct localization.'
    return result

def evaluate_frame(record):
    r=record['rtl'];ann=record['annotation']
    if not r['new_observation']:return dict(category='duplicate_excluded')
    if r['reject_reason'] in (3,5):return dict(category='capacity_failure' if r['reject_reason']==3 else 'deadline_failure')
    if ann is None:return dict(category='unannotated')
    pred=bool(r['target_valid']);truth=ann['target_present']
    result=dict(category='true_positive' if pred and truth else 'false_positive' if pred else 'false_negative' if truth else 'true_negative')
    if pred and truth:
        box=ann['primary_bbox'];result['bbox_iou']=overlap([r[k] for k in ('xmin','ymin','xmax','ymax')],box)
        result['center_error_px']=math.hypot(r['cx']-(box[0]+box[2])//2,r['cy']-(box[1]+box[3])//2)
    return result
