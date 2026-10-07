#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Exercise CSQC menu input and server actions in native QSS-M, with captures."""
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
import time

from hand_view import png_from_tga
from run import HERE, stage_runtime


def stage_asset(source, destination):
    # Immutable assets may be large. Each test still has independent configs.
    if Path(source).suffix in (".dat", ".md3", ".mdl", ".wav", ".bsp", ".lit", ".png", ".tga", ".json"):
        os.link(source, destination)
        return destination
    return shutil.copy2(source, destination)


def digest(path):
    with Path(path).open("rb") as stream:
        result = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
        return result.hexdigest()


def capture_case(binary, basedir, output, name, width, height, scale, timeout):
    game = HERE / "dist/beachvolley"
    with tempfile.TemporaryDirectory(prefix="beach-menu-", dir=HERE / "build") as directory:
        runtime = Path(directory)
        target = runtime / "beachvolley"
        shutil.copytree(game, target, copy_function=stage_asset, symlinks=True)
        stage_runtime(binary, basedir, runtime, target)
        settings = dict(developer=1, bv_selftest=0, bv_visualtest=0, bv_playtest=0,
                        bv_matchtest=0, bv_bottest=0, bv_receivetest=0, bv_netview=0,
                        bv_handview=0, bv_menutest=1, host_timescale=0, host_framerate=0.1,
                        host_maxfps=100, scr_sbarscale=scale, con_notifytime=0,
                        con_notifylines=0, scr_fade=0, scr_conspeed=100000,
                        bv_contact_kick=1, bv_menu_auto=1, gamma=1, contrast=1)
        (target / "fixture.cfg").write_text("exec beach.cfg\n" + "".join(
            f"set {key} {value}\n" for key, value in settings.items()) + "map beach\n")
        command = [str(binary), "-basedir", str(runtime), "-game", "beachvolley", "-nohome",
                   "-nolan", "-noudp", "-nosound", "-window", "-width", str(width), "-height", str(height),
                   "-nojoy", "-nomouse", "-fsaa", "4", "+exec", "fixture.cfg"]
        env = dict(os.environ, SDL_VIDEO_DRIVER="offscreen", SDL_AUDIO_DRIVER="dummy",
                   LIBGL_ALWAYS_SOFTWARE="1", LP_NUM_THREADS="2")
        log = output / f"{name}.log"
        with log.open("w") as stream:
            process = subprocess.Popen(command, cwd=runtime, env=env, stdout=stream,
                                       stderr=subprocess.STDOUT)
            started = time.monotonic()
            try:
                while process.poll() is None:
                    text = log.read_text(errors="replace")
                    if any(error in text for error in ("Host_Error", "Sys_Error", "Program error")):
                        raise RuntimeError(f"{name}: engine error; see {log}")
                    if time.monotonic() - started > timeout:
                        raise RuntimeError(f"{name}: engine timed out; see {log}")
                    time.sleep(0.1)
            finally:
                if process.poll() is None:
                    process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                if process.returncode:
                    for index, source in enumerate(sorted((target / "screenshots").glob("*.tga"))):
                        (output / f"{name}-failed-{index:02d}.png").write_bytes(png_from_tga(source))
        text = log.read_text(errors="replace")
        completion = re.search(r"BEACH MENU DONE pass=(\d+) fail=(\d+)", text)
        failures = re.findall(r"BEACH MENU FAIL .+|Host_Error[^\n]*|Sys_Error[^\n]*|Program error[^\n]*|unimplemented builtin[^\n]*|qcrequest[^\n]*not supported", text)
        if process.returncode or not completion or int(completion[2]) or failures:
            raise RuntimeError(f"{name}: menu fixture failed; see {log}\n" + "\n".join(failures))
        if int(completion[1]) < 35:
            raise RuntimeError(f"{name}: too few assertions: {completion[1]}")
        images = sorted((target / "screenshots").glob("*.tga"))
        labels = ("home", "practice", "settings", "learn", "resume", "confirm", "look", "first-serve")
        if len(images) != len(labels):
            raise RuntimeError(f"{name}: expected {len(labels)} captures, got {len(images)}")
        records = []
        for label, source in zip(labels, images):
            if struct.unpack_from("<HH", source.read_bytes(), 12) != (width, height):
                raise RuntimeError(f"{name}: wrong capture dimensions")
            png = output / f"{name}-{label}.png"
            png.write_bytes(png_from_tga(source))
            records.append(dict(file=png.name, sha256=digest(png), width=width, height=height))
        return dict(name=name, assertions=int(completion[1]), settings=settings, captures=records)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, required=True)
    parser.add_argument("--basedir", type=Path, required=True)
    parser.add_argument("--artifacts", type=Path, default=HERE / "artifacts/menu")
    parser.add_argument("--case", action="append", choices=("desktop", "compact", "large-hud", "wide"))
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    binary = args.bin.expanduser().resolve()
    basedir = args.basedir.expanduser().resolve()
    output = args.artifacts.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    (HERE / "build").mkdir(exist_ok=True)
    game = HERE / "dist/beachvolley"
    summary = dict(complete=False, engine_sha256=digest(binary),
                   progs_sha256=digest(game / "progs.dat"), csprogs_sha256=digest(game / "csprogs.dat"), results=[])
    report = output / "summary.json"
    report.write_text(json.dumps(summary, indent=2) + "\n")
    for name, width, height, scale in (("desktop", 1280, 720, 2), ("compact", 640, 480, 2), ("large-hud", 1280, 720, 4), ("wide", 1600, 900, 2)):
        if args.case and name not in args.case:
            continue
        result = capture_case(binary, basedir, output, name, width, height, scale, args.timeout)
        summary["results"].append(result)
        report.write_text(json.dumps(summary, indent=2) + "\n")
        print(f"{name}: PASS ({result['assertions']} native menu assertions)", flush=True)
    summary["complete"] = True
    report.write_text(json.dumps(summary, indent=2) + "\n")


if __name__ == "__main__":
    main()
