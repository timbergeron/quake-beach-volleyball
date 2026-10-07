#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Extract a clothed anatomical athlete from the pinned CC0 MakeHuman inputs."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import struct

from anatomy_mesh import weld_small_edges, refine_quads
from player_assets import add, sub


def clip_polygon(polygon, boundary):
    """Clip world/UV corners together; clothing edges cross source polygons."""
    result = []
    for before, after in zip(polygon, polygon[1:]+polygon[:1]):
        a, b = boundary(before), boundary(after)
        if a <= 0:
            result.append(before)
        if (a <= 0) != (b <= 0):
            t = a/(a-b)
            result.append(tuple(x+(y-x)*t for x, y in zip(before, after)))
    return result


def paint_kit(data, image, away=False):
    from PIL import ImageDraw
    atlas = image.copy()
    width, height = atlas.size
    draw = ImageDraw.Draw(atlas)
    font = {"N": ("1001", "1101", "1011", "1001", "1001"),
            "O": ("0110", "1001", "1001", "1001", "0110"),
            "R": ("1110", "1001", "1110", "1010", "1001"),
            "1": ("010", "110", "010", "010", "111")}
    marks = []
    for text, start_y, top, size in (("NOR", -3.1, 12.9, .45), ("1", -.65, 7.8, .85)):
        for letter, character in enumerate(text):
            for row, bits in enumerate(font[character]):
                for column, bit in enumerate(bits):
                    if bit == "1":
                        y, z = start_y+(letter*5+column)*size, top-row*size
                        marks.append((y, y+size*.88, z-size*.88, z, (234, 237, 235, 255)))
    for row in range(6):
        for column in range(9):
            color = (195, 37, 45, 255)
            if row in (2, 3) or column in (2, 3):
                color = (238, 240, 238, 255)
            if row == 3 or column == 3:
                color = (18, 33, 60, 255)
            y, z = -1.75+column*.39, 15.1-row*.35
            marks.append((y, y+.39, z-.35, z, color))
    def paint(polygon, boundaries, color):
        for boundary in boundaries:
            polygon = clip_polygon(polygon, boundary)
            if len(polygon) < 3:
                return
        draw.polygon([(round(p[3]*(width-1)), round(p[4]*(height-1))) for p in polygon], fill=color)
    for face in data["faces"]:
        polygon = [(*data["vertices"][c[0]], *c[1:]) for c in face]
        paint(polygon, (lambda p: .5-p[2], lambda p: abs(p[1])-6.2,
                       lambda p: p[2]-(15.6+3*min(abs(p[1])/2.9, 1)**2)),
              (136, 42, 46, 255) if away else (25, 52, 76, 255))
        paint(polygon, (lambda p: p[2]-1.2, lambda p: -7.5-p[2], lambda p: abs(p[1])-8),
              (39, 48, 60, 255))
        paint(polygon, (lambda p: 23.3-p[2], lambda p: p[0]-.5), (117, 96, 61, 255))
        if max(p[0] for p in polygon) > 1.5 and max(p[2] for p in polygon) > 3:
            for y0, y1, z0, z1, color in marks:
                paint(polygon, (lambda p: 1.5-p[0], lambda p: y0-p[1], lambda p: p[1]-y1,
                               lambda p: z0-p[2], lambda p: p[2]-z1), color)
    return atlas


def prepare(source, output):
    from PIL import Image
    vertices, uv, faces, group = [], [], [], ""
    for line in (source/"base.obj").read_text().splitlines():
        if line.startswith("v "):
            vertices.append(tuple(map(float, line.split()[1:])))
        elif line.startswith("vt "):
            uv.append(tuple(map(float, line.split()[1:])))
        elif line.startswith("g "):
            group = line[2:]
        elif line.startswith("f ") and group == "body":
            faces.append([tuple(int(i)-1 for i in item.split("/")[:2]) for item in line.split()[1:]])
    for line in (source/"male.target").read_text().splitlines():
        if line and not line.startswith("#"):
            index, *delta = line.split()
            vertices[int(index)] = add(vertices[int(index)], tuple(map(float, delta)))
    skeleton = json.loads((source/"default.mhskel").read_text())
    weights = defaultdict(dict)
    for name, entries in json.loads((source/"default_weights.mhw").read_text())["weights"].items():
        for index, weight in entries:
            weights[index][name] = weight
    def joint(name):
        ids = skeleton["joints"][name]
        return tuple(sum(vertices[i][a] for i in ids)/len(ids) for a in range(3))
    origin = joint(skeleton["bones"]["root"]["tail"])
    def canonical(point):
        x, y, z = sub(point, origin)
        return [round(z*3.5, 6), round(x*3.5, 6), round(y*3.5, 6)]
    ids = sorted({i for face in faces for i, t in face})
    remap = {old: new for new, old in enumerate(ids)}
    data = dict(schema="beachvolley.body-rig.v1", license="CC0-1.0",
        revision="a8bc2d54ff0ac92e78ff71431b1023eda42bf482",
        source_sha256={name: hashlib.sha256((source/name).read_bytes()).hexdigest()
            for name in ("base.obj", "male.target", "default.mhskel", "default_weights.mhw", "skin.png")},
        axes="X forward, Y left, Z up; pelvis origin; tall-athlete game scale",
        vertices=[canonical(vertices[i]) for i in ids], weights=[weights[i] for i in ids],
        bones={name: dict(head=canonical(joint(b["head"])), tail=canonical(joint(b["tail"])), parent=b["parent"])
               for name, b in skeleton["bones"].items()},
        faces=[[[remap[i], uv[t][0], 1-uv[t][1]] for i, t in face] for face in faces])
    weld_small_edges(data, distance=.10)
    # Spend extra samples on the face, shoulders and calf silhouettes. Fine nail
    # details stay at their welded resolution instead of being subdivided.
    refine_quads(data, lambda p: p[2] > 19 or 10 < p[2] < 19 and abs(p[1]) < 8 or -24 < p[2] < -20, min_edge=.22)
    image = Image.open(source/"skin.png").convert("RGBA")
    # Keep diffuse highlights from clipping in QSS-M's bright alias lighting.
    image = Image.merge("RGBA", tuple(c.point(lambda x: round(x*.88)) for c in image.split()[:3])+(image.getchannel("A"),))
    width, height = image.size
    output.mkdir(parents=True, exist_ok=True)
    for away in (False, True):
        atlas = paint_kit(data, image, away)
        filename = "bv_athlete_away.tga" if away else "bv_athlete.tga"
        header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)
        (output/filename).write_bytes(header+atlas.tobytes("raw", "BGRA"))
    (output/"body-rig.json").write_text(json.dumps(data, separators=(",", ":"))+"\n")
    (output/"LICENSE.CC0.txt").write_text((source/"LICENSE.ASSETS.md").read_text())
    print(f"Prepared clothed athlete: {len(data['vertices'])} vertices, {len(data['faces'])} polygons.")
    return data


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("build/hand-source"))
    parser.add_argument("--output", type=Path, default=Path("resources/anatomy"))
    args = parser.parse_args()
    prepare(args.source, args.output)
