# SPDX-License-Identifier: GPL-2.0-or-later
"""Continuous anatomical athlete driven by the game's authored volleyball rig."""
from functools import lru_cache
import json
import hashlib
from pathlib import Path
import shutil
import tempfile

import player_assets as player
from player_assets import add, sub, mul, dot, cross, unit, rotate, transform, mix
from hand_assets import IDENTITY, align, compose, axis_rotation, quaternion, qmultiply, dual_skin
from anatomy_mesh import triangulate


@lru_cache(maxsize=1)
def rig(use_plan=True):
    source = player.HERE/"resources/anatomy/body-rig.json"
    if not source.is_file():
        source = player.HERE/"build/anatomical-source/body-rig.json"
    data = triangulate(json.loads(source.read_text()))
    data["source_path"] = str(source)
    data["flat_faces"] = set()
    data["checked_poses"] = set()
    plan = source.with_name("crease-plan.json")
    if use_plan and plan.is_file():
        saved = json.loads(plan.read_text())
        if saved["source_sha256"] != hashlib.sha256(source.read_bytes()).hexdigest() or saved.get("topology_revision") != 2:
            raise ValueError("athlete crease plan does not match its source rig")
        apply_creases(data, saved["faces"])
    return data


def apply_creases(data, faces):
    for index in sorted(set(faces)-data["flat_faces"]):
        split = []
        for corner in data["triangles"][index]:
            split.append(len(data["corners"]))
            data["corners"].append(data["corners"][corner])
        data["triangles"][index] = tuple(split)
    data["flat_faces"].update(faces)


