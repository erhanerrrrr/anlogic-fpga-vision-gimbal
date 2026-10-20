"""B2c standalone synthesis and inferred RGB/filter RAM accounting."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
from datetime import datetime
from td_runner import run_td
from check_video_display_synthesis import area_count

def main():
    p=argparse.ArgumentParser();p.add_argument('--td',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    run=root/'build/edge_stream_synthesis'/datetime.now().strftime('run_%Y%m%d_%H%M%S')
    (run/'src').mkdir(parents=True);print(f'Reports: {run}',flush=True)
    result=dict(passed=False,board_tested=False,board_timing_verified=False,wrapper_included=True,
        clock_mhz_provisional=75,fifo_depth=2048,fifo_word_bits=24,fifo_logical_bits=49152,
        frame_descriptors_bits=164,source_sha256={})
    try:
        files=(root/'b2c_sources.f').read_text().splitlines()+['synthesis/edge_stream_probe.v']
        for name in files:
            shutil.copy2(root/name,run/'src'/Path(name).name)
            result['source_sha256'][name]=hashlib.sha256((root/name).read_bytes()).hexdigest()
        (run/'timing.sdc').write_text('create_clock -name pixel_clk -period 13.333 [get_ports {clk}]\n'
            'set_input_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {in_*}]\n'
            'set_output_delay -clock [get_clocks {pixel_clk}] 0.000 [get_ports {out_*}]\n'
            'set_false_path -from [get_ports {rst_n}]\n')
        (run/'synth.tcl').write_text('create_project edge_stream_check . -family ph1 -device PH1P35MDG324 -speed -3\n'
            'top_module edge_stream_probe\nadd_files {'+' '.join('src/'+Path(n).name for n in files)+'}\n'
            'add_files timing.sdc\nset_param -run syn_1 flow syn_ip_flow off\nset_param -run syn_1 gate pack_seq_in_io off\n'
            'launch_runs syn_1\nwait_run -quiet syn_1\nopen_run syn_1\n'
            'report_area -file area.rpt\nreport_timing_summary -file timing.rpt -ep_num 3 -path_num 1\n'
            'write_verilog mapped.v\nclose_project\nputs "B2C_SYNTH_FINISHED"\nexit\n')
        out=run_td(a.td,'source synth.tcl',run,run/'console.log',900)
        syn=run/'edge_stream_check_Runs/syn_1'
        if 'B2C_SYNTH_FINISHED' not in out or not (syn/'.opt_gate.end.f').exists() or list(syn.glob('*.error.f')):
            raise RuntimeError('Synthesis not confirmed')
        run_log=(syn/'run.log').read_text(errors='replace')
        result['warnings']=[line for line in run_log.splitlines() if re.search(r'\b(?:CRITICAL-)?WARNING:',line)]
        if re.search(r'\bERROR:',run_log):raise RuntimeError('Synthesis log contains errors')
        area=(run/'area.rpt').read_text(errors='replace')
        result['resources']={n:area_count(area,n) for n in ('reg','eram20k','dsp','slice','lut')}
        result['resources']['latch']=area_count((syn/'edge_stream_check_rtl.area').read_text(errors='replace'),'LATCH')
        net=(run/'mapped.v').read_text(errors='replace');rams=[]
        for parameters,instance in re.findall(r'\bPH1P_PHY_ERAM_V2\s*#\s*\((.*?)\)\s+(\S+)\s*\(',net,re.S):
            settings=dict(re.findall(r'\.(\w+)\("([^"]+)"\)',parameters))
            rams.append(dict(instance=instance.lstrip('\\'),**{k:settings.get(k) for k in ['MODE','DATA_WIDTH_A','DATA_WIDTH_B']}))
        result['ram_mapping']=rams
        # TD renames inferred RGB memory to core/ramread0_syn_*.
        result['rgb_fifo_eram']=sum('/base/pair/' in r['instance'] and '/filter/' not in r['instance'] for r in rams)
        result['edge_window_eram']=sum('/edges/window_core/' in r['instance'] for r in rams)
        result['filter_eram']=sum('/filter/' in r['instance'] for r in rams)
        timing=(run/'timing.rpt').read_text(errors='replace')
        result['timing_ns']={k:float(re.search(r'\b'+k+r':\s*([-\d.]+)ns',timing)[1]) for k in ('SWNS','STNS','HWNS','HTNS')}
        baseline=json.loads((root/'reports/b2b_20261012/synthesis_summary.json').read_text())
        result['resource_delta_from_b2b']={k:v-baseline['resources'][k] for k,v in result['resources'].items()}
        result['timing_passed']=all(v>=0 for v in result['timing_ns'].values())
        result['ram_layout_passed']=(result['rgb_fifo_eram']==3 and result['filter_eram']==2 and result['edge_window_eram']==2 and len(rams)==7 and result['resources']['eram20k']==7)
        result['passed']=result['resources']['latch']==0 and result['timing_passed'] and result['ram_layout_passed'] and result['resources']['dsp']==0
        if not result['passed']:raise RuntimeError('Resource/timing check failed; inspect summary')
        print('PASS: B2c standalone synthesis. '+json.dumps(result['resources']),flush=True)
    finally:(run/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
if __name__=='__main__':main()
