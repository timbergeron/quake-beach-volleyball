#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Anatomical first-person hands, with authored volleyball-specific poses.

The trimmed bind mesh, UVs and joint weights are CC0 MakeHuman assets. This
skinning implementation and motion authoring are original. The shared 389-frame
contract lets body and view model animate together without changing ball physics.
"""
import argparse
from collections import Counter
from functools import lru_cache
import json
import math
from pathlib import Path
import shutil
import struct
import tempfile

from player_assets import (HERE, CLIPS, FRAME_COUNT, Vectors, add, sub, mul,
                          dot, cross, unit, mix, smooth, rotate, transform, harness)

IDENTITY = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
CUT_CLIP = next(c for c in CLIPS if c.name == "cut")
HAND_FRAME_COUNT = FRAME_COUNT + CUT_CLIP.count


def hand_manifest():
    from player_assets import animation_manifest
    manifest = animation_manifest()
    manifest["frames"] = HAND_FRAME_COUNT
    notes = dict(
        set_load="Hands rise near the forehead; spread fingers and opposed thumbs yield into a deep cradle.",
        set="Fingers extend through release, then wrists and hands return to the relaxed pose.",
        float_load="The guide palm lifts under the toss while the hitting hand draws back with relaxed fingers.",
        float_serve="A firm palm pushes straight through contact before a relaxed return.",
        cut="Forearm and wrist turn inward; the hitting arm follows across the body.")
    for clip in manifest["clips"]:
        if clip["name"] in notes:
            clip["note"] = notes[clip["name"]]
    manifest["clips"].append(dict(name="cut_away", start=FRAME_COUNT,
        count=CUT_CLIP.count, seconds=CUT_CLIP.seconds, loop=False, contact=0,
        note="Wrist-away cut: forearm turns outward and follows to the hitting side."))
    return manifest


def axis_rotation(axis, degrees):
    axis = unit(axis)
    c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
    return tuple(add(add(mul(v, c), mul(cross(axis, v), s)),
                     mul(axis, dot(axis, v)*(1-c))) for v in IDENTITY)


def compose(a, b):
    return tuple(transform(v, a, (0, 0, 0)) for v in b)


def align(a, b):
    a, b = unit(a), unit(b)
    axis, cosine = cross(a, b), max(-1, min(1, dot(a, b)))
    if dot(axis, axis) < 1e-10:
        return IDENTITY if cosine > 0 else axis_rotation((0, 1, 0), 180)
    return axis_rotation(axis, math.degrees(math.acos(cosine)))


def quaternion(rotation):
    m = tuple(tuple(rotation[c][r] for c in range(3)) for r in range(3))
    trace = sum(m[i][i] for i in range(3))
    if trace > 0:
        s = math.sqrt(trace+1)*2
        return (s/4, (m[2][1]-m[1][2])/s, (m[0][2]-m[2][0])/s, (m[1][0]-m[0][1])/s)
    i = max(range(3), key=lambda i: m[i][i])
    j, k = (i+1)%3, (i+2)%3
    s = math.sqrt(1+m[i][i]-m[j][j]-m[k][k])*2
    q = [0, 0, 0, 0]
    q[0], q[i+1] = (m[k][j]-m[j][k])/s, s/4
    q[j+1], q[k+1] = (m[j][i]+m[i][j])/s, (m[k][i]+m[i][k])/s
    return tuple(q)


def qmultiply(a, b):
    w, x, y, z = a
    v, i, j, k = b
    return (w*v-x*i-y*j-z*k, w*i+x*v+y*k-z*j,
            w*j-x*k+y*v+z*i, w*k+x*j-y*i+z*v)


def dual_skin(point, weights, duals):
    # Dual quaternions preserve joint volume when fingers close. Linear matrix
    # blending flattens the inner PIP/DIP crease and can collapse a nail edge.
    reference = duals[max(weights, key=weights.get)][0]
    q, d = [0.0]*4, [0.0]*4
    for name, weight in weights.items():
        real, dual = duals[name]
        if sum(a*b for a, b in zip(reference, real)) < 0:
            weight = -weight
        for i in range(4):
            q[i] += real[i]*weight
            d[i] += dual[i]*weight
    length = math.sqrt(sum(x*x for x in q))
    q, d = [x/length for x in q], [x/length for x in d]
    correction = sum(a*b for a, b in zip(q, d))
    d = [a-b*correction for a, b in zip(d, q)]
    u = tuple(q[1:])
    v = add(point, add(mul(cross(u, point), 2*q[0]), mul(cross(u, cross(u, point)), 2)))
    shift = qmultiply(d, (q[0], -q[1], -q[2], -q[3]))[1:]
    return add(v, mul(shift, 2))


@lru_cache(maxsize=1)
def rig(path=None):
    data = json.loads((Path(path) if path else HERE / "resources/hands/hand-rig.json").read_text())
    # OBJ uses seam vertices; preserve the seam's UV but share the geometry's
    # normal. Canonical faces are outward CCW on the left hand.
    corners, lookup, triangles, geometric = [], {}, [], []
    for face in data["faces"]:
        ids = []
        for corner in face:
            key = tuple(corner)
            if key not in lookup:
                lookup[key] = len(corners)
                corners.append(corner)
            ids.append(lookup[key])
        # Shortest diagonal is more stable on nail beds and thumb webbing.
        if len(face) == 4:
            p = [data["vertices"][c[0]] for c in face]
            d02, d13 = sub(p[0], p[2]), sub(p[1], p[3])
            local = [(0, 1, 2), (0, 2, 3)] if dot(d02, d02) <= dot(d13, d13) else [(0, 1, 3), (1, 2, 3)]
        else:
            local = [(0, i, i+1) for i in range(1, len(face)-1)]
        for a, b, c in local:
            original = [face[i][0] for i in (a, b, c)]
            if len(set(original)) < 3:
                continue
            p = [data["vertices"][i] for i in original]
            area = cross(sub(p[1], p[0]), sub(p[2], p[0]))
            if dot(area, area) < .000004:
                continue
            triangles.append((ids[a], ids[b], ids[c]))
            geometric.append((face[a][0], face[b][0], face[c][0]))
    # Thumb webbing needs its own corner normals at strong opposition. Keep
    # those corners separate in every pose instead of changing topology.
    flat = []
    for i, (triangle, original) in enumerate(zip(triangles, geometric)):
        crease = any(
            .02 < sum(w for n, w in data["weights"][v].items() if n.startswith(("finger1", "lowerarm"))) < .98
            or .02 < sum(w for n, w in data["weights"][v].items() if n.startswith("finger")) < .98
            or sum(w > .12 for n, w in data["weights"][v].items() if n.startswith("finger")) > 1
            for v in original)
        if crease:
            indices = []
            for index in triangle:
                indices.append(len(corners))
                corners.append(corners[index])
            triangles[i] = tuple(indices)
        flat.append(crease)
    data.update(corners=corners, triangles=triangles, geometric=geometric, flat=flat)
    # Continue the cropped forearm behind the camera. Leaving its irregular
    # source boundary exposed creates visible sawtooth ends on overhead shots.
    edge_counts = Counter(tuple(sorted((a, b))) for tri in geometric
                          for a, b in zip(tri, tri[1:]+tri[:1]))
    boundary = [(a, b) for tri in geometric for a, b in zip(tri, tri[1:]+tri[:1])
                if edge_counts[tuple(sorted((a, b)))] == 1
                and max(data["vertices"][i][0] for i in (a, b)) < -4.5]
    roots = sorted({i for edge in boundary for i in edge})
    following = dict(boundary)
    ordered = [roots[0]]
    while following[ordered[-1]] != ordered[0]:
        ordered.append(following[ordered[-1]])
    if len(ordered) != len(roots):
        raise ValueError("forearm boundary must be one closed loop")
    source_corners = {c[0]: i for i, c in enumerate(corners)}
    uv_rect = data["forearm_uv_rect"]
    def extension_uv(original, phase):
        u = data_order[original]/len(ordered)
        return [mix(uv_rect[0], uv_rect[2], u), mix(uv_rect[1], uv_rect[3], phase)]
    data_order = {v: i for i, v in enumerate(ordered)}
    extensions, row = [], {}
    for original in roots:
        row[original] = len(corners)
        corners.append([original, *extension_uv(original, 0)])
    rows = [row]
    vertex_count = len(data["vertices"])
    for layer in range(1, 5):
        row = {}
        for original in roots:
            index = vertex_count + len(extensions)
            extensions.append((layer/4, original))
            row[original] = len(corners)
            corners.append([index, *extension_uv(original, layer/4)])
        rows.append(row)
    for before, after in zip(rows, rows[1:]):
        for a, b in boundary:
            for triangle in ((before[b], before[a], after[a]), (before[b], after[a], after[b])):
                triangles.append(triangle)
                geometric.append(tuple(corners[i][0] for i in triangle))
                flat.append(True)
    roots_set = set(roots)
    for i, original in enumerate(geometric):
        if any(v in roots_set or v >= vertex_count for v in original):
            indices = []
            for corner in triangles[i]:
                indices.append(len(corners))
                corners.append(corners[corner])
            triangles[i] = tuple(indices)
            flat[i] = True
    data.update(extensions=extensions, extension_roots=roots, extension_order=data_order,
                extension_source_uv={i: corners[source_corners[i]][1:] for i in roots})
    return data


def motion(clip, t, side):
    """Camera-space wrist, finger direction, dorsal roll, three curl angles.

    Setting yields under the forehead, then extends through the ball. A float
    serve keeps the palm firm through contact. A cut has lateral wrist rotation
    rather than the float's straight push. Each returns to the same relaxed pose.
    """
    neutral = ((16, side*6.0, -10.5), (15, 0, -side*10), (10, 18, 10), 3, 8)
    # Parameters: wrist xyz, pitch/roll/yaw (X is forward), MCP/PIP/DIP
    # flexion in degrees, finger spread, and thumb opposition.
    load = ((16, side*4.8, 0.2), (-105, -side*23, -side*22), (18, 30, 18), 9, 22)
    dish = ((15.4, side*4.4, -.5), (-112, -side*26, -side*24), (23, 34, 20), 10, 27)
    release = ((21, side*5.4, 7), (-85, -side*12, -side*14), (3, 8, 4), 7, 12)
    bow = ((10, side*7, 4) if side < 0 else (19, side*6, 4),
           (-85, -side*10, -side*6), (5, 10, 5), 3, 8)
    strike = ((23, side*4.2, 9) if side < 0 else (18, side*8, -4),
              (-79, -side*3, 0) if side < 0 else (-20, 0, 10), (4, 7, 4), 2, 8)
    follow = ((25, 4, -5) if side < 0 else (16, side*8, -9),
              (12, 12, 28) if side < 0 else (15, 0, -10), (12, 18, 10), 2, 10)
    toss = ((18, 6, -4), (-10, 180, 15), (10, 18, 8), 7, 20)
    float_bow = ((12, -7, 4), (-87, 0, -6), (3, 6, 3), 1, 6)
    float_strike = ((23, -3.5, 8), (-92, 0, 0), (3, 6, 3), 1, 6)
    float_follow = ((27, -2.5, 4), (-82, 0, 1), (4, 7, 4), 1, 6)
    cut_strike = ((23, -1, 8), (-90, 32, 24), (9, 14, 8), 3, 12)
    cut_follow = ((24, 9, -1), (-8, 52, 47), (24, 32, 18), 2, 14)
    keys = [(0, neutral), (1, neutral)]
    if clip == "set_load":
        keys = [(0, neutral), (.65, load), (1, dish)]
    elif clip in ("set", "back_set", "jump_set"):
        keys = [(0, dish), (.33, release), (.62, release), (1, neutral)]
    elif clip == "float_load":
        keys = [(0, neutral), (.35, toss if side > 0 else float_bow),
                (.72, ((22, 6, 6), (-25, 155, 15), (4, 10, 4), 7, 12) if side > 0 else float_bow),
                (1, ((20, 7, 3), (-70, -15, -8), (7, 12, 6), 3, 8) if side > 0 else float_bow)]
    elif clip == "float_serve":
        keys = [(0, float_strike if side < 0 else ((20, 7, 3), (-70, -15, -8), (7, 12, 6), 3, 8)),
                (.28, float_follow if side < 0 else neutral), (.5, float_follow if side < 0 else neutral), (1, neutral)]
    elif clip in ("attack_load", "takeoff"):
        keys = [(0, neutral), (.65, bow), (1, bow)]
    elif clip == "approach":
        keys = [(0, neutral), (.7, ((4, side*9, -15), (20, 0, 0), (14, 20, 10), 2, 8)), (1, bow)]
    elif clip == "jump_serve":
        keys = [(0, neutral), (.2, toss if side > 0 else bow), (.55, neutral), (.8, bow), (1, strike)]
    elif clip in ("cut", "cut_away"):
        if clip == "cut_away":
            cut_strike = ((23, -7, 8), (-90, -32, -24), (9, 14, 8), 3, 12)
            cut_follow = ((24, -13, -1), (-8, -42, -35), (24, 32, 18), 2, 14)
        keys = [(0, cut_strike if side < 0 else strike), (.32, cut_follow if side < 0 else neutral), (.64, cut_follow if side < 0 else neutral), (1, neutral)]
    elif clip in ("spike", "roll"):
        keys = [(0, strike), (.32, follow), (.64, follow), (1, neutral)]
    elif clip.startswith("block"):
        block = ((21, side*7, 8), (-72, -side*5, 0), (0, 4, 2), 10, 10)
        keys = [(0, neutral), (.35, block), (.7, block), (1, block if clip == "block_load" else neutral)]
    elif clip in ("pass_load", "pass", "peel", "dive", "pancake", "poke"):
        platform = ((22, side*2.0, -8), (3, -side*65, -side*8), (30, 40, 25), 0, 35)
        if clip == "poke":
            platform = ((22, side*4, 7), (-78, 0, 0), (30, 40, 25), 0, 32)
        keys = [(0, neutral if clip in ("pass_load", "peel") else platform), (1, neutral if clip in ("pass", "poke") else platform)]
    elif clip in ("run", "shuffle_l", "shuffle_r", "backpedal"):
        amplitude = math.sin(t*math.tau)*1.1
        return (add(neutral[0], (0, 0, side*amplitude)), *neutral[1:])
    for (ta, a), (tb, b) in zip(keys, keys[1:]):
        if t <= tb:
            u = smooth((t-ta)/(tb-ta))
            return tuple(mix(x, y, u) for x, y in zip(a, b))
    return keys[-1][1]


def hand_pose(clip, t, side):
    return skin_pose(motion(clip, t, side), side)


@lru_cache(maxsize=256)
def skin_pose(parameters, side):
    data = rig()
    wrist, angles, curls, spread, opposition = parameters
    axes = tuple(rotate(a, angles) for a in IDENTITY)
    # Source is the left hand (thumb toward +Y); its medial direction is -Y.
    # Reflection makes a right hand with the correct thumb and UVs.
    axes = (axes[0], mul(axes[1], -side), axes[2])
    transforms = {}
    def bone_transform(name):
        if name in transforms:
            return transforms[name]
        bone = data["bones"][name]
        parent = bone["parent"]
        parent_r, parent_t = bone_transform(parent) if parent in data["bones"] and not name.startswith("lowerarm") and name != "wrist" else (IDENTITY, (0, 0, 0))
        local = IDENTITY
        if name.startswith("finger"):
            finger, joint = map(int, name[6:].split("-"))
            bend_axis = unit(cross(sub(bone["tail"], bone["head"]), (0, 0, -1)))
            if finger == 1:
                local = compose(axis_rotation((1, 0, 0), -opposition*.45 if joint == 1 else 0),
                                axis_rotation(bend_axis, curls[joint-1]*.32))
            else:
                local = compose(axis_rotation((0, 0, 1), spread*(3.5-finger) if joint == 1 else 0),
                                axis_rotation(bend_axis, curls[joint-1]))
        rotation = compose(parent_r, local)
        head = bone["head"]
        translation = sub(transform(head, parent_r, parent_t), transform(head, rotation, (0, 0, 0)))
        transforms[name] = (rotation, translation)
        return transforms[name]
    for name in data["bones"]:
        bone_transform(name)
    # Elbows stay below and outside the camera. Skinning the two forearm bones
    # to this axis keeps the imported wrist continuous when the palm rotates.
    elbow = (4, side*12, -15)
    bind_elbow = data["bones"]["lowerarm01"]["head"]
    desired_elbow = tuple(dot(sub(elbow, wrist), axis) for axis in axes)
    forearm_rotation = align(bind_elbow, desired_elbow)
    for name in ("lowerarm01", "lowerarm02"):
        transforms[name] = (forearm_rotation, (0, 0, 0))
    duals = {}
    for name, (rotation, translation) in transforms.items():
        real = quaternion(rotation)
        duals[name] = (real, tuple(x*.5 for x in qmultiply((0, *translation), real)))
    positions = []
    for p, weights in zip(data["vertices"], data["weights"]):
        result = dual_skin(p, weights, duals)
        positions.append(transform(result, axes, wrist))
    center = tuple(sum(positions[i][k] for i in data["extension_roots"])/len(data["extension_roots"]) for k in range(3))
    forearm_direction = unit(sub(center, wrist))
    # Continue along the anatomical forearm axis. Bending this cropped ring
    # toward a fixed offscreen endpoint made a false elbow with sharp folds.
    # A straight continuation hides the cut below/behind the camera without
    # introducing a visible joint or flattening the cross-section.
    end = add(center, mul(forearm_direction, 35))
    first = data["extension_roots"][0]
    u = sub(positions[first], center)
    u = unit(sub(u, mul(forearm_direction, dot(u, forearm_direction))))
    area = (0, 0, 0)
    ordered = sorted(data["extension_roots"], key=data["extension_order"].get)
    for a, b in zip(ordered, ordered[1:]+ordered[:1]):
        area = add(area, cross(sub(positions[a], center), sub(positions[b], center)))
    v = mul(cross(forearm_direction, u), 1 if dot(area, forearm_direction) > 0 else -1)
    radii = []
    for original in ordered:
        raw = sub(positions[original], center)
        radial = sub(raw, mul(forearm_direction, dot(raw, forearm_direction)))
        radii.append(math.sqrt(dot(radial, radial)))
    radius = sum(radii)/len(radii)
    for phase, original in data["extensions"]:
        raw = sub(positions[original], center)
        axial = dot(raw, forearm_direction)
        radial = sub(raw, mul(forearm_direction, axial))
        index = data["extension_order"][original]
        target_theta = math.tau*(index+.5)/len(ordered)
        theta = math.atan2(dot(radial, v), dot(radial, u))
        theta += math.tau*round((target_theta-theta)/math.tau)
        theta = mix(theta, target_theta, phase)
        length = mix(math.sqrt(dot(radial, radial)), radius*1.25, phase)
        radial = add(mul(u, math.cos(theta)*length), mul(v, math.sin(theta)*length))
        offset = add(radial, mul(forearm_direction, axial*(1-phase)))
        positions.append(add(mix(center, end, phase), offset))
    normals = [(0, 0, 0) for _ in positions]
    for a, b, c in data["geometric"]:
        face = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
        if side > 0:
            face = mul(face, -1)
        for index in (a, b, c):
            normals[index] = add(normals[index], face)
    normals = list(map(unit, normals))
    corner_positions = [positions[c[0]] for c in data["corners"]]
    corner_normals = [normals[c[0]] for c in data["corners"]]
    harness()
    from md3harness.format import normal_bytes, decode_normal
    quantized = [tuple(round(x*64)/64 for x in p) for p in Vectors(corner_positions)]
    for (a, b, c), flat in zip(data["triangles"], data["flat"]):
        if flat:
            face = unit(cross(sub(corner_positions[b], corner_positions[a]), sub(corner_positions[c], corner_positions[a])))
            if side > 0:
                face = mul(face, -1)
            for i in (a, b, c):
                # Smooth where the average agrees with the face; use a crease
                # normal only on the tight inner thumb fold.
                if dot(corner_normals[i], face) < .3:
                    corner_normals[i] = face
            # A narrow crease can change its face direction when positions and
            # normals land on MD3's two grids. Correct only disagreeing crease
            # corners against their exact exported representation.
            qface = cross(sub(quantized[b], quantized[a]), sub(quantized[c], quantized[a]))
            if side > 0:
                qface = mul(qface, -1)
            average = add(add(corner_normals[a], corner_normals[b]), corner_normals[c])
            if dot(qface, average) > .2*math.sqrt(dot(qface, qface)*dot(average, average)):
                continue
            packed = [decode_normal(*normal_bytes(n)) for n in Vectors([corner_normals[i] for i in (a, b, c)])]
            average = add(add(packed[0], packed[1]), packed[2])
            if dot(qface, average) < -.05*math.sqrt(dot(qface, qface)*dot(average, average)):
                for i in (a, b, c):
                    corner_normals[i] = unit(qface)
    return Vectors(corner_positions), Vectors(corner_normals), wrist


def scene(frame_range=None):
    data = rig()
    result = dict(schema="md3harness.scene.v1", name="bv_hands.md3", winding="ccw", frames=[], surfaces=[], tags=[])
    # Reflection reverses winding. Canonical MakeHuman faces point outward;
    # both hands must also point outward after their camera-space reflection.
    for side, name in ((1, "left_hand"), (-1, "right_hand")):
        triangles = [(a, c, b) if side > 0 else (a, b, c) for a, b, c in data["triangles"]]
        result["surfaces"].append(dict(name=name, shader="progs/bv_hands",
            uv=[c[1:] for c in data["corners"]], triangles=triangles, poses=[]))
    for clip in hand_manifest()["clips"]:
        name = clip["name"]
        if frame_range and not any(clip["start"] <= f < clip["start"]+clip["count"] for f in frame_range):
            continue
        print(f"Sampling hand clip: {name}", flush=True)
        for frame in range(clip["count"]):
            if frame_range and clip["start"]+frame not in frame_range:
                continue
            t = frame/(clip["count"] if clip["loop"] else clip["count"]-1)
            tags = []
            for surface, side in zip(result["surfaces"], (1, -1)):
                positions, normals, wrist = hand_pose(name, t, side)
                surface["poses"].append(dict(positions=positions, normals=normals))
                tags.append(dict(name="tag_left" if side > 0 else "tag_right", origin=wrist, axes=IDENTITY))
            result["frames"].append(f"{name[:10]}{frame:03d}")
            result["tags"].append(tags)
    return result


def combine_batches(paths, output):
    """Join fixed-topology exported pose batches without re-encoding vertices.

    Each input passed the harness. The complete output is checked again before
    delivery; frame bounds, tags and every surface's packed poses are retained.
    """
    header = struct.Struct("<4si64s9i")
    surface_header = struct.Struct("<4s64s10i")
    blobs = [Path(p).read_bytes() for p in paths]
    heads = [header.unpack_from(b) for b in blobs]
    if any(h[5:8] != heads[0][5:8] for h in heads):
        raise ValueError("hand batch tag/surface counts differ")
    frames = b"".join(b[h[8]:h[9]] for b, h in zip(blobs, heads))
    tags = b"".join(b[h[9]:h[10]] for b, h in zip(blobs, heads))
    offsets = [h[10] for h in heads]
    surfaces = []
    for _ in range(heads[0][6]):
        sh = [surface_header.unpack_from(b, off) for b, off in zip(blobs, offsets)]
        prefixes = [b[off+108:off+s[10]] for b, off, s in zip(blobs, offsets, sh)]
        if any(s[4:11] != sh[0][4:11] for s in sh) or any(p != prefixes[0] for p in prefixes):
            raise ValueError("hand batch topology/materials differ")
        poses = b"".join(b[off+s[10]:off+s[11]] for b, off, s in zip(blobs, offsets, sh))
        final = list(sh[0])
        final[3] = sum(h[4] for h in heads)
        final[11] = final[10]+len(poses)
        surfaces.append(surface_header.pack(*final)+prefixes[0]+poses)
        offsets = [off+s[11] for off, s in zip(offsets, sh)]
    final = list(heads[0])
    final[4] = sum(h[4] for h in heads)
    final[8] = header.size
    final[9] = final[8]+len(frames)
    final[10] = final[9]+len(tags)
    final[11] = final[10]+sum(map(len, surfaces))
    Path(output).write_bytes(header.pack(*final)+frames+tags+b"".join(surfaces))


def expand_frames(source, output, indices, names):
    """Repeat validated packed poses while preserving full animation labels."""
    from md3harness.format import HEADER, SURFACE, FRAME, TAG, VERTEX, string, loads
    data = Path(source).read_bytes()
    head = list(HEADER.unpack_from(data))
    frames = b"".join(data[head[8]+i*FRAME.size:head[8]+i*FRAME.size+40]+string(name, 16)
                      for i, name in zip(indices, names))
    tag_size = head[5]*TAG.size
    tags = b"".join(data[head[9]+i*tag_size:head[9]+(i+1)*tag_size] for i in indices)
    offset, surfaces = head[10], []
    for _ in range(head[6]):
        sh = list(SURFACE.unpack_from(data, offset))
        stride = sh[5]*VERTEX.size
        prefix = data[offset+108:offset+sh[10]]
        poses = b"".join(data[offset+sh[10]+i*stride:offset+sh[10]+(i+1)*stride] for i in indices)
        old_end = sh[11]
        sh[3], sh[11] = len(indices), sh[10]+len(poses)
        surfaces.append(SURFACE.pack(*sh)+prefix+poses)
        offset += old_end
    head[4], head[8] = len(indices), HEADER.size
    head[9] = head[8]+len(frames)
    head[10] = head[9]+len(tags)
    head[11] = head[10]+sum(map(len, surfaces))
    result = HEADER.pack(*head)+frames+tags+b"".join(surfaces)
    loads(result)  # Check all expanded header, tag, index and packed data ranges.
    Path(output).write_bytes(result)


def export_batch(game, index):
    cli = harness()
    progs = Path(game)/"progs"
    progs.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(HERE/"resources/hands/bv_hands.tga", progs/"bv_hands.tga")
    start, end = index*80, min(HAND_FRAME_COUNT, (index+1)*80)
    if start >= end:
        raise ValueError("invalid hand batch")
    full = scene(range(start, end))
    unique, mapping, seen = [], [], {}
    for frame in range(len(full["frames"])):
        # Cached immutable pose arrays identify exact duplicate geometry. No
        # rounding or approximate pose matching changes an authored frame.
        key = tuple(id(s["poses"][frame][field]) for s in full["surfaces"] for field in ("positions", "normals"))
        if key not in seen:
            seen[key] = len(unique)
            unique.append(frame)
        mapping.append(seen[key])
    compact = dict(full, frames=[full["frames"][i] for i in unique], tags=[full["tags"][i] for i in unique],
        surfaces=[dict(s, poses=[s["poses"][i] for i in unique]) for s in full["surfaces"]])
    temporary = progs/f"hand-unique-{index}.md3"
    cli.export_scene(compact, temporary, game, dict(frames=len(unique), triangle_budget=8000), strict=True)
    expand_frames(temporary, progs/f"hand-batch-{index}.md3", mapping, full["frames"])
    print(f"Hand batch {index}: strict PASS ({start}..{end-1})", flush=True)


def assemble(game, reports=None):
    cli = harness()
    from md3harness.quality import inspect
    progs = Path(game)/"progs"
    path = progs/"bv_hands.md3"
    temporary = progs/"bv_hands.candidate.md3"
    combine_batches([progs/f"hand-batch-{i}.md3" for i in range((HAND_FRAME_COUNT+79)//80)], temporary)
    report = inspect(temporary, game, dict(frames=HAND_FRAME_COUNT, triangle_budget=8000))
    if not report["passed"] or report["issues"]:
        raise ValueError(f"assembled hands rejected: {report['issues']}")
    temporary.replace(path)
    report["model"] = path.name
    cli.save_json(progs/"bv_hands.animations.json", hand_manifest())
    if reports:
        cli.save_json(Path(reports)/"hands.report.json", report)
    print(f"Complete hand model: strict PASS ({HAND_FRAME_COUNT} poses)", flush=True)
    return report


def generate_hands(game, reports=None):
    game = Path(game)
    (game / "progs").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(HERE / "resources/hands/bv_hands.tga", game / "progs/bv_hands.tga")
    with tempfile.TemporaryDirectory(prefix="hand-batches-", dir=game) as directory:
        for index in range((HAND_FRAME_COUNT+79)//80):
            export_batch(directory, index)
        report = assemble(directory, reports)
        for name in ("bv_hands.md3", "bv_hands.animations.json"):
            shutil.copyfile(Path(directory)/"progs"/name, game/"progs"/name)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=HERE / "build/hand-candidate")
    parser.add_argument("--reports", type=Path, default=HERE / "build/hand-quality")
    parser.add_argument("--batch", type=int, help="Export one batch into an isolated candidate")
    parser.add_argument("--assemble", action="store_true", help="Join and strictly inspect an exported candidate")
    args = parser.parse_args()
    if args.batch is not None:
        export_batch(args.output, args.batch)
    elif args.assemble:
        assemble(args.output, args.reports)
    else:
        generate_hands(args.output, args.reports)