def transforms(state, data):
    axes = tuple(rotate(a, state["torso"]) for a in IDENTITY)
    hip = add(state["hip"], (0, 0, 8*(1-player.smooth((state["torso"][0]-40)/25))))
    world = lambda p: transform(p, axes, hip)
    bones = data["bones"]
    result = {name: (axes, hip) for name in bones}
    wrists = []
    def segment(names, start, end, target_start, target_end):
        direction = sub(end, start)
        rotation = align(direction, sub(target_end, target_start))
        for name in names:
            head = bones[name]["head"]
            fraction = dot(sub(head, start), direction)/dot(direction, direction)
            destination = mix(target_start, target_end, fraction)
            result[name] = (rotation, sub(destination, transform(head, rotation, (0, 0, 0))))
    for side, suffix, key in ((1, ".L", "left"), (-1, ".R", "right")):
        bind_shoulder = bones["upperarm01"+suffix]["head"]
        shoulder = world(bind_shoulder)
        elbow, wrist = player.ik(shoulder, state[key], (10.6, 10.2), state["lp" if side > 0 else "rp"])
        bind_elbow = bones["lowerarm01"+suffix]["head"]
        bind_wrist = bones["wrist"+suffix]["head"]
        segment(["clavicle"+suffix, "shoulder01"+suffix], bones["clavicle"+suffix]["head"], bind_shoulder,
                world(bones["clavicle"+suffix]["head"]), shoulder)
        segment(["upperarm01"+suffix, "upperarm02"+suffix], bind_shoulder, bind_elbow, shoulder, elbow)
        segment(["lowerarm01"+suffix, "lowerarm02"+suffix], bind_elbow, bind_wrist, elbow, wrist)
        longitudinal = unit(sub(bones["finger3-3"+suffix]["tail"], bind_wrist))
        lateral = sub(bones["finger2-1"+suffix]["head"], bones["finger5-1"+suffix]["head"])
        lateral = unit(sub(lateral, mul(longitudinal, dot(lateral, longitudinal))))
        dorsal = mul(cross(longitudinal, lateral), -side)
        bind_axes = (longitudinal, lateral, dorsal)
        pitch, roll, yaw = state["hands"]
        desired = tuple(rotate(a, (pitch, side*roll, side*yaw)) for a in IDENTITY)
        desired = (desired[0], mul(desired[1], -side), desired[2])
        rotation = tuple(transform(tuple(dot(a, axis) for axis in bind_axes), desired, (0, 0, 0)) for a in IDENTITY)
        result["wrist"+suffix] = (rotation, sub(wrist, transform(bind_wrist, rotation, (0, 0, 0))))
        def finger(name):
            if name in result and not name.startswith(("finger", "metacarpal")):
                return result[name]
            bone = bones[name]
            parent_r, parent_t = finger(bone["parent"])
            local = IDENTITY
            if name.startswith("finger"):
                number, joint = map(int, name.split(".")[0][6:].split("-"))
                curl = min(state["fingers"], .62)*(48, 65, 40)[joint-1]
                bend = unit(cross(sub(bone["tail"], bone["head"]), mul(dorsal, -1)))
                local = axis_rotation(bend, curl*(.35 if number == 1 else 1))
                if number == 1 and joint == 1:
                    local = compose(axis_rotation(longitudinal, -side*state["fingers"]*18), local)
            r = compose(parent_r, local)
            head = bone["head"]
            t = sub(transform(head, parent_r, parent_t), transform(head, r, (0, 0, 0)))
            result[name] = (r, t)
            return result[name]
        for name in bones:
            if name.endswith(suffix) and name.startswith(("finger", "metacarpal")):
                finger(name)
        root = add(hip, (0, side*3.5, -2))
        knee, ankle = player.ik(root, state["lf" if side > 0 else "rf"], (15.4, 14.6), (1, 0, 0))
        ankle = add(ankle, (0, 0, 1.03))
        bind_hip = bones["upperleg01"+suffix]["head"]
        bind_knee = bones["lowerleg01"+suffix]["head"]
        bind_ankle = bones["foot"+suffix]["head"]
        segment(["pelvis"+suffix], bones["pelvis"+suffix]["head"], bind_hip, hip, root)
        segment(["upperleg01"+suffix, "upperleg02"+suffix], bind_hip, bind_knee, root, knee)
        segment(["lowerleg01"+suffix, "lowerleg02"+suffix], bind_knee, bind_ankle, knee, ankle)
        foot_r = tuple(rotate(a, (state["feet"][0 if side > 0 else 1], 0, -side*8)) for a in IDENTITY)
        foot_t = sub(ankle, transform(bind_ankle, foot_r, (0, 0, 0)))
        for name in bones:
            if name.endswith(suffix) and name.startswith(("foot", "toe")):
                result[name] = (foot_r, foot_t)
        wrists.append(wrist)
    head = bones["head"]
    bind_center = mix(head["head"], head["tail"], .5)
    angles = tuple(a+b for a, b in zip(state["torso"], state["head"]))
    head_axes = tuple(rotate(a, angles) for a in IDENTITY)
    head_center = world((bind_center[0], 0, 27))
    head_t = sub(head_center, transform(bind_center, head_axes, (0, 0, 0)))
    for name in bones:
        if name.startswith(("head", "jaw", "eye", "special", "levator", "oculi", "orbicularis", "oris", "risorius", "temporalis", "tongue")):
            result[name] = (head_axes, head_t)
    for name in ("neck01", "neck02", "neck03"):
        # Neck weights interpolate torso and head motion without a separate
        # sphere collar or disconnected jaw geometry.
        result[name] = (head_axes, head_t)
    return result, wrists, axes, hip, head_axes, head_center


def raw_pose(state, data=None):
    data = data or rig()
    poses, wrists, axes, hip, head_axes, head_center = transforms(state, data)
    duals = {}
    for name, (rotation, translation) in poses.items():
        real = quaternion(rotation)
        duals[name] = (real, tuple(x*.5 for x in qmultiply((0, *translation), real)))
    positions = []
    for point, weights in zip(data["vertices"], data["weights"]):
        rotation, translation = poses[next(iter(weights))]
        # Facial bones share one rigid head transform. Applying it directly
        # avoids repeatedly blending identical quaternions at dense vertices.
        if all(poses[name][0] is rotation for name in weights):
            if not all(poses[name][1] is translation for name in weights):
                total = sum(weights.values())
                translation = tuple(sum(poses[name][1][axis]*weight for name,weight in weights.items())/total
                                    for axis in range(3))
            positions.append(transform(point, rotation, translation))
        else:
            positions.append(dual_skin(point, weights, duals))
    normals = [(0, 0, 0) for _ in positions]
    for a, b, c in data["geometric"]:
        face = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
        for index in (a, b, c):
            normals[index] = add(normals[index], face)
    normals = [unit(n) if dot(n, n) > 1e-16 else (0, 0, 1) for n in normals]
    return positions, normals, wrists, axes, hip, head_axes, head_center


