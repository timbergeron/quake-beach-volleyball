#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Capture exact first-person hand poses in QSS-M's actual alias renderer."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
import zlib

from player_assets import HERE, CLIPS, FRAME_COUNT
from run import stage_runtime


def png_from_tga(path):
    data = path.read_bytes()
    width, height = struct.unpack_from("<HH", data, 12)
    depth, descriptor = data[16:18]
    if data[2] != 2 or depth not in (24, 32):
        raise ValueError("expected a true-color engine screenshot")
    stride = depth//8
    rgba = bytearray()
    for row in range(height):
        rgba.append(0)
        source_row = row if descriptor & 32 else height-1-row
        for x in range(width):
            offset = 18+data[0]+(source_row*width+x)*stride
            b, g, r = data[offset:offset+3]
            rgba.extend((r, g, b, data[offset+3] if stride == 4 else 255))
    def chunk(kind, body):
        return struct.pack(">I", len(body))+kind+body+struct.pack(">I", zlib.crc32(kind+body) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            +chunk(b"IDAT", zlib.compress(rgba, 9))+chunk(b"IEND", b""))


def capture(binary, basedir, game, output, selected=None):
    output.mkdir(parents=True, exist_ok=True)
    clips = {c.name: c for c in CLIPS}
    keys = [("ready", clips["ready"].start),
            ("deep-dish", clips["set_load"].start+clips["set_load"].count-1),
            ("set-release", clips["set"].start+3),
            ("float-toss", clips["float_load"].start+clips["float_load"].count-1),
            ("float-contact", clips["float_serve"].start+2),
            ("cut-inward", clips["cut"].start+3),
            ("cut-away", FRAME_COUNT+3)]
    review = dict(engine_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
        model_sha256=hashlib.sha256((game/"progs/bv_hands.md3").read_bytes()).hexdigest(),
        skin_sha256=hashlib.sha256((game/"progs/bv_hands.tga").read_bytes()).hexdigest(), captures=[])
    metadata = output/"review.json"
    if selected and metadata.is_file():
        previous = json.loads(metadata.read_text())
        if all(previous.get(k) == review[k] for k in ("engine_sha256", "model_sha256", "skin_sha256")):
            review["captures"] = previous["captures"]
    with tempfile.TemporaryDirectory(prefix="beach-hand-view-", dir=HERE/"build") as directory:
        for index, (name, frame) in enumerate(keys, 1):
            if selected and name not in selected:
                continue
            runtime = Path(directory)/name
            runtime.mkdir()
            target = runtime/"beachvolley"
            shutil.copytree(game, target)
            stage_runtime(binary, basedir, runtime, target)
            (target/"fixture.cfg").write_text(f"set developer 1\nset bv_selftest 0\nset bv_handview {index}\n"
                "set host_timescale 0\nset host_framerate 0.05\nset host_maxfps 100\n"
                "set bv_help 0\nset con_notifytime 0\nset con_notifylines 0\nset scr_fade 0\n"
                "set scr_conspeed 100000\nmap beach\n")
            command = [str(binary), "-window", "-width", "1280", "-height", "720", "-nojoy", "-nomouse",
                "-fsaa", "4", "-basedir", str(runtime), "-game", "beachvolley", "-nohome", "-nolan", "-noudp",
                "-nosound", "+exec", "fixture.cfg"]
            env = {**os.environ, "SDL_VIDEO_DRIVER": "offscreen", "SDL_AUDIO_DRIVER": "dummy",
                   "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2"}
            result = subprocess.run(command, cwd=runtime, env=env, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, errors="replace", timeout=120)
            (output/f"{name}.log").write_text(result.stdout)
            found = re.search(r"BEACH HAND VIEW frame=(\d+)", result.stdout)
            screenshots = sorted((target/"screenshots").glob("*.tga"))
            if result.returncode or not found or int(found[1]) != frame or not screenshots or "BEACH HAND VIEW DONE" not in result.stdout:
                raise RuntimeError(f"{name}: capture failed; see {output/name}.log")
            png = output/f"{name}.png"
            png.write_bytes(png_from_tga(screenshots[0]))
            review["captures"] = [c for c in review["captures"] if c["name"] != name]
            review["captures"].append(dict(name=name, frame=frame, image=png.name,
                sha256=hashlib.sha256(png.read_bytes()).hexdigest()))
            metadata.write_text(json.dumps(review, indent=2)+"\n")
            print(f"{name}: PASS (first-person MD3 frame {frame})", flush=True)
    return review


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, required=True)
    parser.add_argument("--basedir", type=Path, required=True)
    parser.add_argument("--game", type=Path, default=HERE/"dist/beachvolley")
    parser.add_argument("--output", type=Path, default=HERE/"artifacts/hands-qssm")
    parser.add_argument("--case", action="append", choices=("ready", "deep-dish", "set-release",
        "float-toss", "float-contact", "cut-inward", "cut-away"), help="capture selected views; repeat to select several")
    args = parser.parse_args()
    capture(args.bin.resolve(), args.basedir.resolve(), args.game.resolve(), args.output.resolve(), args.case)
