"""C4 synthetic acceptance, manifest rejection tests and metric accounting checks."""
import copy,hashlib,json,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'model'))
from generate_h4e_c4 import generate
from replay_h4e_rgb import replay
from h4e_c4_reference import validate,digest,metrics,evaluate_frame

def format_tests(dataset):
    cases=[]
    with tempfile.TemporaryDirectory(prefix='h4e_c4_format_') as directory:
        work=Path(directory)
        # Copy one small complete frame and label, never edit the generated inputs.
        base=json.loads(Path(dataset).read_text());base['frames']=[base['frames'][1]]
        for key in ('rgb_file',):
            p=Path(dataset).parent/base['frames'][0][key];(work/p.name).write_bytes(p.read_bytes())
        p=Path(dataset).parent/base['frames'][0]['annotation']['mask_file'];(work/p.name).write_bytes(p.read_bytes())
        manifest=work/'manifest.json'
        def check(name,change,message):
            value=copy.deepcopy(base);change(value);manifest.write_text(json.dumps(value))
            try:validate(manifest)
            except (ValueError,KeyError) as exc:
                assert message in str(exc),(name,str(exc));cases.append(dict(name=name,status='EXPECTED_REJECTION',reason=str(exc)))
            else:raise AssertionError('validator accepted '+name)
        check('schema',lambda m:m.update(schema='other'),'schema')
        check('wrong_entry',lambda m:m.update(entry='after_gamma'),'entry')
        check('display_identity',lambda m:m.update(identity_profile='h4e-refresh-v1'),'identity')
        check('kind',lambda m:m.update(source_kind='unknown'),'source_kind')
        check('boolean_width',lambda m:m.update(width=True),'width')
        check('camera_partial',lambda m:m.update(source_kind='camera'),'720p')
        check('cfg_range',lambda m:m['frames'][0].update(cfg_id=65536),'cfg_id')
        check('target_range',lambda m:m['frames'][0].update(target_id=3),'target_id')
        check('threshold_count',lambda m:m['frames'][0].update(thresholds=[24,16]),'thresholds')
        check('threshold_sign',lambda m:m['frames'][0].update(thresholds=[-1,16,16]),'threshold')
        check('hblank',lambda m:m['frames'][0].update(hblank_cycles=-1),'hblank')
        check('path_escape',lambda m:m['frames'][0].update(rgb_file='../outside.rgb'),'escapes')
        check('file_missing',lambda m:m['frames'][0].update(rgb_file='missing.rgb'),'missing')
        check('checksum',lambda m:m['frames'][0].update(rgb_sha256='0'*64),'SHA256')
        raw=work/base['frames'][0]['rgb_file'];bad=work/'truncated.rgb';bad.write_bytes(raw.read_bytes()[:-1])
        check('truncated',lambda m:m['frames'][0].update(rgb_file=bad.name,rgb_sha256=digest(bad)),'byte count')
        bad=work/'padding.rgb';bad.write_bytes(raw.read_bytes()+b'0')
        check('extra_bytes',lambda m:m['frames'][0].update(rgb_file=bad.name,rgb_sha256=digest(bad)),'byte count')
        check('bbox_outside',lambda m:m['frames'][0]['annotation'].update(primary_bbox=[0,0,64,1]),'bbox')
        check('bbox_inverted',lambda m:m['frames'][0]['annotation'].update(primary_bbox=[30,10,20,20]),'inverted')
        check('presence_type',lambda m:m['frames'][0]['annotation'].update(target_present=1),'bool')
        check('annotation_provenance',lambda m:m['frames'][0]['annotation'].update(origin='human'),'provenance')
        check('mask_presence',lambda m:m['frames'][0]['annotation'].update(target_present=False,primary_bbox=None),'mask/presence')
        bad=work/'invalid.mask';bad.write_bytes(bytes([2])+bytes(base['width']*base['height']-1))
        check('mask_values',lambda m:m['frames'][0]['annotation'].update(mask_file=bad.name,mask_sha256=digest(bad)),'0/1')
        check('no_exposure',lambda m:m.update(exposure=''),'exposure')
        check('invalid_structural_reason',lambda m:m['frames'][0].update(expected_structural_reason=4),'structural')
        def repeat_changed(m):
            m['frames'].append(copy.deepcopy(m['frames'][0]));m['frames'][1]['thresholds']=[80,40,40]
        check('repeat_config_changed',repeat_changed,'same source identity')
        def cfg_changed(m):
            repeat_changed(m);m['frames'][1]['frame_id']+=1
        check('same_cfg_changed_parameters',cfg_changed,'new cfg_id')
        # Full 720p file-size/hash check only; this is NOT a 720p RTL simulation.
        rgb=work/'720p.rgb';rgb.write_bytes(bytes(1280*720*3));full=copy.deepcopy(base)
        full.update(width=1280,height=720);full['frames'][0].update(rgb_file=rgb.name,rgb_sha256=digest(rgb),annotation=None)
        manifest.write_text(json.dumps(full));validate(manifest);cases.append(dict(name='720p_format_only',status='PASS',rgb_bytes=rgb.stat().st_size))
        full.update(source_kind='camera',bit_sha256=None);manifest.write_text(json.dumps(full))
        try:validate(manifest)
        except ValueError as exc:
            assert 'bit_sha256' in str(exc);cases.append(dict(name='camera_missing_bit',status='EXPECTED_REJECTION',reason=str(exc)))
        else:raise AssertionError('missing camera provenance accepted')
    return cases

