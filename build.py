#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Build a playable version-6 QuakeC mod; never modifies the Quake install."""

import argparse
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

from assets import generate


HERE = Path(__file__).resolve().parent
GAME = HERE / "dist/beachvolley"
BUILD = HERE / "build"


def run(command, cwd, name):
    result = subprocess.run([str(arg) for arg in command], cwd=cwd,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=120)
    log = BUILD / f"{name}.log"
    log.write_text(result.stdout)
    if result.returncode:
        raise RuntimeError(f"{name} failed; see {log}\n{result.stdout[-4000:]}")
    if name.startswith("qc-") and re.search(r"\b(?:warning|error)\b", result.stdout, re.I):
        raise RuntimeError(f"{name} emitted warnings; see {log}\n{result.stdout[-4000:]}")
    print(f"{name}: OK")


def tool(value, name):
    path = Path(value).expanduser().resolve() if value else None
    if path and path.is_file():
        return path
    found = shutil.which(name)
    if found:
        return Path(found)
    raise ValueError(f"{name} not found; supply --{name}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--basedir", type=Path, required=True, help="Quake directory containing id1")
    parser.add_argument("--fteqcc")
    parser.add_argument("--qbsp")
    parser.add_argument("--light")
    parser.add_argument("--vis")
    args = parser.parse_args()
    fteqcc = tool(args.fteqcc, "fteqcc")
    qbsp = tool(args.qbsp, "qbsp")
    light = tool(args.light, "light")
    vis = tool(args.vis, "vis")
    generate(args.basedir.expanduser().resolve(), BUILD, GAME)
    run([fteqcc, "-Wall", "-srcfile", "progs.src"], HERE / "src", "qc-server")
    run([fteqcc, "-Wall", "-DCSQC=1", "-srcfile", "csprogs.src"], HERE / "src", "qc-hud")
    run([qbsp, "-nopercent", "-leaktest", BUILD / "beach.map", GAME / "maps/beach.bsp"],
        BUILD, "qbsp")
    run([vis, "-threads", "2", GAME / "maps/beach.bsp"], BUILD, "vis")
    run([light, "-threads", "2", "-extra4", GAME / "maps/beach.bsp"], BUILD, "light")
    package_game()


def package_game():
    """Package the current compiled game and generated assets."""
    shutil.copyfile(HERE / "beach.cfg", GAME / "beach.cfg")
    shutil.copyfile(HERE / "server.cfg", GAME / "server.cfg")
    (GAME / "autoexec.cfg").write_text("exec beach.cfg\n")
    documents = ("README.md", "LICENSE", "THIRD_PARTY.md", "docs/court.png", "docs/ball.png", "docs/net.png", "docs/player.md", "docs/player.png", "docs/hands.md", "docs/hands.png", "docs/model-detail.md", "docs/texture-authoring.md", "resources/hands/LICENSE.CC0.txt", "resources/anatomy/LICENSE.CC0.txt")
    documents += tuple(path.relative_to(HERE).as_posix()
                       for path in sorted((HERE / "docs/releases").glob("*.md")))
    documents += tuple(path.relative_to(HERE).as_posix()
                       for path in sorted((HERE / "docs/screenshots").glob("*"))
                       if path.suffix in (".png", ".json"))
    documents += tuple(path.relative_to(HERE).as_posix()
                       for directory in ("docs/player-quality", "docs/model-quality", "docs/model-review")
                       for path in sorted((HERE / directory).rglob("*"))
                       if path.suffix in (".png", ".json", ".html"))
    for name in documents:
        (GAME / name).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(HERE / name, GAME / name)
    archive = HERE / "dist/beachvolley.zip"
    # Include only distributable content, never runtime configs or Quake data.
    members = [GAME / name for name in ("progs.dat", "csprogs.dat", "beach.cfg", "server.cfg", "autoexec.cfg")]
    members.extend(GAME / name for name in documents)
    obsolete = {"progs/bv_ball.mdl", "textures/beach/bv_tape.tga",
                "progs/bv_athlete.mdl", "progs/bv_hands.mdl",
                "textures/beach/bv_pole.tga", "textures/beach/{bv_net.tga"}
    for directory in ("maps", "progs", "sound", "textures", "gfx"):
        members.extend(p for p in (GAME / directory).rglob("*") if p.suffix in (".bsp", ".lit", ".mdl", ".md3", ".wav", ".tga")
                       and p.relative_to(GAME).as_posix() not in obsolete)
    members.append(GAME / "progs/bv_athlete.animations.json")
    members.append(GAME / "progs/bv_hands.animations.json")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as output:
        for path in sorted(members):
            output.write(path, path.relative_to(GAME.parent))
    print(f"Playable mod: {GAME}\nInstall archive: {archive}")


if __name__ == "__main__":
    main()