def plan_creases(states, data=None):
    """Find quantized shading conflicts and reserve only those split corners."""
    player.harness()
    from md3harness.format import normal_bytes, decode_normal
    import math
    data, faces = data or rig(), set()
    for state in states:
        key = tuple(sorted(state.items()))
        if key in data["checked_poses"]:
            continue
        data["checked_poses"].add(key)
        positions, normals, *_ = raw_pose(state, data)
        positions = [tuple(round(x*64)/64 for x in p) for p in player.Vectors(positions)]
        normals = [decode_normal(*normal_bytes(n)) for n in player.Vectors(normals)]
        for index, (a, b, c) in enumerate(data["geometric"]):
            face = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
            if dot(face, face) < 1e-18:
                raise ValueError(f"anatomical face {index} collapses in this quantized pose")
            average = add(add(normals[a], normals[b]), normals[c])
            if dot(face, average) < -.025*math.sqrt(dot(face, face)*dot(average, average)):
                faces.add(index)
    apply_creases(data, faces)
    return len(data["flat_faces"])


def preflight():
    """Rebuild the fixed crease layout from the complete authored library."""
    rig.cache_clear()
    data = rig(use_plan=False)
    for clip in player.CLIPS:
        for frame in range(clip.count):
            state = clip.sample(frame/(clip.count if clip.loop else clip.count-1))
            try:
                plan_creases([state], data)
            except ValueError as error:
                raise ValueError(f"{clip.name} frame {frame}: {error}") from error
        print(f"Athlete preflight: {clip.name}; {len(data['flat_faces'])} crease faces", flush=True)
    source = Path(data["source_path"])
    saved = dict(schema="beachvolley.crease-plan.v1", topology_revision=2,
                 source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                 frames=player.FRAME_COUNT, unique_poses=len(data["checked_poses"]),
                 faces=sorted(data["flat_faces"]))
    source.with_name("crease-plan.json").write_text(json.dumps(saved, indent=2)+"\n")
    rig.cache_clear()
    return saved


def athlete(state):
    data = rig()
    positions, normals, wrists, axes, hip, head_axes, head_center = raw_pose(state, data)
    mesh = player.Mesh()
    corner_positions = [positions[c[0]] for c in data["corners"]]
    corner_normals = [normals[c[0]] for c in data["corners"]]
    for index in data["flat_faces"]:
        triangle = data["triangles"][index]
        a, b, c = [tuple(round(x*64)/64 for x in p) for p in player.Vectors([corner_positions[i] for i in triangle])]
        face = unit(cross(sub(b, a), sub(c, a)))
        for corner in triangle:
            if dot(corner_normals[corner], face) < .3:
                corner_normals[corner] = face
    mesh.append("anatomical_body", "skin", corner_positions, corner_normals,
                [c[1:] for c in data["corners"]], data["triangles"], oriented=True)
    hp = lambda p: transform(p, head_axes, head_center)
    mesh.ellipsoid("cap", "navy", hp((.15, 0, 2.2)), (2.65, 2.70, 1.5), head_axes, sides=64, rings=20)
    mesh.ellipsoid("brim", "navy", hp((2.6, 0, 2.55)), (2.7, 2.9, .16), head_axes, sides=64, rings=8)
    # Full shield follows the anatomical face rather than a spherical head.
    positions, normals, coords, faces = [], [], [], []
    columns, rows = 64, 12
    import math
    for row in range(rows+1):
        v = row/rows
        for column in range(columns+1):
            u = column/columns
            angle = (u-.5)*2.6
            nose = math.exp(-((u-.5)/.13)**2)
            positions.append(hp((3.7*math.cos(angle)+1.0, 2.95*math.sin(angle), .3-v*(2.4+.45*nose))))
            normals.append(unit(transform((math.cos(angle), math.sin(angle), .08), head_axes, (0, 0, 0))))
            coords.append(player.uv("lens", u, v))
    for row in range(rows):
        for column in range(columns):
            a, b = row*(columns+1)+column, (row+1)*(columns+1)+column
            faces.extend(((a, b, a+1), (a+1, b, b+1)))
    mesh.append("shield", "lens", positions, normals, coords, faces)
    for side in (-1, 1):
        mesh.bone("temples", "white", hp((2.0, side*2.8, -.5)), hp((-1.9, side*2.6, -.6)), .18, sides=12)
    return mesh, wrists


