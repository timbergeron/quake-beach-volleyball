#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Extract the CC0 anatomical hand data; Pillow is only needed for this step.

Inputs are the pinned MakeHuman base OBJ, default skeleton/weights, young male
target, and the system asset pack's young_lightskinned_male_diffuse.png.
The normal game build consumes the checked-in extraction without dependencies.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import struct

from player_assets import add, sub, mul, dot, cross, unit, smooth


def prepare(source, output):
    from PIL import Image
    vertices, uvs, faces, group = [], [], [], ""
    for line in (source / "base.obj").read_text().splitlines():
        if line.startswith("v "):
            vertices.append(tuple(map(float, line.split()[1:])))
        elif line.startswith("vt "):
            uvs.append(tuple(map(float, line.split()[1:])))
        elif line.startswith("g "):
            group = line[2:]
        elif line.startswith("f ") and group == "body":
            faces.append([tuple(int(i)-1 for i in item.split("/")[:2]) for item in line.split()[1:]])
    for line in (source / "male.target").read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        index, *delta = line.split()
        vertices[int(index)] = add(vertices[int(index)], tuple(map(float, delta)))
    skeleton = json.loads((source / "default.mhskel").read_text())
    weights = defaultdict(dict)
    for bone, entries in json.loads((source / "default_weights.mhw").read_text())["weights"].items():
        for index, weight in entries:
            weights[index][bone] = weight
    def joint(name):
        ids = skeleton["joints"][name]
        return tuple(sum(vertices[i][k] for i in ids)/len(ids) for k in range(3))
    wrist = joint("wrist.L____head")
    longitudinal = unit(sub(joint("finger3-3.L____tail"), wrist))
    lateral = sub(joint("finger2-1.L____head"), joint("finger5-1.L____head"))
    lateral = unit(sub(lateral, mul(longitudinal, dot(lateral, longitudinal))))
    # On a left hand, fingers × medial thumb points toward the palm. Use its
    # opposite for dorsal +Z; reflect face order with this handed basis.
    normal = mul(cross(longitudinal, lateral), -1)
    # MakeHuman units are decimetres; 32 game units per metre.
    def canonical(p):
        d = sub(p, wrist)
        return [round(dot(d, axis)*3.2, 6) for axis in (longitudinal, lateral, normal)]
    chosen = [f for f in faces if all(vertices[i][0] > 3.3 for i, t in f)]
    ids = sorted({i for f in chosen for i, t in f})
    indices = {old: new for new, old in enumerate(ids)}
    bones = {}
    for name, bone in skeleton["bones"].items():
        if name.endswith(".L") and name.startswith(("wrist", "metacarpal", "finger", "lowerarm")):
            bones[name[:-2]] = dict(head=canonical(joint(bone["head"])),
                tail=canonical(joint(bone["tail"])), parent=(bone["parent"] or "")[:-2])
    selected_uvs = sorted({t for f in chosen for i, t in f})
    # Crop the arm/hand islands with a generous gutter. No full-body texture is
    # shipped. Retain original texel density instead of rescaling photographs.
    image = Image.open(source / "skin.png").convert("RGBA")
    width, height = image.size
    x0 = max(0, int(min(uvs[t][0] for t in selected_uvs)*width)-16)
    x1 = min(width, int(max(uvs[t][0] for t in selected_uvs)*width)+17)
    y0 = max(0, int((1-max(uvs[t][1] for t in selected_uvs))*height)-16)
    y1 = min(height, int((1-min(uvs[t][1] for t in selected_uvs))*height)+17)
    crop = image.crop((x0, y0, x1, y1))
    # Power-of-two atlas for Quake's mipmapped alias-model texture loader.
    atlas_width = 1 << (crop.width-1).bit_length()
    atlas_height = 1 << (crop.height-1).bit_length()
    atlas = Image.new("RGBA", (atlas_width, atlas_height), crop.getpixel((0, 0)))
    atlas.paste(crop, (0, 0))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, atlas_width, atlas_height, 32, 0x28)
    (output / "bv_hands.tga").write_bytes(header + atlas.tobytes("raw", "BGRA"))
    uvmap = {t: [(uvs[t][0]*width-x0)/atlas_width,
                  ((1-uvs[t][1])*height-y0)/atlas_height] for t in selected_uvs}
    data = dict(schema="beachvolley.hand-rig.v1", license="CC0-1.0",
        source="https://github.com/makehumancommunity/makehuman",
        revision="a8bc2d54ff0ac92e78ff71431b1023eda42bf482",
        source_sha256={n: hashlib.sha256((source/n).read_bytes()).hexdigest()
                       for n in ("base.obj", "male.target", "default.mhskel", "default_weights.mhw", "skin.png")},
        axes="X fingers, Y toward thumb, Z dorsum; wrist origin; game units",
        vertices=[canonical(vertices[i]) for i in ids], bones=bones,
        weights=[{n[:-2]: weight for n, weight in weights[i].items() if n[:-2] in bones} for i in ids],
        faces=[[[indices[i], *[round(u, 8) for u in uvmap[t]]] for i, t in reversed(f)] for f in chosen])
    # Slice the proximal forearm at a plane instead of retaining the jagged
    # boundary made by whole-face selection. Its smooth ring can continue out
    # of the camera without creating a false elbow or a twisted attachment.
    plane, intersections, clipped = -5.8, {}, []
    def intersection(a, b):
        pa, pb = data["vertices"][a[0]], data["vertices"][b[0]]
        t = (plane-pa[0])/(pb[0]-pa[0])
        edge = tuple(sorted((a[0], b[0])))
        if edge not in intersections:
            intersections[edge] = len(data["vertices"])
            data["vertices"].append([plane, *[pa[k]+(pb[k]-pa[k])*t for k in (1, 2)]])
            wa, wb = data["weights"][a[0]], data["weights"][b[0]]
            data["weights"].append({name: wa.get(name, 0)*(1-t)+wb.get(name, 0)*t
                                    for name in sorted(wa.keys() | wb.keys())})
        return [intersections[edge], *[a[k]+(b[k]-a[k])*t for k in (1, 2)]]
    for face in data["faces"]:
        polygon, previous = [], face[-1]
        for current in face:
            inside = data["vertices"][current[0]][0] >= plane
            was_inside = data["vertices"][previous[0]][0] >= plane
            if inside != was_inside:
                polygon.append(intersection(previous, current))
            if inside:
                polygon.append(current)
            previous = current
        if len(polygon) >= 3:
            clipped.append(polygon)
    data["faces"], data["forearm_clip_x"] = clipped, plane
    # The base mesh has millimetre-scale nail bevels. Weld short edges before
    # skinning so rotating them cannot collapse a triangle on MD3's 1/64 grid.
    parent = list(range(len(data["vertices"])))
    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for face in data["faces"]:
        for a, b in zip(face, face[1:]+face[:1]):
            delta = sub(data["vertices"][a[0]], data["vertices"][b[0]])
            if dot(delta, delta) < .055**2:
                parent[root(b[0])] = root(a[0])
    groups = defaultdict(list)
    for i in range(len(data["vertices"])):
        groups[root(i)].append(i)
    for members in groups.values():
        position = [sum(data["vertices"][i][k] for i in members)/len(members) for k in range(3)]
        weights = defaultdict(float)
        for i in members:
            for bone, weight in data["weights"][i].items():
                weights[bone] += weight/len(members)
        for i in members:
            data["vertices"][i] = position
            data["weights"][i] = dict(weights)
    for face in data["faces"]:
        for corner in face:
            corner[0] = root(corner[0])
    data["md3_weld_distance"] = .055
    # Reserve the atlas's unused lower gutter for an unwrapped forearm strip.
    # Repeating a single boundary texel along a metre of arm makes wood-like
    # streaks. Sample nearby real skin along its original UV direction instead.
    strip_top, strip_height, strip_width = atlas_height-228, 224, atlas_width-8
    if max(c[2] for f in data["faces"] for c in f)*atlas_height >= strip_top-16:
        raise ValueError("skin atlas needs room for the forearm strip")
    data["forearm_uv_rect"] = [4.5/atlas_width, (strip_top+.5)/atlas_height,
                               (atlas_width-4.5)/atlas_width, (strip_top+strip_height-.5)/atlas_height]
    (output / "hand-rig.json").write_text(json.dumps(data, separators=(",", ":"))+"\n")
    from hand_assets import rig
    rig.cache_clear()
    extracted = rig(output/"hand-rig.json")
    ordered = sorted(extracted["extension_roots"], key=extracted["extension_order"].get)
    center_uv = [sum(extracted["extension_source_uv"][i][k] for i in ordered)/len(ordered) for k in (0, 1)]
    def sample(u, v):
        px, py = u*atlas_width-.5, v*atlas_height-.5
        ix, iy = int(px), int(py)
        fx, fy = px-ix, py-iy
        pixels = [atlas.getpixel((min(atlas_width-1, max(0, ix+dx)), min(atlas_height-1, max(0, iy+dy))))
                  for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1))]
        return tuple(round((pixels[0][k]*(1-fx)+pixels[1][k]*fx)*(1-fy)
                           +(pixels[2][k]*(1-fx)+pixels[3][k]*fx)*fy) for k in range(4))
    strip = Image.new("RGBA", (strip_width, strip_height))
    for x in range(strip_width):
        position = x/(strip_width-1)*len(ordered)
        index, phase = int(position)%len(ordered), position%1
        a, b = [extracted["extension_source_uv"][ordered[i%len(ordered)]] for i in (index, index+1)]
        u, v = [a[k]+(b[k]-a[k])*phase for k in (0, 1)]
        for y in range(strip_height):
            depth = y/(strip_height-1)
            edge = sample(u, v+.06*depth)
            interior = sample(center_uv[0]+.09*(x/(strip_width-1)-.5), center_uv[1]+.06*depth)
            blend = smooth(min(1, depth*4))
            strip.putpixel((x, y), tuple(round(a+(b-a)*blend) for a, b in zip(edge, interior)))
    atlas.paste(strip, (4, strip_top))
    for x in range(4):
        atlas.paste(strip.crop((0, 0, 1, strip_height)), (x, strip_top))
        atlas.paste(strip.crop((strip_width-1, 0, strip_width, strip_height)), (atlas_width-4+x, strip_top))
    for y in range(4):
        atlas.paste(atlas.crop((0, strip_top, atlas_width, strip_top+1)), (0, strip_top-1-y))
        atlas.paste(atlas.crop((0, strip_top+strip_height-1, atlas_width, strip_top+strip_height)), (0, strip_top+strip_height+y))
    (output / "bv_hands.tga").write_bytes(header+atlas.tobytes("raw", "BGRA"))
    (output / "LICENSE.CC0.txt").write_bytes((source / "LICENSE.ASSETS.md").read_bytes())
    print(f"Hand extraction: {len(data['vertices'])} source vertices, {len(clipped)} faces; atlas {atlas.size}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("build/hand-source"))
    parser.add_argument("--output", type=Path, default=Path("resources/hands"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    prepare(args.source, args.output)
