"""Independent integer calibration and per-pixel classification reference."""
def parameters(ok,count,means,lows,highs):
    color=max(range(3),key=lambda i:means[i])
    others=[means[i] for i in range(3) if i!=color]
    main=means[color]
    if not ok or count!=256:reason=1
    elif any(not lo<=m<=hi for lo,m,hi in zip(lows,means,highs)):reason=2
    elif not 80<=main<=224:reason=3
    elif any(hi-lo>32 for lo,hi in zip(lows,highs)):reason=4
    elif any(main-v<40 for v in others):reason=5
    else:reason=0
    if reason:return [0,reason,0,0,0,0]
    return [1,0,color,max(0,min(255,main-32))]+[max(0,min(255,main-v-32)) for v in others]

def classify(rgb,color,main,d1,d2):
    if color==3:return 0
    others=[v for i,v in enumerate(rgb) if i!=color]
    return int(rgb[color]>=main and rgb[color]-others[0]>=d1 and rgb[color]-others[1]>=d2)


def frame_rgb(pattern,x,y,w,h):
    rx,ry=(w-16)//2,(h-16)//2
    inside=rx<=x<rx+16 and ry<=y<ry+16
    if pattern in (1,3,4,5,6,7,10) and inside:
        if pattern==1:return (144 if y<ry+8 else 160,40,40)
        if pattern==3:return (128,128,128)
        if pattern==4:return (16,16,16)
        if pattern==5:return (255,255,255)
        if pattern==6:return (200,40,40) if y<ry+8 else (40,40,200)
        if pattern==7:return (40,152,40)
        if pattern==10:return (40,40,152)
    if pattern==2:
        return [(130,50,50),(130,51,50),(119,39,39),(120,40,40)][(x*4)//w]
    if pattern==9:
        return [(50,130,50),(51,130,50),(39,119,39),(40,120,40)][(x*4)//w]
    if pattern==8:return (0,100,0)
    if pattern==11:return (0,0,100)
    return (100,0,0)
