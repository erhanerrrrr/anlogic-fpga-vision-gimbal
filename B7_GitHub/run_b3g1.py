"""Check strict same-source result selection before full B3 display wiring."""
import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
from b1_tools import simulate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelsim", type=Path, required=True)
    args = parser.parse_args()
    files = ["rtl/capture_target_gate.v", "rtl/b1_target_snapshot.v",
             "sim/tb_capture_target_gate.v"]
    run = ROOT / "build/capture_target_gate" / datetime.now().strftime("run_%Y%m%d_%H%M%S")
    run.mkdir(parents=True)
    result = {"passed": False, "scope": "strict same-source adapter and B1a snapshot unit test",
              "board_tested": False, "source_sha256": {
                  name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in files}}
    print(f"Reports: {run}", flush=True)
    try:
        for name in files:
            shutil.copy2(ROOT / name, run / Path(name).name)
        output = simulate(args.modelsim, run, [Path(name).name for name in files],
                          "tb_capture_target_gate", "PASS CAPTURE_TARGET_GATE:", timeout=60)
        if "Errors: 0, Warnings: 0" not in output:
            raise RuntimeError("ModelSim reported errors or warnings")
        result["passed"] = True
        print("PASS: B3g1 same-source gate checks completed.", flush=True)
    finally:
        (run / "summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
