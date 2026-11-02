"""Standalone TD synthesis of the B4b latency text panel with test wrapper."""
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
    files=['rtl/video_latency_text.v','assets/osd/target_text_font.v',
           'synthesis/b4b_latency_probe.v']
    run=root/'build/b4b_latency_synthesis'/datetime.now().strftime('run_%Y%m%d_%H%M%S_%f')
    run.mkdir(parents=True)
    for name in files:shutil.copy2(root/name,run/Path(name).name)
    result={'stage':'B4b','scope':'latency text plus font and banked observation wrapper',
            'wrapper_included':True,'passed':False,'board_tested':False,
            'board_timing_verified':False,'provisional_clock_mhz':75,
            'source_sha256':{name:hashlib.sha256((root/name).read_bytes()).hexdigest()
                             for name in files}}
    print('Reports:',run,flush=True)
    try:
        (run/'timing.sdc').write_text(
            'create_clock -name pixel_clk -period 13.333 [get_ports {clk}]\n'
            'set_input_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {in_*}]\n'
            'set_output_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {out_*}]\n'
            'set_false_path -from [get_ports {rst_n}]\n')
        (run/'synth.tcl').write_text(
            'create_project b4b_latency_check . -family ph1 -device PH1P35MDG324 -speed -3\n'
            'top_module b4b_latency_probe\n'
            'add_files {'+' '.join(Path(name).name for name in files)+' timing.sdc}\n'
            'set_param -run syn_1 flow syn_ip_flow off\n'
            'set_param -run syn_1 gate pack_seq_in_io off\n'
            'launch_runs syn_1\nwait_run -quiet syn_1\nopen_run syn_1\n'
            'report_area -file area.rpt\n'
            'report_timing_summary -file timing.rpt -ep_num 3 -path_num 1\n'
            'close_project\nputs "B4B_SYNTH_FINISHED"\nexit\n')
        output=run_td(args.td,'source synth.tcl',run,run/'console.log',900)
        syn=run/'b4b_latency_check_Runs/syn_1'
        if ('B4B_SYNTH_FINISHED' not in output or
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
            (syn/'b4b_latency_check_rtl.area').read_text(errors='replace'),'LATCH')
        timing=(run/'timing.rpt').read_text(errors='replace')
        result['timing_ns']={name:float(re.search(
            r'\b'+name+r':\s*([-\d.]+)ns',timing)[1])
            for name in ('SWNS','STNS','HWNS','HTNS')}
        if any(value<0 for value in result['timing_ns'].values()):
            raise RuntimeError('Provisional 75 MHz timing failed')
        if any(result['resources'][name] for name in ('eram20k','dsp','latch')):
            raise RuntimeError('Unexpected RAM/DSP/latch resource')
        result['passed']=True
        print('PASS: B4b standalone latency text synthesis. '
              +json.dumps(result['resources']),flush=True)
    finally:
        (run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')


if __name__=='__main__':
    main()
