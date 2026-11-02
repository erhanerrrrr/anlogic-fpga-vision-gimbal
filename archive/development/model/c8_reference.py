"""C8 ROI arithmetic reference: complete-array integer statistics, not streaming RTL."""
FIELDS=('frame_id','cfg_id','target_id','ok','reason','count','sum_r','sum_g','sum_b',
        'min_r','min_g','min_b','max_r','max_g','max_b','mean_r','mean_g','mean_b')

def rgb(pattern,x,y,rx,ry):
    inside=rx<=x<rx+16 and ry<=y<ry+16
    if not inside:return (0,0,255) if pattern==1 else (0,0,0)
    index=(y-ry)*16+x-rx
    if pattern in (0,1):return (144 if index<128 else 160,40,40)
    if pattern==2:return (255,255,255)
    if pattern==3:return ((index*17+3)%256,(index*29+7)%256,(index*43+11)%256)
    if pattern==4:return (40,152,40)
    if pattern==5:return (40,40,152)
    return (0,0,0)

def statistics(fid,cfg,color,points,ok=True,reason=0):
    count=len(points)
    sums=[sum(p[c] for p in points) for c in range(3)]
    lows=[min(p[c] for p in points) if points else 0 for c in range(3)]
    highs=[max(p[c] for p in points) if points else 0 for c in range(3)]
    means=[v//256 if ok else 0 for v in sums]
    return [fid,cfg,color,int(ok),reason,count]+sums+lows+highs+means
