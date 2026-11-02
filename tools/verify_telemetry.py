"""Check the PC decoder against independently decoded RTL UART bytes."""
from pathlib import Path
import hashlib,json,binascii
from telemetry import Stream,statistics
ROOT=Path(__file__).resolve().parents[1]
data=bytes.fromhex((ROOT/'sim/uart_packets.hex').read_text())
s=Stream();rows=list(s.feed(data))
assert len(rows)==3 and [r['source_id'] for r in rows]==[123,125,125]
assert [r['fresh'] for r in rows]==[True,True,False]
assert [r['dropped'] for r in rows]==[0,1,1]
for r in rows:
    assert (r['x'],r['y'],r['pan_us'],r['tilt_us'])==(640,360,1512,1490)
    assert r['target_valid'] and r['source_live'] and r['enabled']
    assert r['mode']=='MOTION' and r['motion']=='MOVING' and r['foreground_cells']==77
assert statistics(rows)['valid_fraction'] is None # MOTION is not color tracking
split=Stream();received=[]
for b in data:received.extend(split.feed(bytes([b])))
assert received==rows
bad=bytearray(data[:40]);bad[16]^=1
s=Stream();recovered=list(s.feed(b'noise'+bad+data))
assert recovered==rows and s.bad_crc==1 and s.discarded>0
invalid=bytearray(data[:40]);invalid[24]&=~8
invalid[38:40]=binascii.crc_hqx(invalid[2:38],0xffff).to_bytes(2,'little')
r=list(Stream().feed(invalid))[0]
assert not r['target_valid'] and r['error_x']=='' and r['error_y']==''
first=bytearray(data[:40]);first[24]&=~3
first[38:40]=binascii.crc_hqx(first[2:38],0xffff).to_bytes(2,'little')
assert list(Stream().feed(first))[0]['target_valid'] # no one-frame panel-status lag
measurements=[dict(rows[0],mode='ORIGINAL',error_x=n,error_y=-n) for n in range(1,21)]
metrics=statistics(measurements)
assert metrics['error_x_pixels']==dict(mean_absolute=10.5,p95=19,maximum=20)
assert metrics['valid_fraction']==1 and metrics['error_y_pixels']==metrics['error_x_pixels']
record={'status':'PASS','scope':'RTL 3-packet UART stream, fields, bytewise fragments, CRC/noise resynchronization, invalid coordinates, MOTION statistics exclusion',
        'input_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'tools/telemetry.py',Path(__file__),ROOT/'sim/uart_packets.hex']}}
(ROOT/'sim/telemetry_validation.json').write_text(json.dumps(record,indent=2))
print('PASS PC telemetry decoder against RTL bytes and corrupted/fragmented streams')
