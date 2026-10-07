#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Make a self-contained animated review of the exact exported MD3 bytes."""
import argparse
import base64
import gzip
import hashlib
import json
from pathlib import Path
import struct
import zlib

from player_assets import HERE, animation_manifest, harness


def texture_png(tga):
    data = Path(tga).read_bytes()
    width, height = struct.unpack_from("<HH", data, 12)
    if data[2] != 2 or data[16] != 32 or data[17] != 0x28:
        raise ValueError("expected the generated top-down RGBA TGA")
    rgba = bytearray()
    for row in range(height):
        rgba.append(0)
        for x in range(width):
            b, g, r, a = data[18+(row*width+x)*4:22+(row*width+x)*4]
            rgba.extend((r, g, b, a))
    def chunk(kind, body):
        return struct.pack(">I", len(body))+kind+body+struct.pack(">I", zlib.crc32(kind+body) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            +chunk(b"IDAT", zlib.compress(rgba, 9))+chunk(b"IEND", b""))


def generate_review(game, output):
    cli = harness()
    game, output = Path(game), Path(output)
    model = game / "progs/bv_athlete.md3"
    # Read and validate exported bytes, never preview an unexported source rig.
    from md3harness.quality import inspect
    digest = hashlib.sha256(model.read_bytes()).hexdigest()
    cached = HERE / "build/player-quality/athlete.report.json"
    report = json.loads(cached.read_text()) if cached.is_file() else None
    if not (report and report.get("sha256") == digest and all(
            (game / t["path"]).is_file() and hashlib.sha256((game / t["path"]).read_bytes()).hexdigest() == t["sha256"]
            for t in report.get("textures", {}).values())):
        from anatomical_body import CONTRACT
        report = inspect(model, game, CONTRACT)
    if not report["passed"] or report["issues"]:
        raise ValueError("cannot review an invalid exported player")
    textures = {name: base64.b64encode(texture_png(game / f"progs/{name}.tga")).decode()
                for name in ("bv_athlete", "bv_athlete_away", "bv_kit")}
    manifest = animation_manifest()
    manifest["sha256"] = digest
    manifest["triangles"] = sum(s["triangles"] for s in report["surfaces"])
    page = (HERE / "resources/player-review.html").read_text()
    page = page.replace("__MODEL__", base64.b64encode(gzip.compress(model.read_bytes(), mtime=0)).decode())
    page = page.replace("__MANIFEST__", json.dumps(manifest)).replace("__TEXTURES__", json.dumps(textures))
    output.mkdir(parents=True, exist_ok=True)
    (output / "animation.html").write_text(page)
    cli.save_json(output / "animations.json", manifest)
    print(f"Animated review: {(output / 'animation.html').resolve()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path, default=HERE / "dist/beachvolley")
    parser.add_argument("--output", type=Path, default=HERE / "build/player-review")
    args = parser.parse_args()
    generate_review(args.game, args.output)
