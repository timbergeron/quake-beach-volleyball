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


def run_case(binary, basedir, game, workspace, visual, play=False, profile="default"):
    name = "play" if play else "visual" if visual else "gameplay"
    if profile != "default":
        name = profile
    width, height = (640, 480) if profile == "compact" else (960, 540)
    runtime = workspace / name
    runtime.mkdir()
    shutil.copytree(game, runtime / "beachvolley")
    match = profile in ("match", "match-set", "match-topspin")
    bot = profile in ("bot-dive", "bot-dive-fast")
    receive = profile in ("receive-float", "receive-topspin", "receive-early", "receive-late")
    if not visual and not play and not match and not bot and not receive:
        (runtime / "beachvolley/autoexec.cfg").write_text("exec server.cfg\n")
    stage_runtime(binary, basedir, runtime, runtime / "beachvolley")
    command = [str(binary), "-basedir", str(runtime), "-game", "beachvolley",
               "-nohome", "-nolan", "-noudp", "-nosound",
               "+set", "developer", "1", "+set", "bv_selftest", "0" if visual or play or match or bot or receive else "1",
               "+set", "bv_visualtest", "2" if profile == "compact" else "1" if visual else "0",
               "+set", "bv_playtest", str({"opposite": 2, "sweet": 3, "late": 4, "jump-serve": 5}.get(profile, 1)) if play else "0",
               "+set", "bv_matchtest", "3" if profile == "match-topspin" else "2" if profile == "match-set" else "1" if match else "0",
               "+set", "bv_bottest", "1" if bot else "0",
               "+set", "bv_receivetest", str({"receive-float": 1, "receive-topspin": 2,
                   "receive-early": 3, "receive-late": 4}.get(profile, 0)),
               "+map", "beach"]
    if visual or play or match or bot or receive:
        command[1:1] = ["-window", "-width", str(width), "-height", str(height), "-nojoy", "-nomouse"]
        command.remove("-nosound")
        # Shader warmup and screenshot readback must not lengthen the scripted
        # button hold. Variable server rates are checked separately in QC.
        command[-2:-2] = ["+set", "host_timescale", "0", "+set", "host_framerate", "0.02" if match or profile == "bot-dive" else "0.01",
                         "+set", "host_maxfps", "100"]
        if profile == "compact":
            command[-2:-2] = ["+set", "scr_sbarscale", "2", "+set", "bv_help", "1"]
    else:
        command.insert(1, "-dedicated")
    env = {**os.environ, "SDL_VIDEO_DRIVER": "offscreen", "SDL_AUDIO_DRIVER": "dummy",
           "LIBGL_ALWAYS_SOFTWARE": "1", "LP_NUM_THREADS": "2"}
    artifacts = HERE / "artifacts"
    artifacts.mkdir(exist_ok=True)
    try:
        result = subprocess.run(command, cwd=runtime, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, errors="replace", timeout=80 if match else 40)
    except subprocess.TimeoutExpired as failure:
        output = failure.stdout or b""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        (artifacts / f"{name}.log").write_text(output)
        raise RuntimeError(f"{name}: engine timed out\n{output[-6000:]}") from failure
    (artifacts / f"{name}.log").write_text(result.stdout)
    errors = []
    if result.returncode:
        errors.append(f"engine exit {result.returncode}")
    for forbidden in ("BEACH FAIL", "BEACH PLAY FAIL", "BEACH MATCH FAIL", "BEACH BOT FAIL", "BEACH RECEIVE FAIL", "Host_Error", "Sys_Error", "Program error",
                      "unimplemented builtin", "Shader compilation failed", "Could not load",
                      "not looped", "bad loop", "not precached", "Couldn't load sound/beach", "couldn't load bitmap font"):
        if forbidden in result.stdout:
            errors.append(forbidden)
    if receive:
        for marker in ("BEACH RECEIVE PASS manual-physical-contact", "BEACH RECEIVE PASS timing-and-control",
                       "BEACH RECEIVE HUD timing-and-cushion", "BEACH RECEIVE DONE"):
            if marker not in result.stdout:
                errors.append(f"missing {marker}")
        images = sorted((runtime / "beachvolley/screenshots").glob("*.tga"))
        if len(images) != 2:
            errors.append("missing live receive/feedback captures")
        else:
            screenshot = f"{name}.tga"
            shutil.copyfile(images[0], artifacts / screenshot)
            shutil.copyfile(images[-1], artifacts / f"{name}-contact.tga")
    elif bot:
        for marker in ("BEACH BOT PASS physical-dive-and-pose", "BEACH BOT PASS live-emergency-dig",
                       "BEACH BOT PASS dig-recovery", "BEACH BOT DONE"):
            if marker not in result.stdout:
                errors.append(f"missing {marker}")
        images = sorted((runtime / "beachvolley/screenshots").glob("*.tga"))
        if len(images) != 2:
            errors.append("missing live dive/dig captures")
        else:
            screenshot = f"{name}.tga"
            shutil.copyfile(images[0], artifacts / screenshot)
            shutil.copyfile(images[-1], artifacts / f"{name}-contact.tga")
    elif match:
        for marker in ("BEACH MATCH PASS live-receive-set-attack-return",
                       "BEACH MATCH PASS point-scored-once", "BEACH MATCH HUD score-and-guidance",
                       "BEACH MATCH HUD point-reason",
                       "BEACH MATCH DONE"):
            if marker not in result.stdout:
                errors.append(f"missing {marker}")
        if profile == "match-topspin" and "BEACH MATCH PASS opponent-jump-topspin" not in result.stdout:
            errors.append("missing physical opponent jump serve")
        images = sorted((runtime / "beachvolley/screenshots").glob("*.tga"))
        if len(images) != 2:
            errors.append("missing live doubles/point captures")
        else:
            screenshot = f"{name}.tga"
            shutil.copyfile(images[0], artifacts / screenshot)
            shutil.copyfile(images[-1], artifacts / f"{name}-point.tga")
    elif play:
        landing_marker = "late-serve-misses" if profile == "late" else "serve-landed-in"
        for marker in ("BEACH PLAY PASS serve-contact", f"BEACH PLAY PASS {landing_marker}",
                       "BEACH PLAY PASS serve-quality", "BEACH PLAY HUD timing",
                       "BEACH PLAY HUD quality",
                       "BEACH PLAY HUD serve", "BEACH PLAY HUD reach", "BEACH PLAY HUD preview",
                       "BEACH PLAY DONE"):
            if marker not in result.stdout:
                errors.append(f"missing {marker}")
        if profile == "jump-serve" and "BEACH PLAY PASS live-jump-topspin" not in result.stdout:
            errors.append("missing live jump/topspin contact")
        images = sorted((runtime / "beachvolley/screenshots").glob("*.tga"))
        if len(images) != 2:
            errors.append("missing preparation/contact feedback captures")
        else:
            screenshot = f"{profile}-serve.tga" if profile in ("sweet", "late", "opposite", "jump-serve") else "serve-preparation.tga"
            shutil.copyfile(images[0], artifacts / screenshot)
            shutil.copyfile(images[-1], artifacts / f"{name}-contact.tga")
    elif visual:
        if "BEACH HUD READY" not in result.stdout:
            errors.append("HUD did not render")
        images = sorted((runtime / "beachvolley/screenshots").glob("*.tga"))
        if not images:
            errors.append("no screenshot")
        else:
            dimensions = struct.unpack_from("<HH", images[-1].read_bytes(), 12)
            if dimensions != (width, height):
                errors.append(f"unexpected screenshot size: {dimensions}")
            screenshot = "compact-hud.tga" if profile == "compact" else "court.tga"
            shutil.copyfile(images[-1], artifacts / screenshot)
            if profile == "compact":
                if len(images) != 2:
                    errors.append("missing compact help/HUD captures")
                else:
                    shutil.copyfile(images[0], artifacts / "compact-help.tga")
    else:
        completed = re.search(r"BEACH DONE pass=(\d+) fail=(\d+)", result.stdout)
        if not completed or int(completed[2]) or int(completed[1]) < 205:
            errors.append("missing or failed gameplay completion marker")
    if errors:
        raise RuntimeError(f"{name}: {', '.join(errors)}\n{result.stdout[-6000:]}")
    return {"name": name, "passes": re.findall(r"BEACH (?:(?:PLAY|MATCH|BOT|RECEIVE) )?PASS (.+)", result.stdout),
            "screenshot": screenshot if visual or play or match or bot or receive else None,
            "contact_screenshot": f"{name}-contact.tga" if play or bot or receive else None,
            "custom_font": "BEACH HUD FONT custom" in result.stdout if visual or play or match or bot or receive else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, required=True)
    parser.add_argument("--basedir", type=Path, required=True)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--skip-visual", action="store_true")
    selection.add_argument("--case", action="append", choices=("gameplay", "visual", "play", "opposite",
        "sweet", "late", "compact", "match", "match-set", "bot-dive", "bot-dive-fast", "jump-serve",
        "receive-float", "receive-topspin", "receive-early", "receive-late", "match-topspin"),
        help="run a selected case; repeat to select several")
    args = parser.parse_args()
    binary = args.bin.expanduser().resolve()
    basedir = args.basedir.expanduser().resolve()
    game = HERE / "dist/beachvolley"
    if not (game / "maps/beach.bsp").is_file():
        parser.error("build the mod first")
    # Runtime copies can exceed a small system tmpfs when the whole suite runs.
    scratch = HERE / "build"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="beachvolley-test-", dir=scratch) as temporary:
        workspace = Path(temporary)
        cases = (("gameplay", False, False, "default"), ("visual", True, False, "default"),
                 ("play", False, True, "default"), ("opposite", False, True, "opposite"),
                 ("sweet", False, True, "sweet"), ("late", False, True, "late"),
                 ("compact", True, False, "compact"), ("match", False, False, "match"),
                 ("match-set", False, False, "match-set"), ("bot-dive", False, False, "bot-dive"),
                 ("bot-dive-fast", False, False, "bot-dive-fast"),
                 ("jump-serve", False, True, "jump-serve"),
                 ("receive-float", False, False, "receive-float"),
                 ("receive-topspin", False, False, "receive-topspin"),
                 ("receive-early", False, False, "receive-early"),
                 ("receive-late", False, False, "receive-late"),
                 ("match-topspin", False, False, "match-topspin"))
        selected = args.case or (["gameplay"] if args.skip_visual else [case[0] for case in cases])
        results = [run_case(binary, basedir, game, workspace, visual, play, profile)
                   for name, visual, play, profile in cases if name in selected]
    summary = {"engine_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
               "progs_sha256": hashlib.sha256((game / "progs.dat").read_bytes()).hexdigest(),
               "csprogs_sha256": hashlib.sha256((game / "csprogs.dat").read_bytes()).hexdigest(),
               "results": results}
    (HERE / "artifacts/summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    for result in results:
        print(f"{result['name']}: PASS ({len(result['passes'])} gameplay assertions)")


if __name__ == "__main__":
    main()
