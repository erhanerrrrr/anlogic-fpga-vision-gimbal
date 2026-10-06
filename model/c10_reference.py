"""C10 scene definition; expected geometry anchors are stored separately in fixtures."""
def rgb(pattern,x,y,w,h):
    left,top=(100,80) if w>=640 else (10,8)
    rx,ry=(w-16)//2,(h-16)//2
    if pattern==8:return (130,50,50)
    # Other colors coexist in the large image and must not become red targets.
    background=(0,0,0)
    if w>=640 and 500<=x<=540 and 80<=y<=110:background=(40,200,40)
    if w>=640 and 700<=x<=740 and 80<=y<=110:background=(40,40,200)
    if pattern==4:
        return (144 if y<ry+8 else 160,40,40) if rx<=x<rx+16 and ry<=y<ry+16 else background
    if pattern==7 and rx<=x<rx+16 and ry<=y<ry+16:return (128,128,128)
    if pattern==2:return background
    if pattern==3:
        inside=(((100<=x<=140) or (300<=x<=340)) and 80<=y<=110) if w>=640 else (((4<=x<=12) or (44<=x<=52)) and 8<=y<=16)
    else:
        left+=10 if pattern in (1,6) else (20 if pattern==7 else 0)
        inside=left<=x<=left+40 and top<=y<=top+30
    if inside:return (100,0,0) if pattern==5 else ((130,50,50) if pattern in (6,7) else (200,40,40))
    return background
