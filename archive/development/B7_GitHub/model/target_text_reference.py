"""Independent text formatting with Python strings and uniform glyph data."""
import json
import numpy as np
from target_osd_reference import unpack,render

def load_font(path):
    """Paint JSON cells into pixels, independently of the RTL bit packing."""
    result={}
    for char,bitmap in json.loads(path.read_text()).items():
        canvas=np.zeros((16,16),dtype=np.uint8)
        for y,row in enumerate(bitmap):
            for x,on in enumerate(row):
                if on=='1':canvas[1+y*2:3+y*2,3+x*2:5+x*2]=1
        result[str(ord(char))]=[int(''.join(str(int(v)) for v in row),2) for row in canvas]
    return result

def lines(value,ready,display):
    p=unpack(value)
    status='WAIT' if not ready else 'VALID' if p['valid'] else 'INVALID'
    color=['RED','GREEN','BLUE','NA'][p['color']] if ready else 'NA'
    x=f"{p['cx']:04d}" if p['valid'] else 'NA  '
    y=f"{p['cy']:04d}" if p['valid'] else 'NA  '
    a=f"{p['area']:07d}" if p['valid'] else 'NA     '
    why=['OK','EMPTY','SMALL','CAPACITY','WAIT','TIMEOUT','RESERVED','RESERVED'][p['reason']]
    count=f"{p['components']:04d}" if ready and p['reason'] not in (3,5) else 'NA  '
    return [f'TARGET:{status:<8}COLOR:{color:<5}',f'X:{x} Y:{y} AREA:{a}',
        f"RESULT HEX:{p['frame']:08X} CFG HEX:{p['cfg']:04X} DISPLAY HEX:{display:08X}",
        f"REASON:{p['reason']} {why:<8}SLOTS:{p['slots']:03d} COMPONENTS:{count}"]

def render_text(value,ready,display,logo,font):
    image=render(value,logo)
    p=unpack(value)
    ink=(255,128,0) if not ready else (0,255,0) if p['valid'] else (255,255,0)
    for row,(y,text) in enumerate(zip((16,40,64,88),lines(value,ready,display))):
        image[y:y+16,16:976]=(32,32,32)
        for column,char in enumerate(text):
            glyph=font.get(str(ord(char)),[0]*16)
            for gy,bits in enumerate(glyph):
                for gx in range(16):
                    if bits & (1<<(15-gx)):image[y+gy,16+column*16+gx]=ink if row==0 else (255,255,255)
    return image
