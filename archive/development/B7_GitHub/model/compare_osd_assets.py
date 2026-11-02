"""Compare actual RTL ROM reads to frozen vendor-asset tables and render them."""
import argparse
import csv
import json
from pathlib import Path
from PIL import Image, ImageDraw


def compare(directory, reference, inject_error=False):
    expected = json.loads(reference.read_text())
    logo_ref = {int(k):v for k,v in expected['logo'].items()}
    font_ref = {int(k):v for k,v in expected['font'].items()}
    if inject_error:
        logo_ref[5494] ^= 1
    with (directory/'logo.csv').open() as f:
        logo_rows = list(csv.DictReader(f))
    with (directory/'font.csv').open() as f:
        font_rows = list(csv.DictReader(f))
    if [int(r['addr']) for r in logo_rows] != list(range(32768)):
        raise ValueError('Logo address count/order mismatch')
    if [(int(r['char']),int(r['row'])) for r in font_rows] != [(c,y) for c in range(256) for y in range(16)]:
        raise ValueError('Font address count/order mismatch')
    actual_logo = [int(r['pixel'],16) for r in logo_rows]
    actual_font = [int(r['bits'],16) for r in font_rows]
    errors = sum(v != logo_ref.get(i,0) for i,v in enumerate(actual_logo))
    errors += sum(v != font_ref.get(i//16,[0]*16)[i%16] for i,v in enumerate(actual_font))
    if errors:
        raise ValueError(f'OSD asset mismatch: {errors} entries')
    # RGB/alpha and glyph pixels below all come from RTL CSV, not the reference.
    logo = Image.new('RGBA',(160,160))
    logo.putdata([((v>>16)&255,(v>>8)&255,v&255,255 if v&(1<<24) else 0) for v in actual_logo[:25600]])
    logo.save(directory/'logo_rtl.png')
    atlas = Image.new('RGB',(16*16,16*16),'#17202b')
    for c in range(256):
        for y in range(16):
            bits = actual_font[c*16+y]
            for x in range(16):
                if bits & (1<<(15-x)):
                    atlas.putpixel(((c%16)*16+x,(c//16)*16+y),(255,255,255))
    atlas.resize((768,768),Image.Resampling.NEAREST).save(directory/'font_atlas_rtl.png')
    preview = Image.new('RGB',(720,430),'#edf0f4')
    draw = ImageDraw.Draw(preview)
    draw.text((20,12),'Official asset RTL readback - host-composited preview',fill='#142033')
    for left,color,label in [(20,'white','White background'),(200,'#17202b','Dark background'),(380,'#9199a7','Gray background')]:
        draw.rectangle((left,44,left+159,203),fill=color)
        preview.paste(logo,(left,44),logo)
        draw.text((left,212),label,fill='#142033')
    def text_rtl(text, y):
        for k,c in enumerate(text):
            code=ord(c)
            for gy in range(16):
                bits=actual_font[code*16+gy]
                for gx in range(16):
                    if bits&(1<<(15-gx)):
                        draw.rectangle((20+k*32+gx*2,y+gy*2,21+k*32+gx*2,y+gy*2+1),fill='#17202b')
    text_rtl('FPGA VIDEO',245)
    text_rtl('RAW GRAY EDGE MASK',285)
    text_rtl('0123456789:',325)
    text_rtl(chr(0x80)+chr(0x81)+' ANLOGIC',365)
    preview.save(directory/'osd_assets_preview.png')
    result={'logo_addresses':32768,'font_rows':4096,'mismatches':0,
            'opaque_logo_pixels':sum(bool(v&(1<<24)) for v in actual_logo),
            'supported_glyphs':len(font_ref),'video_compositor_verified':False,
            'reference_origin':'Frozen tables parsed from original vendor assets; not an independent logo design.'}
    (directory/'image_check.json').write_text(json.dumps(result,indent=2)+'\n')
    return result


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--directory',type=Path,required=True)
    p.add_argument('--reference',type=Path,required=True)
    p.add_argument('--inject-error',action='store_true')
    a=p.parse_args()
    try:
        compare(a.directory,a.reference,a.inject_error)
        print('PASS: OSD asset tables match RTL readback.')
    except (OSError,ValueError,KeyError) as e:
        print(f'FAIL: {e}'); raise SystemExit(1)
