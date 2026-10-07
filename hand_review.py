#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Self-contained review of the exported first-person MD3 and skin."""
import argparse
import base64
import gzip
import hashlib
import json
from pathlib import Path

from player_assets import HERE, harness
from hand_assets import hand_manifest
from player_review import texture_png


def generate_review(game, output, reports=None):
    cli = harness()
    from md3harness.quality import inspect
    game, output = Path(game), Path(output)
    model = game / "progs/bv_hands.md3"
    digest = hashlib.sha256(model.read_bytes()).hexdigest()
    report = None
    if reports and (Path(reports)/"hands.report.json").is_file():
        report = json.loads((Path(reports)/"hands.report.json").read_text())
    if not (report and report.get("sha256") == digest and all(
            hashlib.sha256((game/t["path"]).read_bytes()).hexdigest() == t["sha256"]
            for t in report.get("textures", {}).values())):
        report = inspect(model, game, dict(frames=402, triangle_budget=30000))
    if not report["passed"] or report["issues"]:
        raise ValueError("cannot review an invalid exported hand model")
    clip_file = game/"progs/bv_hands.animations.json"
    manifest = json.loads(clip_file.read_text()) if clip_file.is_file() else hand_manifest()
    if manifest["frames"] != report["frames"] or any(c["start"]+c["count"] > report["frames"] for c in manifest["clips"]):
        raise ValueError("hand manifest does not match exported frame ranges")
    manifest.update(sha256=digest, triangles=sum(s["triangles"] for s in report["surfaces"]))
    for clip in manifest["clips"]:
        if clip["name"] == "float_serve":
            clip["note"] = "Firm palm and straight push through the ball; relaxed fingers return after contact."
        elif clip["name"] == "cut":
            clip["note"] = "Forearm rotates, wrist turns sideways, and the arm follows across the body."
    textures = {"bv_hands": base64.b64encode(texture_png(game/"progs/bv_hands.tga")).decode()}
    page = (HERE/"resources/hand-review.html").read_text()
    page = page.replace("__MODEL__", base64.b64encode(gzip.compress(model.read_bytes(), mtime=0)).decode())
    page = page.replace("__MANIFEST__", json.dumps(manifest)).replace("__TEXTURES__", json.dumps(textures))
    output.mkdir(parents=True, exist_ok=True)
    (output/"hands.html").write_text(page)
    cli.save_json(output/"animations.json", manifest)
    print(f"Hand review: {(output/'hands.html').resolve()}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path, default=HERE/"dist/beachvolley")
    parser.add_argument("--output", type=Path, default=HERE/"build/hand-review")
    parser.add_argument("--reports", type=Path, default=HERE/"build/hand-quality")
    args = parser.parse_args()
    generate_review(args.game, args.output, args.reports)
