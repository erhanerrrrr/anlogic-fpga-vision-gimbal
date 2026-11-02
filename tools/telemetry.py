"""UART telemetry logger and offline decoder. No commands are sent to the board.

Examples:
  python telemetry.py --port COM5 --seconds 60 --output experiment.csv
  python telemetry.py --hex ../sim/uart_packets.hex --output simulated.csv
  python telemetry.py --binary recording.bin --output decoded.csv
Live mode needs pyserial; offline decoding uses Python standard library only.
"""
import argparse,binascii,csv,json,math,time
from pathlib import Path

MODES=['ORIGINAL','GRAYSCALE','BINARY','EDGE','COLOR MASK','POSTERIZE','MOTION','SENSOR AE']
MOTION=['WAIT BACKGROUND','LEARNING','CLEAR','MOVING','PRESENT STILL','SCENE CHANGED','NO VIDEO','SETTLING']

def decode(packet):
    assert len(packet)==40 and packet[:4]==b'\xa5\x5a\x01\x28'
    assert binascii.crc_hqx(packet[2:38],0xffff)==int.from_bytes(packet[38:40],'little')
    u16=lambda i:int.from_bytes(packet[i:i+2],'little')
    u32=lambda i:int.from_bytes(packet[i:i+4],'little')
    flags=packet[24]
    fresh=bool(flags&32)
    # The panel's live flags are sampled just before it accepts this event.
    # For a fresh result use its atomic source_ok/valid bits; otherwise use live status.
    valid=bool(flags&8) and bool(flags&16) and (fresh or bool(flags&2))
    return dict(sequence=u16(4),board_ms=u32(6),source_id=u32(10),cfg=u16(14),
       x=u16(16),y=u16(18),pan_us=u16(20),tilt_us=u16(22),fresh=fresh,
       enabled=bool(flags&4),source_live=bool(flags&2),panel_target_live=bool(flags&1),source_ok=bool(flags&16),raw_target_valid=bool(flags&8),target_valid=valid,
       state=packet[25],mode=MODES[packet[26]&7],color=packet[27],reason=packet[28],
       motion=MOTION[packet[29]&7],foreground_cells=u16(30),internal_age_ticks=u32(32),
       internal_age_ms=u32(32)*15e-6,dropped=u16(36),
       error_x=u16(16)-640 if valid and fresh else '',error_y=u16(18)-360 if valid and fresh else '')

class Stream:
    def __init__(self):self.buffer=bytearray();self.bad_crc=0;self.discarded=0
    def feed(self,data):
        self.buffer.extend(data)
        while len(self.buffer)>=40:
            if self.buffer[:4]!=b'\xa5\x5a\x01\x28':
                del self.buffer[0];self.discarded+=1;continue
            try:row=decode(self.buffer[:40])
            except AssertionError:
                del self.buffer[0];self.bad_crc+=1;continue
            del self.buffer[:40]
            yield row

def statistics(rows):
    # Only distinct, fresh, valid tracking observations. Always report coverage.
    active=[r for r in rows if r['fresh'] and r['enabled'] and r['state'] in (1,2,3,4) and r['mode']!='MOTION']
    valid=[r for r in active if r['target_valid']]
    def metric(key):
        a=sorted(abs(r[key]) for r in valid)
        return dict(mean_absolute=sum(a)/len(a),p95=a[math.ceil(.95*len(a))-1],maximum=a[-1]) if a else None
    return dict(packets=len(rows),fresh_tracking_observations=len(active),valid_observations=len(valid),
       valid_fraction=len(valid)/len(active) if active else None,error_x_pixels=metric('error_x'),error_y_pixels=metric('error_y'),
       notes=['Errors use the FPGA detected center, not independent ground truth.',
              'Internal age is NOT optical display delay or mechanical response.',
              'For missing/stale observations inspect source_live, source_id and dropped; do not infer zero error.',
              'Do not combine different distances, lighting, targets or test protocols into one performance claim.'])

def main():
    p=argparse.ArgumentParser(description=__doc__);g=p.add_mutually_exclusive_group(required=True)
    g.add_argument('--port');g.add_argument('--hex',type=Path);g.add_argument('--binary',type=Path)
    p.add_argument('--seconds',type=float,default=60);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if a.output.exists() or a.output.with_suffix('.json').exists():p.error('Output exists; choose a new experiment name')
    stream=Stream();rows=[]
    if a.port:
        try:import serial
        except ImportError:p.error('Live logging requires pyserial: python -m pip install pyserial')
        deadline=time.monotonic()+a.seconds
        raw_path=a.output.with_suffix('.bin')
        if raw_path.exists():p.error('Raw output exists')
        with serial.Serial(a.port,115200,timeout=.2,rtscts=False,dsrdtr=False) as port,raw_path.open('xb') as raw:
            while time.monotonic()<deadline:
                data=port.read(4096);raw.write(data);rows.extend(stream.feed(data))
    else:
        data=bytes.fromhex(a.hex.read_text()) if a.hex else a.binary.read_bytes()
        rows=list(stream.feed(data))
    if not rows:raise SystemExit(f'No valid F2N packets; bad_crc={stream.bad_crc}, discarded_bytes={stream.discarded}')
    with a.output.open('x',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    report=statistics(rows);report.update(bad_crc=stream.bad_crc,discarded_bytes=stream.discarded)
    a.output.with_suffix('.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