def textures(game):
    from md3harness.materials import write_tga
    progs = Path(game)/"progs"
    progs.mkdir(parents=True, exist_ok=True)
    source = Path(rig()["source_path"]).parent
    for name in ("bv_athlete.tga", "bv_athlete_away.tga"):
        shutil.copyfile(source/name, progs/name)
    write_tga(progs/"bv_kit.tga", player.ATLAS, player.ATLAS, player.skin())


CONTRACT = dict(frames=player.FRAME_COUNT, triangle_budget=60000,
                dimensions=[18.34375, 27.375, 61.890625], dimension_tolerance=.05)
BATCH_FRAMES = 40


def export_batch(game, index):
    cli = player.harness()
    textures(game)
    start, end = index*BATCH_FRAMES, min(player.FRAME_COUNT, (index+1)*BATCH_FRAMES)
    if start >= end:
        raise ValueError("invalid athlete batch")
    full = player.scene(frame_range=range(start, end))
    path = Path(game)/"progs"/f"athlete-batch-{index}.md3"
    report = cli.export_scene(full, path, game, dict(triangle_budget=60000), strict=True)
    print(f"Athlete batch {index}: strict PASS ({start}..{end-1})", flush=True)
    return report


def assemble(game, reports=None):
    cli = player.harness()
    from md3harness.packed import combine_batches
    from md3harness.format import HEADER, SURFACE, string
    from md3harness.quality import inspect
    progs = Path(game)/"progs"
    path = progs/"bv_athlete.md3"
    temporary = progs/"bv_athlete.candidate.md3"
    temporary.write_bytes(combine_batches([p.read_bytes() for p in
        [progs/f"athlete-batch-{i}.md3" for i in range((player.FRAME_COUNT+BATCH_FRAMES-1)//BATCH_FRAMES)]]))
    report = inspect(temporary, game, CONTRACT)
    if not report["passed"] or report["issues"]:
        raise ValueError(f"assembled athlete rejected: {report['issues']}")
    temporary.replace(path)
    data = bytearray(path.read_bytes())
    data[8:72] = string("bv_athlete_away.md3")
    offset = HEADER.unpack_from(data)[10]
    for _ in range(HEADER.unpack_from(data)[6]):
        surface = SURFACE.unpack_from(data, offset)
        for index in range(surface[4]):
            shader = offset+surface[8]+index*68
            if bytes(data[shader:shader+64]).split(b"\0")[0] == b"progs/bv_athlete":
                data[shader:shader+64] = string("progs/bv_athlete_away")
        offset += surface[11]
    away = progs/"bv_athlete_away.md3"
    away.write_bytes(data)
    del data
    away_report = inspect(away, game, CONTRACT)
    if not away_report["passed"] or away_report["issues"]:
        raise ValueError(f"away athlete rejected: {away_report['issues']}")
    report["model"] = path.name
    cli.save_json(progs/"bv_athlete.animations.json", player.animation_manifest())
    if reports:
        cli.save_json(Path(reports)/"athlete.report.json", report)
        cli.save_json(Path(reports)/"athlete-away.report.json", away_report)
        cli.save_json(Path(reports)/"athlete.contract.json", CONTRACT)
    print("Both anatomical kits: strict PASS (389 poses)", flush=True)
    return report


def generate_players(game, reports=None):
    game = Path(game)
    player.harness()
    textures(game)
    with tempfile.TemporaryDirectory(prefix="athlete-batches-", dir=game) as directory:
        for index in range((player.FRAME_COUNT+BATCH_FRAMES-1)//BATCH_FRAMES):
            export_batch(directory, index)
        report = assemble(directory, reports)
        for name in ("bv_athlete.md3", "bv_athlete_away.md3", "bv_athlete.animations.json"):
            shutil.copyfile(Path(directory)/"progs"/name, game/"progs"/name)
    return report


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=player.HERE/"build/high-detail-candidate")
    parser.add_argument("--reports", type=Path, default=player.HERE/"build/high-detail-quality")
    parser.add_argument("--batch", type=int)
    parser.add_argument("--assemble", action="store_true")
    parser.add_argument("--plan-creases", action="store_true")
    args = parser.parse_args()
    if args.plan_creases:
        preflight()
    elif args.batch is not None:
        export_batch(args.output, args.batch)
    elif args.assemble:
        assemble(args.output, args.reports)
    else:
        generate_players(args.output, args.reports)
