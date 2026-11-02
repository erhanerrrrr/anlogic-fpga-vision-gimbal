"""Independent integer/rational validity rule. Geometry remains available on rejection."""
from fractions import Fraction


def decide(count,box,max_area=921600,min_area=9,min_width=3,min_height=3):
    l,t,r,b=box
    if count==0:return 1
    if r<l or b<t:return 6
    width,height=r-l+1,b-t+1
    if count>width*height:return 6
    if count<min_area:return 2
    if width<min_width or height<min_height:return 3
    if count>max_area:return 4
    if Fraction(count,width*height)<Fraction(3,4):return 5
    return 0


def packet(fid,cfg,color,count,box,max_area=921600):
    reason=decide(count,box,max_area)
    l,t,r,b=box
    public=[1,count,l,t,r,b,(l+r)//2,(t+b)//2] if reason==0 else [0]*8
    return [fid,cfg,color]+public+[reason,count,l,t,r,b]
