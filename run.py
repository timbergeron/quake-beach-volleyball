#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Launch the built mod using isolated configs and read-only base-game links."""

import argparse
import subprocess
from pathlib import Path


HERE = Path(__file__).resolve().parent


def stage_runtime(binary, basedir, runtime, game):
    if not (basedir / "id1/pak0.pak").is_file():
        raise ValueError(f"base-game pak0.pak missing in {basedir / 'id1'}")
    runtime.mkdir(parents=True, exist_ok=True)
    (runtime / "id1").mkdir(exist_ok=True)
    links = []
    for name in ("pak0.pak", "pak1.pak"):
        source = basedir / "id1" / name
        links.append((runtime / "id1" / name, source if source.is_file() else None))
    for name in ("quakespasm.pak", "qssm.pak"):
        source = binary.parent / name
        links.append((runtime / name, source if source.is_file() else None))
    links.append((runtime / "beachvolley", game))
    # Tests use a copied game directory at exactly this path. Other regular
    # files/directories belong to the user and must never be replaced.
    for target, source in links:
        if source is not None and target.resolve() == source.resolve():
            continue
        if target.exists() and not target.is_symlink():
            raise ValueError(f"runtime path is not a managed symlink: {target}")
    for target, source in links:
        if source is not None and target.resolve() == source.resolve():
            continue
        if target.is_symlink():
            target.unlink()
        if source is not None:
            target.symlink_to(source.resolve(), target_is_directory=source.is_dir())
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
