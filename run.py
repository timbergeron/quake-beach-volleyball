#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Launch the built mod using isolated configs and read-only base-game links."""

import argparse
import subprocess
from pathlib import Path


HERE = Path(__file__).resolve().parent


def stage_runtime(binary, basedir, runtime, game):
    runtime.mkdir(parents=True, exist_ok=True)
    (runtime / "id1").mkdir(exist_ok=True)
    found = False
    for name in ("pak0.pak", "pak1.pak"):
        source = basedir / "id1" / name
        if source.is_file():
            target = runtime / "id1" / name
            if not target.exists():
                target.symlink_to(source.resolve())
            found = True
    if not found:
        raise ValueError(f"no base-game PAKs in {basedir / 'id1'}")
    for name in ("quakespasm.pak", "qssm.pak"):
        source = binary.parent / name
        if source.is_file() and not (runtime / name).exists():
            (runtime / name).symlink_to(source.resolve())
    target = runtime / "beachvolley"
    if not target.exists():
        target.symlink_to(game.resolve(), target_is_directory=True)
    return runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bin", type=Path, required=True)
    parser.add_argument("--basedir", type=Path, required=True)
    parser.add_argument("--window", action="store_true")
    args = parser.parse_args()
    binary = args.bin.expanduser().resolve()
    basedir = args.basedir.expanduser().resolve()
    game = HERE / "dist/beachvolley"
    if not (game / "progs.dat").is_file():
        parser.error("build the mod with build.py first")
    runtime = stage_runtime(binary, basedir, HERE / ".runtime", game)
    command = [str(binary), "-basedir", str(runtime), "-game", "beachvolley", "-nohome",
               "+exec", "beach.cfg", "+map", "beach"]
    if args.window:
        command[1:1] = ["-window", "-width", "1280", "-height", "720"]
    raise SystemExit(subprocess.call(command, cwd=runtime))


if __name__ == "__main__":
    main()
