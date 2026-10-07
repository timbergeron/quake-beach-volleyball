#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Prepare current atlases, UV guides and prompts for external texture painting."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

from net_assets import REGIONS as NET_REGIONS
from player_assets import REGIONS as KIT_REGIONS

HERE = Path(__file__).resolve().parent
MODELS = ("bv_athlete.md3", "bv_athlete_away.md3", "bv_hands.md3", "bv_ball.md3", "bv_net.md3")


def regions_svg(width, height, regions):
    shapes = []
    for label, (x0, y0, x1, y1) in regions.items():
        shapes.append(f'<rect x="{x0}" y="{y0}" width="{x1-x0}" height="{y1-y0}" '
                      f'fill="none" stroke="#ffad33" stroke-width="2"/>'
                      f'<text x="{x0+8}" y="{y0+22}" font-family="sans-serif" '
                      f'font-size="16" fill="#ffad33" stroke="#000" stroke-width="0.5">{html.escape(label)}</text>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}">'+"".join(shapes)+"</svg>\n")


def generate(game, output, harness):
    game, output, harness = Path(game).resolve(), Path(output).resolve(), Path(harness).resolve()
    tool = harness/"tools/texture_kit.py"
    if not tool.is_file():
        raise ValueError("Update the sibling md3harness checkout for tools/texture_kit.py")
    subprocess.run([sys.executable, str(tool), *[str(game/"progs"/name) for name in MODELS],
                    "--asset-root", str(game), "--output", str(output)], check=True)
    metadata = output/"manifest.json"
    report = json.loads(metadata.read_text())
    report["complete"] = False
    metadata.write_text(json.dumps(report, indent=2)+"\n")
    # The game uses a single progs directory; flatten this handoff's filenames.
    page = (output/"index.html").read_text()
    for atlas in report["atlases"]:
        for key in ("png", "uv"):
            before = atlas[key]
            after = Path(before).name
            (output/before).rename(output/after)
            atlas[key] = after
            page = page.replace(before, after)
    (output/"progs").rmdir()
    overlays = {}
    for name, regions, size in (("bv_kit", KIT_REGIONS, 512), ("bv_net", NET_REGIONS, 1024)):
        atlas = next(a for a in report["atlases"] if a["shader"] == "progs/"+name)
        sx, sy = atlas["width"]/size, atlas["height"]/size
        scaled = {label: (x0*sx, y0*sy, x1*sx, y1*sy) for label, (x0,y0,x1,y1) in regions.items()}
        overlays[name] = regions_svg(atlas["width"], atlas["height"], scaled)
    atlas = next(a for a in report["atlases"] if a["shader"] == "progs/bv_hands")
    sx, sy = atlas["width"]/512, atlas["height"]/2048
    overlays["bv_hands"] = regions_svg(atlas["width"], atlas["height"],
        {"FOREARM": (4*sx,1820*sy,508*sx,2044*sy)})
    for name, svg in overlays.items():
        path = output/f"{name}_regions.svg"
        path.write_text(svg)
        before = f'<object data="{name}_uv.svg" type="image/svg+xml"></object>'
        page = page.replace(before, before+f'<object data="{path.name}" type="image/svg+xml"></object>')
        atlas = next(a for a in report["atlases"] if a["shader"] == "progs/"+name)
        atlas.update(regions=path.name, regions_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    guide = HERE/"docs/texture-authoring.md"
    (output/"INSTRUCTIONS.md").write_bytes(guide.read_bytes())
    page = page.replace('<main>', '<p><a href="INSTRUCTIONS.md">Painting instructions and prompts</a></p><main>')
    (output/"index.html").write_text(page)
    for relative in ("LICENSE", "THIRD_PARTY.md", "resources/hands/LICENSE.CC0.txt", "resources/anatomy/LICENSE.CC0.txt"):
        path = output/relative
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(HERE/relative, path)
    report["instructions_sha256"] = hashlib.sha256(guide.read_bytes()).hexdigest()
    report["complete"] = True
    metadata.write_text(json.dumps(report, indent=2)+"\n")
    archive = output.parent/(output.name+".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as zipped:
        for path in sorted(output.rglob("*")):
            if path.is_file():
                zipped.write(path, "texture-paint-kit/"+path.relative_to(output).as_posix())
    print(f"Painting kit archive: {archive}")
    return archive


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path, default=HERE/"dist/beachvolley")
    parser.add_argument("--output", type=Path, default=HERE/"build/texture-paint-kit")
    parser.add_argument("--harness", type=Path, default=HERE.parent/"md3harness")
    args = parser.parse_args()
    generate(args.game, args.output, args.harness)
