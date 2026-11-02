"""Verify the frozen board package without depending on old local directories."""
from pathlib import Path
import hashlib, json, re

ROOT = Path(__file__).resolve().parent
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def verify():
    manifest = json.loads((ROOT/'source_manifest.json').read_text(encoding='utf-8'))
    summary = json.loads((ROOT/'evidence/build_summary.json').read_text(encoding='utf-8'))
    for name, expected in manifest['source_files_sha256'].items():
        assert sha(ROOT/name) == expected, f'Source mismatch: {name}'
    assert sha(ROOT/'td_project/camera_to_dsi_display.al') == manifest['project_sha256']
    assert sha(ROOT/'td_project/camera_to_dsi_display.sdc') == manifest['sdc_sha256']
    assert sha(ROOT/'H4E_row_regions.bit') == summary['sha256']
    assert (ROOT/'H4E_row_regions.bit').stat().st_size == summary['bytes']
    repo = ROOT.parents[2]
    baseline = json.loads((repo/'BASELINE.json').read_text(encoding='utf-8'))
    assert (repo/baseline['directory']).resolve() == ROOT
    assert baseline['bit_sha256'] == summary['sha256']
    assert (repo/baseline['bit']).resolve() == ROOT/'H4E_row_regions.bit'
    assert (repo/baseline['interface_document']).is_file()
    assert baseline['implemented_profile'] == 'h4e-refresh-v1'
    assert baseline['next_profile_board_implemented'] is False
    # TD .al uses unescaped "P&R" attributes, so it is not strict XML.
    project = (ROOT/'td_project/camera_to_dsi_display.al').read_text(encoding='utf-8')
    refs = re.findall(r'<File\s+Path="([^"]+)"', project)
    for name in refs:
        assert (ROOT/'td_project'/name).is_file(), f'Missing project dependency: {name}'
    # These test assets are unchanged from the accepted run. Python drivers have
    # deliberately been made portable and have a separate export manifest.
    for name in ('tb_regions.v', 'tb_h4e.v', 'assets/logo_reference.hex'):
        assert sha(ROOT/name) == manifest['test_files_sha256'][name], name
    exported = json.loads((ROOT/'export_manifest.json').read_text(encoding='utf-8'))
    for name, expected in exported['sha256'].items():
        assert sha(ROOT/name) == expected, f'Export mismatch: {name}'
    report = dict(status='PASS', source_files=len(manifest['source_files_sha256']),
                  project_references=len(refs), bit_sha256=summary['sha256'])
    print(json.dumps(report))
    return report

if __name__ == '__main__':
    verify()
