"""Synthesize the 1280x720 button-controlled four-mode and OSD video chain, base RGB tap and diagnostics."""

import argparse
from collections import Counter
from datetime import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

# Reuse the already-verified TD launcher; the grayscale runner is unchanged.
from td_runner import run_td
from audit_unused_nets import audit


def area_count(area_text, name):
    # TD marks approximate post-synthesis counts with an asterisk (#slice*).
    match = re.search(r"^\s*#" + re.escape(name) + r"\*?\s+(\d+)\b", area_text, re.MULTILINE)
    if not match:
        raise RuntimeError(f"Missing resource count: {name}")
    return int(match.group(1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--td", type=Path, help="Full path to td_commands_prompt.exe")
    parser.add_argument("--clock-mhz", type=float, default=75.0,
                        help="Provisional standalone clock budget in MHz (default: 75).")
    parser.add_argument("--require-timing", action="store_true",
                        help="Fail if the post-synthesis timing estimate is not met.")
    args = parser.parse_args()
    if not math.isfinite(args.clock_mhz) or args.clock_mhz <= 0:
        parser.error("--clock-mhz must be a finite positive number")
    period_ns = round(1000.0 / args.clock_mhz, 3)
    if period_ns < 0.001:
        parser.error("--clock-mhz gives a period smaller than the 0.001 ns constraint resolution")
    script_dir = Path(__file__).resolve().parent
    root = script_dir.parent
    if args.td and not args.td.is_file():
        raise FileNotFoundError(args.td)
    candidates = [args.td, shutil.which("td_commands_prompt.exe"),
                  os.environ.get("TD_EXECUTABLE")]
    executable = next((Path(p).resolve() for p in candidates if p and Path(p).is_file()), None)
    if executable is None:
        raise FileNotFoundError("TD not found. Pass --td with the path to td_commands_prompt.exe.")

    run_dir = root / "build" / "video_display_synthesis" / datetime.now().strftime("run_%Y%m%d_%H%M%S_%f")
    (run_dir / "src").mkdir(parents=True)
    print(f"Reports: {run_dir}", flush=True)
    version_output = run_td(executable, "exit", run_dir, run_dir / "td_version.log", 30)
    version_match = re.search(r"Tang Dynasty, V([0-9.]+)", version_output)
    if not version_match or not re.fullmatch(r"6\.2\.1[0-9]*", version_match.group(1)):
        raise RuntimeError("Expected the TD 6.2.1 series used by the contest. See td_version.log")
    version = version_match.group(1)
    print(f"TD version: {version}", flush=True)

    hashes = {}
    for source in [root / "rtl" / name for name in ("rgb_to_gray.v", "video_gray.v", "window_3x3.v",
                   "sobel_core.v", "edge_raster.v", "video_edge.v", "video_rgb_edge_align.v", "frame_mode_ctrl.v", "rgb_bypass.v", "video_bypass.v", "video_modes.v", "button_events.v", "button_mode_request.v", "video_modes_buttons.v", "video_static_osd.v", "video_display.v")] + [root / "assets/osd/anlogic_logo_rom.v", root / "assets/osd/osd_char_lib.v", script_dir / "video_display_720p_probe_top.v"]:
        snapshot = run_dir / "src" / source.name
        shutil.copy2(source, snapshot)
        hashes[source.name] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
    for name in ("video_display_synthesis.tcl", "video_display_synthesis.sdc"):
        shutil.copy2(script_dir / name, run_dir / name)
    for name in ("check_video_display_synthesis.py", "td_runner.py", "audit_unused_nets.py"):
        shutil.copy2(script_dir / name, run_dir / "src" / name)
    sdc_path = run_dir / "video_display_synthesis.sdc"
    sdc_text = sdc_path.read_text(encoding="utf-8")
    if sdc_text.count("-period 13.333") != 1:
        raise RuntimeError("Expected exactly one default 13.333 ns clock in the SDC template")
    sdc_text = sdc_text.replace("-period 13.333", f"-period {period_ns:.3f}", 1)
    sdc_text = sdc_text.replace("provisional 75 MHz budget", f"provisional {args.clock_mhz:g} MHz budget", 1)
    sdc_path.write_text(sdc_text, encoding="utf-8")
    manifest = {
        "td_version": version, "td_executable": str(executable),
        "top_module": "video_display_720p_probe_top", "dimensions": [1280, 720],
        "device": "PH1P35MDG324", "speed_grade": "-3", "flow": "normal synthesis, syn_ip_flow off",
        "observation_wrapper": "32-bit selectable probe; not a board video interface",
        "requested_clock_mhz": args.clock_mhz, "clock_period_ns": period_ns,
        "clock_is_provisional": True, "timing_required_for_exit_zero": args.require_timing,
        "source_sha256": hashes, "synthesis_passed": False,
        "ram_resource_check_passed": False, "board_timing_verified": False,
        "checks_passed": False, "fifo_depth": 5136, "fifo_packet_bits": 81,
        "fifo_logical_bits": 416016, "tag_fifo_bits": 15408,
        "threshold": 128, "buttons_and_mask_are_dynamic_inputs": True,
        "debounce_cycles": 750000, "active_low": True,
        "async_button_ports_false_pathed": True, "osd_enabled": True,
    }
    manifest_path = run_dir / "synthesis_result.json"

    def save_manifest():
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    save_manifest()
    print(f"Button-controlled four-mode and OSD frame size: 1280 x 720; standalone budget: {args.clock_mhz:g} MHz", flush=True)
    print("Running button-controlled four-mode and OSD video synthesis...", flush=True)
    console_path = run_dir / "td_console.log"
    output = run_td(executable, "source video_display_synthesis.tcl", run_dir, console_path, 900)
    syn_dir = run_dir / "video_display_check_Runs" / "syn_1"
    required = [run_dir / "video_display_check.al", run_dir / "video_display_area.rpt", run_dir / "video_display_timing.rpt",
                syn_dir / "video_display_check_gate.db", run_dir / "video_display_mapped.v"]
    if "PASS: button-controlled four-mode and OSD video synthesis completed." not in output:
        raise RuntimeError(f"No confirmed synthesis completion. See {console_path}")
    if any(not p.is_file() or p.stat().st_size == 0 for p in required):
        raise RuntimeError(f"Incomplete synthesis artifacts. See {run_dir}")
    if not (syn_dir / ".opt_gate.end.f").is_file() or list(syn_dir.glob("*.error.f")):
        raise RuntimeError(f"Synthesis status did not confirm success. See {syn_dir}")

    area = (run_dir / "video_display_area.rpt").read_text(encoding="utf-8", errors="replace")
    resources = {name: area_count(area, name) for name in ("reg", "eram20k", "dsp", "pad", "slice", "lut", "dram lut")}
    # Normal synthesis's physical-area format omits the latch row. Read the
    # explicit RTL latch count, rather than treating a missing field as zero.
    rtl_area = (syn_dir / "video_display_check_rtl.area").read_text(encoding="utf-8", errors="replace")
    resources["rtl_latch"] = area_count(rtl_area, "LATCH")
    netlist = (run_dir / "video_display_mapped.v").read_text(encoding="utf-8", errors="replace")
    physical_rams = len(re.findall(r"\bPH1P_PHY_ERAM_V2\s*#\s*\(", netlist))
    ram_mapping = []
    for parameters, instance in re.findall(
            r"\bPH1P_PHY_ERAM_V2\s*#\s*\((.*?)\)\s+(\S+)\s*\(", netlist, re.DOTALL):
        settings = dict(re.findall(r'\.(\w+)\("([^"]+)"\)', parameters))
        ram_mapping.append({"instance": instance.lstrip("\\"), **{
            key: settings.get(key) for key in
            ("MODE", "DATA_WIDTH_A", "DATA_WIDTH_B", "REGMODE_A", "REGMODE_B")}})
    edge_rams = [r for r in ram_mapping if r["instance"].startswith("core/chain/video/align/edges/")]
    fifo_rams = [r for r in ram_mapping if r["instance"].startswith("core/chain/video/align/")
                 and not r["instance"].startswith("core/chain/video/align/edges/")]
    tag_rams = [r for r in ram_mapping if r["instance"].startswith("core/chain/video/")
                and not r["instance"].startswith("core/chain/video/align/")]
    ram_layout_ok = (
        len(edge_rams) == 3 and len(fifo_rams) == 23 and len(tag_rams) == 2
        and len(ram_mapping) == len(edge_rams)+len(fifo_rams)+len(tag_rams)
        and Counter(r["DATA_WIDTH_A"] for r in edge_rams) == {"1": 1, "10": 2}
        and Counter(r["DATA_WIDTH_A"] for r in fifo_rams) == {"1": 1, "5": 16, "40": 6}
        and Counter(r["DATA_WIDTH_A"] for r in tag_rams) == {"1": 1, "2": 1}
        and all(r["MODE"] == "DP20K" and r["DATA_WIDTH_A"] == r["DATA_WIDTH_B"]
                and r["REGMODE_A"] == r["REGMODE_B"] == "NOREG" for r in ram_mapping))
    ff_modes = re.findall(r'\.DFFMODE\("([^\"]+)"\)', netlist)
    # Ensure all three production-sized counters and both synchronizer stages
    # survive mapping; this is structural evidence, not a metastability test.
    button_registers = {
        name: len(re.findall(r"\\core/chain/controls/keys/" + name + r"_reg\[\d+\]\s+\(", netlist))
        for name in ("stable_count", "sync_first", "sync_second")
    }
    button_mapping_ok = button_registers == {"stable_count": 60, "sync_first": 3, "sync_second": 3}
    run_log = (syn_dir / "run.log").read_text(encoding="utf-8", errors="replace")
    warnings = [line.strip() for line in run_log.splitlines() if re.search(r"\b(?:WARNING|CRITICAL-WARNING|ERROR):", line)]
    # No ADC/pin locations are assigned to this synthetic observation wrapper.
    # This one reviewed warning is expected; any other warning/error needs review.
    unexpected_warnings = [line for line in warnings if not re.fullmatch(
        r"SYN-6021 CRITICAL-WARNING: \d+ out of \d+ logical ports has no user assigned specific location constraint\.", line)]
    unused_audit = None
    if "SYN-5025 WARNING: Using 0 for all undriven pins and nets" in warnings:
        # Never blanket-ignore undriven logic: inspect the pre-optimization DB
        # and require every diagnosed bit to be unreferenced in exported RTL.
        audit_log = run_td(executable,
            "import_db video_display_check_Runs/syn_1/video_display_check_elaborate.db\n"
            "set_warning_msg_repeat 10000\ncheck_rtl\nwrite_verilog undriven_review.v\nexit",
            run_dir, run_dir / "undriven_review.log", 60)
        unused_audit = audit(audit_log, (run_dir / "undriven_review.v").read_text(errors="replace"))
        unexpected_warnings = [w for w in unexpected_warnings if w !=
                               "SYN-5025 WARNING: Using 0 for all undriven pins and nets"]
    # Check the packet FIFO, edge RAMs and newly added mode/mask tag RAM.
    ram_ok = (resources["eram20k"] == physical_rams == 28 and ram_layout_ok
              and resources["dsp"] == 6
              and 0 < resources["reg"] < 2048 and resources["rtl_latch"] == 0
              and len(ff_modes) == resources["reg"] and set(ff_modes) == {"FF"})
    timing = (syn_dir / "video_display_check_gate.ts").read_text(encoding="utf-8", errors="replace")
    setup_match = re.search(r"SWNS:\s*([-+0-9.]+)ns", timing)
    hold_match = re.search(r"HWNS:\s*([-+0-9.]+)ns", timing)
    if not setup_match or not hold_match:
        raise RuntimeError("Missing synthesis timing estimate")
    setup_slack, hold_slack = float(setup_match.group(1)), float(hold_match.group(1))
    timing_met = math.isfinite(setup_slack) and math.isfinite(hold_slack) and setup_slack >= 0 and hold_slack >= 0
    manifest.update({
        "synthesis_passed": True, "resources": resources, "ram_resource_check_passed": ram_ok,
        "physical_eram_instances": physical_rams, "mapped_register_modes": sorted(set(ff_modes)),
        "ram_mapping": ram_mapping,
        "pixel_fifo_ram_blocks": len(fifo_rams), "edge_ram_blocks": len(edge_rams),
        "tag_fifo_ram_blocks": len(tag_rams),
        "synthesis_warnings": warnings, "unexpected_synthesis_warnings": unexpected_warnings,
        "undriven_unused_bit_audit": unused_audit,
        "timing_stage": "post-synthesis estimate, before placement and routing",
        "estimated_setup_slack_ns": setup_slack, "estimated_hold_slack_ns": hold_slack,
        "estimated_timing_met": timing_met,
        "button_register_counts": button_registers, "button_mapping_check_passed": button_mapping_ok,
        "checks_passed": ram_ok and button_mapping_ok and not unexpected_warnings and (timing_met or not args.require_timing),
    })
    save_manifest()
    print("PASS: button-controlled four-mode and OSD video synthesis completed.")
    print(f"Resources: ERAM20K={resources['eram20k']} Registers={resources['reg']} RTL-latches={resources['rtl_latch']}")
    if ram_ok:
        print("PASS: pixel FIFO=23, edge buffers=3, mode/mask FIFO=2 ERAM20K blocks.")
    print(f"Estimated setup slack at provisional {args.clock_mhz:g} MHz: {setup_slack:.3f} ns")
    print(f"Estimated hold slack: {hold_slack:.3f} ns")
    if timing_met:
        print("PASS: estimated timing meets the selected clock budget.")
    else:
        print("NOTE: estimated timing is not met; synthesis success alone is insufficient.")
    print(f"Resource report: {run_dir / 'video_display_area.rpt'}")
    print(f"Timing report: {run_dir / 'video_display_timing.rpt'}")
    if warnings and not unexpected_warnings:
        print("NOTE: probe ports have no board pin assignments; this is a standalone synthesis check.")
    if unexpected_warnings:
        raise RuntimeError(f"Unreviewed synthesis warnings/errors. See {syn_dir / 'run.log'}")
    if not ram_ok:
        raise RuntimeError("Button-controlled four-mode and OSD buffer resource check failed; inspect the RAM mapping.")
    if not button_mapping_ok:
        raise RuntimeError("Button counters/synchronizers mapping check failed.")
    if args.require_timing and not timing_met:
        raise RuntimeError("The selected standalone timing budget was not met.")
    print("PASS: integrated display synthesis checks completed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
