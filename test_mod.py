#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Run gameplay regressions in QSS-M, then capture the court/HUD offscreen."""

import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

from run import HERE, stage_runtime


def run_case(binary, basedir, game, workspace, visual, play=False):
    name = "play" if play else "visual" if visual else "gameplay"
    runtime = workspace / name
    runtime.mkdir()
    shutil.copytree(game, runtime / "beachvolley")
    if not visual and not play:
        (runtime / "beachvolley/autoexec.cfg").write_text("exec server.cfg\n")
    stage_runtime(binary, basedir, runtime, runtime / "beachvolley")
    command = [str(binary), "-basedir", str(runtime), "-game", "beachvolley",
               "-nohome", "-nolan", "-noudp", "-nosound",
               "+set", "developer", "1", "+set", "bv_selftest", "0" if visual or play else "1",
               "+set", "bv_visualtest", "1" if visual else "0",
               "+set", "bv_playtest", "1" if play else "0",
               "+map", "beach"]
    if visual or play:
        command[1:1] = ["-window", "-width", "960", "-height", "540", "-nojoy", "-nomouse"]
        command.remove("-nosound")
        # Shader warmup and screenshot readback must not lengthen the scripted
        # button hold. Variable server rates are checked separately in QC.
        command[-2:-2] = ["+set", "host_timescale", "0", "+set", "host_framerate", "0.01",
                         "+set", "host_maxfps", "100"]
    else:
        command.insert(1, "-dedicated")
    env = {**os.environ, "SDL_VIDEO_DRIVER": "offscreen", "SDL_AUDIO_DRIVER": "dummy",
           "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2"}
    result = subprocess.run(command, cwd=runtime, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors="replace", timeout=40)
    artifacts = HERE / "artifacts"
    artifacts.mkdir(exist_ok=True)
    (artifacts / f"{name}.log").write_text(result.stdout)
    errors = []
    if result.returncode:
        errors.append(f"engine exit {result.returncode}")
    for forbidden in ("BEACH FAIL", "BEACH PLAY FAIL", "Host_Error", "Sys_Error", "Program error",
                      "unimplemented builtin", "Shader compilation failed", "Could not load",
                      "not looped", "bad loop", "Couldn't load sound/beach"):
        if forbidden in result.stdout:
            errors.append(forbidden)
    if play:
        for marker in ("BEACH PLAY PASS serve-contact", "BEACH PLAY PASS serve-landed-in",
                       "BEACH PLAY HUD serve", "BEACH PLAY DONE"):
            if marker not in result.stdout:
                errors.append(f"missing {marker}")
        images = sorted((runtime / "beachvolley/screenshots").glob("*.tga"))
        if not images:
            errors.append("no preparation screenshot")
        else:
            shutil.copyfile(images[-1], artifacts / "serve-preparation.tga")
    elif visual:
        if "BEACH HUD READY" not in result.stdout:
            errors.append("HUD did not render")
        images = sorted((runtime / "beachvolley/screenshots").glob("*.tga"))
        if not images:
            errors.append("no screenshot")
        else:
            dimensions = struct.unpack_from("<HH", images[-1].read_bytes(), 12)
            if dimensions != (960, 540):
                errors.append(f"unexpected screenshot size: {dimensions}")
            shutil.copyfile(images[-1], artifacts / "court.tga")
    else:
        completed = re.search(r"BEACH DONE pass=(\d+) fail=(\d+)", result.stdout)
        if not completed or int(completed[2]) or int(completed[1]) < 40:
            errors.append("missing or failed gameplay completion marker")
    if errors:
        raise RuntimeError(f"{name}: {', '.join(errors)}\n{result.stdout[-6000:]}")
    return {"name": name, "passes": re.findall(r"BEACH (?:PLAY )?PASS (.+)", result.stdout),
            "screenshot": "serve-preparation.tga" if play else "court.tga" if visual else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, required=True)
    parser.add_argument("--basedir", type=Path, required=True)
    parser.add_argument("--skip-visual", action="store_true")
    args = parser.parse_args()
    binary = args.bin.expanduser().resolve()
    basedir = args.basedir.expanduser().resolve()
    game = HERE / "dist/beachvolley"
    if not (game / "maps/beach.bsp").is_file():
        parser.error("build the mod first")
    with tempfile.TemporaryDirectory(prefix="beachvolley-test-") as temporary:
        workspace = Path(temporary)
        results = [run_case(binary, basedir, game, workspace, False)]
        if not args.skip_visual:
            results.append(run_case(binary, basedir, game, workspace, True))
            results.append(run_case(binary, basedir, game, workspace, False, True))
    summary = {"engine_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
               "progs_sha256": hashlib.sha256((game / "progs.dat").read_bytes()).hexdigest(),
               "csprogs_sha256": hashlib.sha256((game / "csprogs.dat").read_bytes()).hexdigest(),
               "results": results}
    (HERE / "artifacts/summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    for result in results:
        print(f"{result['name']}: PASS ({len(result['passes'])} gameplay assertions)")


if __name__ == "__main__":
    main()