def main():
    out=ROOT/'reports/h4e-c4/generated';out.mkdir(parents=True,exist_ok=True)
    (out/'summary.json').write_text('{"status":"FAIL"}')
    manifests=generate(out/'datasets');validation=format_tests(manifests[0]);summaries=[];records=[]
    for path in manifests:
        summary=replay(path,out/path.parent.name);assert summary['status']=='PASS';summaries.append(summary)
        records+=json.loads((out/path.parent.name/'records.json').read_text())
    # Integrity errors, structural failures and presence errors have distinct accounting.
    normal=json.loads((out/'scenes/records.json').read_text());m=metrics(normal)
    assert (m['tp'],m['fp'],m['fn'],m['tn'],m['duplicates_excluded'])==(10,0,4,2,1)
    assert {r['name'] for r in normal if r['evaluation']['category']=='false_negative'}=={'glare','dark','dark_after_change','occluded'}
    touch=next(r for r in normal if r['name']=='touching_cards');assert touch['evaluation']['bbox_iou']==0.5 and touch['evaluation']['center_error_px']==10
    fault=copy.deepcopy(normal[1]);fault['rtl'].update(target_valid=0,reject_reason=3)
    fm=metrics([fault]);assert fm['structural_failures']==1 and fm['fn']==0 and fm['evaluated_frames']==0
    wrong=copy.deepcopy(normal[0]);wrong['rtl'].update(target_valid=1,reject_reason=0)
    assert metrics([wrong])['fp']==1 and evaluate_frame(wrong)['category']=='false_positive'
    unknown=copy.deepcopy(normal[1]);unknown['annotation']=None
    assert metrics([unknown])['unannotated']==1
    (out/'metrics_selftest.json').write_text(json.dumps(dict(status='PASS',cases=['known_synthetic_misses','touching_localization','structural_not_FN','injected_false_positive','unannotated_excluded']),indent=2)+'\n')
    files=['model/h4e_c4_reference.py','scripts/generate_h4e_c4.py','scripts/replay_h4e_rgb.py','scripts/run_h4e_c4.py','sim/h4e_c4/tb_h4e_rgb_replay.v']
    summary=dict(status='PASS',source='synthetic_only',frames=sum(s['frames'] for s in summaries),
        classified_pixels_checked=sum(s['classified_pixels_checked'] for s in summaries),filtered_pixels_checked=sum(s['filtered_pixels_checked'] for s in summaries),
        exact_geometry_frames=sum(s['exact_geometry_frames'] for s in summaries),expected_structural_rejects=sum(s['structural_rejects'] for s in summaries),
        format_cases=len(validation),format_rejections=sum(v['status']=='EXPECTED_REJECTION' for v in validation),format_720p='byte count/hash only; not RTL replay',
        real_camera_frames=0,rtl_720p_replay='not_run_this_stage',resource_increment='0 new FPGA logic/memory; no RTL changes',
        source_hashes={s:digest(ROOT/s) for s in files},scenes_detection=dict(tp=m['tp'],fp=m['fp'],fn=m['fn'],tn=m['tn'],positive_frames=m['positive_frames'],negative_frames=m['negative_frames'],duplicates_excluded=m['duplicates_excluded']),
        metric_selftest='PASS',commands_exit_codes='all 0')
    (out/'format_tests.json').write_text(json.dumps(validation,indent=2)+'\n');(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
