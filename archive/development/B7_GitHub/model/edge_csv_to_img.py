"""Restore full RTL edge frames and compare them with the captured RGB input."""

import argparse
import csv
import json
from pathlib import Path
import re
import sys

import numpy as np
from PIL import Image, ImageDraw


def read_frames(path, width, height):
    frames = {}
    with path.open(encoding="ascii", newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames != ["frame", "source_frame_id", "x", "y", "rgb"]:
            raise ValueError(f"Unexpected CSV header: {path}")
        for row in reader:
            frame = int(row["frame"])
            source_id = int(row["source_frame_id"])
            if frame < 0 or not 0 <= source_id <= 0xFFFFFFFF:
                raise ValueError("Invalid frame index or source ID")
            entry = frames.setdefault(frame, {"source_frame_id": source_id, "pixels": []})
            index = len(entry["pixels"])
            if index >= width * height or (int(row["x"]), int(row["y"])) != (index % width, index // width):
                raise ValueError(f"Frame {frame}: coordinates are missing, duplicated or out of order")
            if source_id != entry["source_frame_id"] or not re.fullmatch(r"[0-9a-fA-F]{6}", row["rgb"]):
                raise ValueError(f"Frame {frame}: invalid RGB value or mixed source IDs")
            entry["pixels"].append(tuple(bytes.fromhex(row["rgb"])))
    if not frames or sorted(frames) != list(range(len(frames))):
        raise ValueError("Expected consecutive frame indices starting at zero")
    for frame, entry in frames.items():
        if len(entry["pixels"]) != width * height:
            raise ValueError(f"Frame {frame}: expected {width*height} pixels, got {len(entry['pixels'])}")
        entry["rgb"] = np.array(entry.pop("pixels"), dtype=np.uint8).reshape(height, width, 3)
    return frames


def reference_edge(rgb, threshold):
    # Integer CPU reference from the captured input; no DUT result is used.
    color = rgb.astype(np.int32)
    gray = (77*color[:, :, 0] + 150*color[:, :, 1] + 29*color[:, :, 2] + 128) // 256
    gx = (gray[:-2, 2:] + 2*gray[1:-1, 2:] + gray[2:, 2:]
          - gray[:-2, :-2] - 2*gray[1:-1, :-2] - gray[2:, :-2])
    gy = (gray[2:, :-2] + 2*gray[2:, 1:-1] + gray[2:, 2:]
          - gray[:-2, :-2] - 2*gray[:-2, 1:-1] - gray[:-2, 2:])
    edge = np.zeros(gray.shape, dtype=np.uint8)
    edge[1:-1, 1:-1] = np.where(np.abs(gx)+np.abs(gy) >= threshold, 255, 0)
    return np.repeat(edge[:, :, None], 3, axis=2)


def main():
    folder = Path(__file__).resolve().parent / "test_data"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=folder / "edge_input.csv")
    parser.add_argument("--output", type=Path, default=folder / "edge_output.csv")
    parser.add_argument("--output-dir", type=Path, default=folder)
    parser.add_argument("--width", type=int, default=16)
    parser.add_argument("--height", type=int, default=12)
    parser.add_argument("--threshold", type=int, default=128)
    args = parser.parse_args()
    if not 3 <= args.width <= 2048 or not 3 <= args.height <= 2048 or not 0 <= args.threshold <= 2047:
        parser.error("Dimensions must be 3..2048 and threshold must be 0..2047")
    inputs = read_frames(args.input, args.width, args.height)
    outputs = read_frames(args.output, args.width, args.height)
    if inputs.keys() != outputs.keys():
        raise ValueError("Input and output frame sets differ")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    previews = []
    results = []
    for frame in sorted(inputs):
        source, actual = inputs[frame], outputs[frame]
        if source["source_frame_id"] != actual["source_frame_id"]:
            raise ValueError(f"Frame {frame}: source ID differs")
        expected = reference_edge(source["rgb"], args.threshold)
        diff = np.abs(actual["rgb"].astype(np.int16)-expected.astype(np.int16)).astype(np.uint8)
        mismatches = int(np.count_nonzero(np.any(diff != 0, axis=2)))
        images = {"input": Image.fromarray(source["rgb"]), "output": Image.fromarray(actual["rgb"]),
                  "reference": Image.fromarray(expected), "diff": Image.fromarray(diff)}
        for label, picture in images.items():
            picture.save(args.output_dir / f"edge_frame_{frame:03d}_{label}.png")
        # Preview only the first eight frames; every frame is still verified.
        if len(previews) < 8:
            cell_width = 320
            cell_height = max(1, round(args.height*cell_width/args.width))
            strip = Image.new("RGB", (3*cell_width, cell_height+30), "white")
            draw = ImageDraw.Draw(strip)
            for column, (label, title) in enumerate((("input", "INPUT RGB"), ("output", "ACTUAL RTL EDGE"), ("diff", "ABSOLUTE DIFF"))):
                draw.text((column*cell_width+6, 9), f"Frame {frame} / {title}", fill="black")
                strip.paste(images[label].resize((cell_width, cell_height), Image.Resampling.NEAREST), (column*cell_width, 30))
            previews.append(strip)
        results.append({"frame": frame, "source_frame_id": source["source_frame_id"],
                        "pixels": args.width*args.height, "pixel_mismatches": mismatches,
                        "maximum_channel_error": int(diff.max()), "passed": mismatches == 0})
        print(f"Frame {frame}: pixels={args.width*args.height}, mismatches={mismatches}")
    preview = Image.new("RGB", (previews[0].width, sum(p.height for p in previews)), "white")
    offset = 0
    for strip in previews:
        preview.paste(strip, (0, offset)); offset += strip.height
    preview_path = args.output_dir / "edge_preview.png"
    preview.save(preview_path)
    report = {"input_csv": str(args.input.resolve()), "output_csv": str(args.output.resolve()),
              "width": args.width, "height": args.height, "threshold": args.threshold,
              "border_rule": "final edge value is zero on all four borders",
              "frames": results, "passed": all(r["passed"] for r in results)}
    (args.output_dir / "edge_image_check.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(f"Preview: {preview_path.resolve()}")
    print("PASS: full RTL edge images match the integer reference." if report["passed"] else "FAIL: edge image pixels differ.")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
