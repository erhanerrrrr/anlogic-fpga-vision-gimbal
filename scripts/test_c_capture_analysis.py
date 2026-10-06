"""Small independent anchors and malformed-file check for the offline capture tool."""
import json,tempfile
from pathlib import Path
from analyze_c_capture import analyze
ROOT=Path(__file__).resolve().parents[1]

def main():
    with tempfile.TemporaryDirectory(prefix='capture_analysis_') as d:
        work=Path(d);w,h=64,48
        frame=bytearray()
        for y in range(h):
            for x in range(w):frame.extend((200,40,40) if 10<=x<=50 and 8<=y<=38 else (0,0,0))
        (work/'card.rgb').write_bytes(frame);(work/'empty.rgb').write_bytes(bytes(w*h*3))
        manifest=dict(provenance='synthetic',capture_stage='synthetic RGB integers',lighting='not_applicable',distance_cm=None,
            source_revision='C10 numeric selftest',pixel_format='RGB888_R_G_B',frames=[dict(path=p,width=w,height=h,source_frame_id=i,cfg_id=0,color=0,limits=[80,40,40]) for i,p in enumerate(['card.rgb','empty.rgb'])])
        p=work/'manifest.json';p.write_text(json.dumps(manifest));rows=analyze(p,work/'result')
        assert rows[0][5:13]==[1,1267,10,8,50,38,30,23],rows[0]
        assert rows[1][5:13]==[0]*8,rows[1]
        (work/'empty.rgb').write_bytes(b'bad')
        try:analyze(p,work/'bad_result')
        except ValueError as exc:
            if 'byte count' not in str(exc):raise
        else:raise ValueError('truncated RGB file accepted')
    out=ROOT/'reports/c10/generated';out.mkdir(parents=True,exist_ok=True)
    (out/'capture_tool_selftest.log').write_text('PASS: synthetic rectangle1267/center30,23, empty frame, truncated-file rejection; no real capture used\n')
    print('PASS: offline capture analyzer numeric anchors and truncated input check')
if __name__=='__main__':main()
