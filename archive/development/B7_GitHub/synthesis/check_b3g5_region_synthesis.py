"""Standalone synthesis of B3g5 display plus public-mask H4E selector."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
from datetime import datetime
from td_runner import run_td
from check_video_display_synthesis import area_count

def main():
    p=argparse.ArgumentParser();p.add_argument('--td',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/b3g5_region_synthesis'/datetime.now().strftime('run_%Y%m%d_%H%M%S');(run/'src').mkdir(parents=True)
    print(f'Reports: {run}',flush=True)
    files=(root/'b3g2_sources.f').read_text().splitlines()+[
        '../boards/hx1p35a/h4e/user_source/hdl_source/h4e_region_select.v',
        'synthesis/b3g5_region_probe.v']
    for f in files:shutil.copy2(root/f,run/'src'/Path(f).name)
    result=dict(passed=False,scope='B3g5 display plus unchanged H4E selector via public detect port',
        wrapper_included=True,board_tested=False,board_timing_verified=False,provisional_clock_mhz=75,
        debounce_cycles=750000,source_sha256={f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files})
    try:
        (run/'timing.sdc').write_text('create_clock -name pixel_clk -period 13.333 [get_ports {clk}]\n'
            'set_input_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {in_*}]\n'
            'set_output_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {out_*}]\n'
            'set_false_path -from [get_ports {rst_n}]\n')
        (run/'synth.tcl').write_text('create_project b3g5_region_check . -family ph1 -device PH1P35MDG324 -speed -3\n'
            'top_module b3g5_region_probe\nadd_files {'+' '.join('src/'+Path(f).name for f in files)+' timing.sdc}\n'
            'set_param -run syn_1 flow syn_ip_flow off\nset_param -run syn_1 gate pack_seq_in_io off\n'
            'launch_runs syn_1\nwait_run -quiet syn_1\nopen_run syn_1\n'
            'report_area -file area.rpt\nreport_timing_summary -file timing.rpt -ep_num 3 -path_num 1\n'
            'write_verilog mapped.v\nclose_project\nputs "B3G5_SYNTH_FINISHED"\nexit\n')
        output=run_td(a.td,'source synth.tcl',run,run/'console.log',1200)
        syn=run/'b3g5_region_check_Runs/syn_1'
        assert 'B3G5_SYNTH_FINISHED' in output and (syn/'.opt_gate.end.f').exists() and not list(syn.glob('*.error.f'))
        log=(syn/'run.log').read_text(errors='replace');assert not re.search(r'\bERROR:',log)
        result['warnings']=[s for s in log.splitlines() if 'WARNING:' in s]
        area=(run/'area.rpt').read_text(errors='replace')
        result['resources']={n:area_count(area,n) for n in ['reg','lut','slice','eram20k','dsp']}
        result['resources']['latch']=area_count((syn/'b3g5_region_check_rtl.area').read_text(errors='replace'),'LATCH')
        timing=(run/'timing.rpt').read_text(errors='replace')
        result['timing_ns']={k:float(re.search(r'\b'+k+r':\s*([-\d.]+)ns',timing)[1]) for k in ['SWNS','STNS','HWNS','HTNS']}
        if any(v<0 for v in result['timing_ns'].values()):
            raise RuntimeError('75 MHz standalone timing failed: '+
                json.dumps(result['timing_ns'])+'; inspect '+str(run/'timing.rpt'))
        assert result['resources']['eram20k']>=7 and result['resources']['dsp']==0 and result['resources']['latch']==0
        b3g2=json.loads((root/'reports/b3g2_20261017/synthesis/summary.json').read_text())
        result['approx_delta_from_b3g2_different_wrapper']={
            k:result['resources'][k]-v for k,v in b3g2['resources'].items()}
        result['passed']=True
        print('PASS: B3g5 public-mask region standalone synthesis. '+json.dumps(result['resources']),flush=True)
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
