"""Standalone TD synthesis of the shared three-field centi-FPS converter."""
import argparse
import hashlib
import json
import re
import shutil
from datetime import datetime
from pathlib import Path

from check_video_display_synthesis import area_count
from td_runner import run_td


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--td',type=Path,required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[1]
    source=root/'rtl/osd_fps_decimal.v'
    run=root/'build/b4e_fps_synthesis'/datetime.now().strftime('run_%Y%m%d_%H%M%S_%f')
    run.mkdir(parents=True)
    shutil.copy2(source,run/source.name)
    result={'stage':'B4e','scope':'standalone shared centi-FPS BCD converter',
            'passed':False,'board_tested':False,'board_timing_verified':False,
            'provisional_clock_mhz':75,
            'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    print('Reports:',run,flush=True)
    try:
        (run/'timing.sdc').write_text(
            'create_clock -name pixel_clk -period 13.333 [get_ports {clk}]\n'
            'set_input_delay -clock [get_clocks {pixel_clk}] 0.000 '
            '[get_ports {flush start source_fps_centi* display_fps_centi* result_fps_centi*}]\n'
            'set_output_delay -clock [get_clocks {pixel_clk}] 0.000 '
            '[get_ports {done source_bcd* display_bcd* result_bcd*}]\n'
            'set_false_path -from [get_ports {rst_n}]\n')
        (run/'synth.tcl').write_text(
            'create_project b4e_fps_check . -family ph1 -device PH1P35MDG324 -speed -3\n'
            'top_module osd_fps_decimal\n'
            'add_files {osd_fps_decimal.v timing.sdc}\n'
            'set_param -run syn_1 flow syn_ip_flow off\n'
            'set_param -run syn_1 gate pack_seq_in_io off\n'
            'launch_runs syn_1\nwait_run -quiet syn_1\nopen_run syn_1\n'
            'report_area -file area.rpt\n'
            'report_timing_summary -file timing.rpt -ep_num 3 -path_num 1\n'
            'close_project\nputs "B4E_SYNTH_FINISHED"\nexit\n')
        output=run_td(args.td,'source synth.tcl',run,run/'console.log',900)
        syn=run/'b4e_fps_check_Runs/syn_1'
        if ('B4E_SYNTH_FINISHED' not in output or
                not (syn/'.opt_gate.end.f').exists() or list(syn.glob('*.error.f'))):
            raise RuntimeError('TD synthesis did not finish cleanly')
        log=(syn/'run.log').read_text(errors='replace')
        if re.search(r'\bERROR:',log):
            raise RuntimeError('TD reported an error in run.log')
        result['warnings']=[line for line in log.splitlines() if 'WARNING:' in line]
        area=(run/'area.rpt').read_text(errors='replace')
        result['resources']={name:area_count(area,name)
                             for name in ('reg','lut','slice','eram20k','dsp')}
        result['resources']['latch']=area_count(
            (syn/'b4e_fps_check_rtl.area').read_text(errors='replace'),'LATCH')
        timing=(run/'timing.rpt').read_text(errors='replace')
        result['timing_ns']={name:float(re.search(
            r'\b'+name+r':\s*([-\d.]+)ns',timing)[1])
            for name in ('SWNS','STNS','HWNS','HTNS')}
        if any(value<0 for value in result['timing_ns'].values()):
            raise RuntimeError('Provisional 75 MHz timing failed')
        if any(result['resources'][name] for name in ('eram20k','dsp','latch')):
            raise RuntimeError('Unexpected RAM/DSP/latch resource')
        result['passed']=True
        print('PASS: B4e standalone FPS decimal synthesis. '
              +json.dumps(result['resources']),flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    main()
