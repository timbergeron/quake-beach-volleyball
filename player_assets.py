#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2026 timbergeron
"""Original Norwegian-inspired beach athletes, sampled through md3harness.

X faces the net, Y is the athlete's left, Z is up. Origin is the existing
Quake player origin: bare soles at -24. No animation translates the entity.
Two-bone IK preserves limb lengths; sampled vertex poses need no engine rig.
"""
import argparse
from array import array
from dataclasses import dataclass, field
import importlib
import json
import math
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
FPS = 24
ATLAS = 512


def harness():
    try:
        return importlib.import_module("md3harness.cli")
    except ModuleNotFoundError:
        sibling = HERE.parent / "md3harness"
        if not (sibling / "md3harness/cli.py").is_file():
            raise RuntimeError("Install md3harness or clone it beside this repository") from None
        sys.path.insert(0, str(sibling))
        return importlib.import_module("md3harness.cli")


def add(a, b):
    return (a[0]+b[0], a[1]+b[1], a[2]+b[2])


def sub(a, b):
    return (a[0]-b[0], a[1]-b[1], a[2]-b[2])


def mul(a, b):
    return (a[0]*b, a[1]*b, a[2]*b)


def dot(a, b):
    return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(a):
    return mul(a, 1 / max(math.sqrt(dot(a, a)), 1e-9))


def mix(a, b, t):
    if isinstance(a, (tuple, list)):
        return tuple(mix(x, y, t) for x, y in zip(a, b))
    return a + (b - a) * t


def smooth(t):
    t = max(0, min(1, t))
    return t*t*(3-2*t)


def rotate(p, angles):
    # Local pitch, roll, then axial rotation. Degrees are convenient to author.
    pitch, roll, yaw = (math.radians(a) for a in angles)
    x, y, z = p
    x, z = x*math.cos(pitch)+z*math.sin(pitch), -x*math.sin(pitch)+z*math.cos(pitch)
    y, z = y*math.cos(roll)-z*math.sin(roll), y*math.sin(roll)+z*math.cos(roll)
    return (x*math.cos(yaw)-y*math.sin(yaw), x*math.sin(yaw)+y*math.cos(yaw), z)


def basis(axis, guide=(0, 1, 0)):
    z = unit(axis)
    x = sub(guide, mul(z, dot(guide, z)))
    if dot(x, x) < .001:
        x = sub((1, 0, 0), mul(z, z[0]))
    x = unit(x)
    return x, cross(z, x), z


def transform(p, axes, origin):
    a, b, c = axes
    x, y, z = p
    return (origin[0]+x*a[0]+y*b[0]+z*c[0],
            origin[1]+x*a[1]+y*b[1]+z*c[1],
            origin[2]+x*a[2]+y*b[2]+z*c[2])


def ik(start, target, lengths, pole):
    delta = sub(target, start)
    distance = math.sqrt(dot(delta, delta))
    direction = unit(delta)
    a, b = lengths
    distance = max(abs(a-b)+.03, min(a+b-.03, distance))
    end = add(start, mul(direction, distance))
    along = (a*a-b*b+distance*distance)/(2*distance)
    height = math.sqrt(max(0, a*a-along*along))
    bend = unit(sub(pole, mul(direction, dot(pole, direction))))
    joint = add(start, add(mul(direction, along), mul(bend, height)))
    return joint, end


# Broad, isolated material islands. All small parts use interior UV footprints.
REGIONS = {
    "skin": (0, 0, 256, 256), "kit": (256, 0, 512, 256),
    "shorts": (0, 256, 256, 384), "hair": (256, 256, 384, 384),
    "lens": (384, 256, 512, 384), "white": (0, 384, 128, 512),
    "red": (128, 384, 256, 512), "navy": (256, 384, 384, 512),
    "lip": (384, 384, 512, 512),
}


def uv(material, u, v):
    x0, y0, x1, y1 = REGIONS[material]
    margin = 16
    return ((x0+margin+u*(x1-x0-2*margin))/ATLAS,
            (y0+margin+v*(y1-y0-2*margin))/ATLAS)


@dataclass
class Part:
    name: str
    material: str
    positions: list = field(default_factory=list)
    normals: list = field(default_factory=list)
    uv: list = field(default_factory=list)
    triangles: list = field(default_factory=list)


class Mesh:
    def __init__(self):
        self.parts = {}

    def append(self, name, material, positions, normals, coords, faces, oriented=False):
        part = self.parts.setdefault(name, Part(name, material))
        offset = len(part.positions)
        part.positions.extend(positions)
        part.normals.extend(normals)
        part.uv.extend(coords)
        for a, b, c in faces:
            face = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
            normal = add(add(normals[a], normals[b]), normals[c])
            if not oriented and dot(face, normal) < 0:
                b, c = c, b
            part.triangles.append((offset+a, offset+b, offset+c))

    def ellipsoid(self, name, material, origin, radii, axes=None, sides=12, rings=8):
        axes = axes or ((1, 0, 0), (0, 1, 0), (0, 0, 1))
        positions, normals, coords, faces = [], [], [], []
        for i in range(1, rings):
            lat = math.pi*i/rings
            for j in range(sides+1):
                lon = math.tau*j/sides
                n = (math.sin(lat)*math.cos(lon), math.sin(lat)*math.sin(lon), math.cos(lat))
                positions.append(transform(tuple(n[k]*radii[k] for k in range(3)), axes, origin))
                normals.append(unit(transform(tuple(n[k]/radii[k] for k in range(3)), axes, (0, 0, 0))))
                coords.append(uv(material, j/sides, i/rings))
        for i in range(rings-2):
            for j in range(sides):
                a, b = i*(sides+1)+j, (i+1)*(sides+1)+j
                faces.extend(((a, b, a+1), (a+1, b, b+1)))
        for end in (0, 1):
            tip = len(positions)
            positions.append(transform((0, 0, radii[2]*(1 if end == 0 else -1)), axes, origin))
            normals.append(transform((0, 0, 1 if end == 0 else -1), axes, (0, 0, 0)))
            coords.append(uv(material, .5, end))
            row = 0 if end == 0 else (rings-2)*(sides+1)
            faces.extend((tip, row+j, row+j+1) for j in range(sides))
        self.append(name, material, positions, normals, coords, faces)

    def loft(self, name, material, profiles, axes, origin, sides=16):
        """Elliptical sections with analytic slope normals and hard end caps."""
        positions, normals, coords, faces = [], [], [], []
        for i, (z, rx, ry) in enumerate(profiles):
            before, after = profiles[max(0, i-1)], profiles[min(len(profiles)-1, i+1)]
            dz = max(.001, after[0]-before[0])
            dx, dy = (after[1]-before[1])/dz, (after[2]-before[2])/dz
            for j in range(sides+1):
                angle = math.tau*j/sides
                c, s = math.cos(angle), math.sin(angle)
                positions.append(transform((rx*c, ry*s, z), axes, origin))
                normals.append(unit(transform((c/rx, s/ry, -dx*c*c/rx-dy*s*s/ry), axes, (0, 0, 0))))
                coords.append(uv(material, j/sides, i/(len(profiles)-1)))
        for i in range(len(profiles)-1):
            for j in range(sides):
                a, b = i*(sides+1)+j, (i+1)*(sides+1)+j
                faces.extend(((a, a+1, b), (a+1, b+1, b)))
        for end in (0, len(profiles)-1):
            z, rx, ry = profiles[end]
            offset = len(positions)
            normal = transform((0, 0, -1 if end == 0 else 1), axes, (0, 0, 0))
            positions.append(transform((0, 0, z), axes, origin))
            normals.append(normal)
            coords.append(uv(material, .5, .5))
            for j in range(sides+1):
                positions.append(positions[end*(sides+1)+j])
                normals.append(normal)
                coords.append(uv(material, .5, .5))
            faces.extend((offset, offset+j+1, offset+j+2) for j in range(sides))
        self.append(name, material, positions, normals, coords, faces)

    def bone(self, name, material, start, end, radius, sides=10):
        length = math.sqrt(dot(sub(end, start), sub(end, start)))
        axes = basis(sub(end, start))
        self.loft(name, material, [(0, radius*.72, radius*.72),
            (length*.23, radius, radius*.92), (length*.58, radius*.88, radius*.82),
            (length, radius*.60, radius*.60)], axes, start, sides)

    def decal(self, material, point, half_width, half_height, world, axes):
        x, y, z = point
        vertices = [world((x, y+dy, z+dz)) for dy, dz in
                    ((-half_width, -half_height), (half_width, -half_height),
                     (half_width, half_height), (-half_width, half_height))]
        self.append("markings_"+material, material, vertices, [axes[0]]*4,
                    [uv(material, .5, .5)]*4, [(0, 1, 2), (0, 2, 3)])

    def limb(self, name, start, joint, end, radii, sides=12):
        """One continuous skin tube through a bent joint, with welded shading.

        The elbow/knee is an intermediate ring, not a separate ball joint.
        Short neighboring rings preserve volume when the limb folds.
        """
        first, second = unit(sub(joint, start)), unit(sub(end, joint))
        guide = unit(cross(first, second))
        compression = max(.20, math.sqrt(max(0, (1+dot(first, second))*.5)))
        stations = [(mix(start, joint, t), first, r) for t, r in
                    ((0, radii[0]), (.3, radii[1]), (.8, radii[2]))]
        stations.append((joint, unit(add(first, second)), radii[2]))
        stations += [(mix(joint, end, t), second, r) for t, r in
                     ((.2, radii[3]), (.5, radii[4]), (1, radii[5]))]
        positions, normals, coords, faces = [], [], [], []
        for i, (centre, tangent, radius) in enumerate(stations):
            # A shared bend-plane axis avoids twisting neighboring rings when
            # one bone crosses the global Y direction during the bow draw.
            axes = basis(tangent, guide)
            # Compress the inside of a deeply folded elbow/knee, preserving
            # width across the bend plane and avoiding an inverted inner wall.
            weight = (0, 0, .7, 1, .7, 0, 0)[i]
            inner_radius = radius * (1-weight*(1-compression))
            for j in range(sides+1):
                angle = math.tau*j/sides
                n = transform((math.cos(angle), math.sin(angle), 0), axes, (0, 0, 0))
                positions.append(transform((math.cos(angle)*radius, math.sin(angle)*inner_radius, 0), axes, centre))
                normals.append(n)
                coords.append(uv("skin", j/sides, i/(len(stations)-1)))
        for i in range(len(stations)-1):
            for j in range(sides):
                a, b = i*(sides+1)+j, (i+1)*(sides+1)+j
                faces.extend(((a, a+1, b), (a+1, b+1, b)))
        # Derive normals from the deformed surface so the sharpest folds also
        # agree with winding after vertex quantization.
        averaged = [(0, 0, 0)]*len(positions)
        for a, b, c in faces:
            n = cross(sub(positions[b], positions[a]), sub(positions[c], positions[a]))
            for vertex in (a, b, c):
                averaged[vertex] = add(averaged[vertex], n)
        for i in range(len(stations)):
            a, b = i*(sides+1), i*(sides+1)+sides
            averaged[a] = averaged[b] = add(averaged[a], averaged[b])
        normals = [unit(n) for n in averaged]
        for i in (0, len(stations)-1):
            centre, tangent, _ = stations[i]
            offset = len(positions)
            n = mul(tangent, -1 if i == 0 else 1)
            positions.append(centre); normals.append(n); coords.append(uv("skin", .5, .5))
            for j in range(sides+1):
                positions.append(positions[i*(sides+1)+j]); normals.append(n); coords.append(uv("skin", .5, .5))
            faces.extend((offset, offset+j+2, offset+j+1) if i == 0 else
                         (offset, offset+j+1, offset+j+2) for j in range(sides))
        # A sharp inner crease can require different normals on neighboring
        # faces. Split corners there instead of allowing a smoothed normal to
        # point through the folded surface. Positions still coincide exactly,
        # and the triangle/corner layout remains fixed in every animation pose.
        corners, shading, texcoords, triangles = [], [], [], []
        for face in faces:
            a, b, c = face
            geometric = unit(cross(sub(positions[b], positions[a]), sub(positions[c], positions[a])))
            offset = len(corners)
            for vertex in face:
                corners.append(positions[vertex])
                shading.append(normals[vertex] if dot(normals[vertex], geometric) > .15 else geometric)
                texcoords.append(coords[vertex])
            triangles.append((offset, offset+1, offset+2))
        self.append(name, "skin", corners, shading, texcoords, triangles, oriented=True)


def ready(**changes):
    state = dict(hip=(0, 0, -.5), torso=(6, 0, 0), head=(-4, 0, 0),
        left=(8, 9, 8), right=(8, -9, 8), lp=(1, 1, -1), rp=(1, -1, -1),
        lf=(2, 5, -22.5), rf=(-2, -5, -22.5), feet=(0, 0),
        hands=(20, -35, 0), fingers=.15)
    state.update(changes)
    return state


def pose(base, **changes):
    result = dict(base)
    result.update(changes)
    return result


READY = ready()
PASS = ready(hip=(0, 0, -3), torso=(13, 0, 0), left=(19, 1.8, 13), right=(19, -1.8, 13),
             lp=(0, 1, -1), rp=(0, -1, -1), hands=(70, 0, 0), fingers=.9)
SET = ready(hip=(0, 0, -2), torso=(-3, 0, 0), left=(7, 4.2, 34), right=(7, -4.2, 34),
            lp=(0, 1, 0), rp=(0, -1, 0), hands=(-60, 0, -18), fingers=.50)
SET_RELEASE = pose(SET, hip=(0, 0, 1), left=(11, 4.8, 43), right=(11, -4.8, 43), hands=(-30, 0, -12), fingers=.08)
BACKSWING = ready(hip=(-1, 0, -6), torso=(23, 0, 0), left=(-14, 9, 7), right=(-14, -9, 7),
                 lf=(5, 5, -22.5), rf=(-5, -5, -22.5), hands=(20, 0, 0))
TAKEOFF = ready(hip=(0, 0, 0), torso=(-6, 0, -10), left=(3, 8, 42), right=(-3, -9, 43),
               lp=(1, 1, 0), rp=(-1, -1, 0), lf=(-4, 4, -21), rf=(-6, -4, -20),
               hands=(0, 0, 0), fingers=.12)
BOW = pose(TAKEOFF, torso=(-12, 0, -24), left=(11, 7, 42), right=(-6, -7, 37),
           lp=(1, 1, 0), rp=(-1, -2, 0), lf=(-7, 4, -18), rf=(-10, -4, -16))
STRIKE = pose(BOW, torso=(5, 0, 8), left=(9, 10, 24), right=(13, -3, 48),
              hands=(-15, 0, 0), rp=(-1, -1, 0), lf=(2, 4, -21), rf=(-4, -4, -20), fingers=.04)
FOLLOW = pose(STRIKE, torso=(18, 0, 25), left=(9, 8, 18), right=(15, 6, 18),
              hands=(25, 0, 0), lf=(4, 5, -22), rf=(-2, -5, -22), fingers=.2)
LAND = ready(hip=(0, 0, -6), torso=(17, 0, 0), left=(8, 9, 13), right=(8, -9, 13))
BLOCK = ready(hip=(0, 0, 0), torso=(7, 0, 0), left=(10, 8, 46), right=(10, -8, 46),
              lp=(1, 1, 0), rp=(1, -1, 0), hands=(-80, 0, 0), fingers=0,
              lf=(8, 5, -20), rf=(8, -5, -20))
PIKE = pose(BLOCK, hip=(-2, 0, 0), torso=(16, 0, 0), left=(16, 8, 45), right=(16, -8, 45),
            lf=(17, 5, -14), rf=(17, -5, -14), feet=(-20, -20))
PRONE = ready(hip=(-1, 0, -12), torso=(76, 0, 0), head=(-43, 0, 0),
              left=(31, 2.8, -15), right=(31, -2.8, -15),
              lp=(0, 1, 0), rp=(0, -1, 0), lf=(-18, 5, -15), rf=(-18, -5, -15),
              hands=(95, 0, 0), fingers=.9)
FLOAT = ready(torso=(-9, 0, -17), left=(13, 6, 38), right=(-6, -6, 38),
              lp=(1, 1, 0), rp=(-1, -2, 0), hands=(0, 0, 0), fingers=.05)


@dataclass
class Clip:
    name: str
    seconds: float
    keys: list
    loop: bool = False
    contact: float | None = None
    note: str = ""
    start: int = 0

    @property
    def count(self):
        return max(2, round(self.seconds*FPS) + (0 if self.loop else 1))

    def sample(self, t):
        t = max(0, min(1, t))
        for (ta, a), (tb, b) in zip(self.keys, self.keys[1:]):
            if t <= tb:
                return {k: mix(a[k], b[k], smooth((t-ta)/(tb-ta))) for k in a}
        return self.keys[-1][1]


def clips():
    result = [Clip("ready", 1.2, [(0, READY), (.5, pose(READY, hip=(0, 0, -.2))), (1, READY)], True)]
    for name, lateral, backward in (("run", 0, False), ("shuffle_l", 1, False),
                                     ("shuffle_r", -1, False), ("backpedal", 0, True)):
        keys = []
        for i in range(5):
            t = i/4
            step = math.cos(t*math.tau)*6
            lift_l, lift_r = max(0, math.sin(t*math.tau))*3, max(0, -math.sin(t*math.tau))*3
            x = -1 if backward else 1
            state = ready(hip=(0, 0, -1.5+abs(math.sin(t*math.tau))*.6), torso=(13 if not backward else -4, 0, 0),
                lf=(x*step if not lateral else 0, 5+lateral*step, -22.5+lift_l),
                rf=(-x*step if not lateral else 0, -5-lateral*step, -22.5+lift_r),
                left=(-step, 9, 9), right=(step, -9, 9))
            keys.append((t, state))
        result.append(Clip(name, .64, keys, True, note="In-place; pace follows horizontal travel."))
    result += [
        Clip("split_step", .36, [(0, READY), (.4, pose(READY, hip=(0, 0, 1), lf=(0, 7, -21), rf=(0, -7, -21))), (.7, LAND), (1, READY)]),
        Clip("pass_load", .25, [(0, READY), (1, PASS)], note="Join thumbs; rotate straight forearms into a level platform."),
        Clip("pass", .24, [(0, PASS), (.35, pose(PASS, hip=(0, 0, -1), left=(21, 1.8, 18), right=(21, -1.8, 18))), (1, READY)], contact=0),
        Clip("set_load", .32, [(0, READY), (.55, pose(SET, hip=(0, 0, -4))), (1, SET)], note="Deep dish under the forehead; palms cup inward, thumbs behind the ball."),
        Clip("set", .28, [(0, SET), (.32, SET_RELEASE), (.65, SET_RELEASE), (1, READY)], contact=0,
             note="Coordinated ankle/knee/hip extension, then elbows/wrists; no held ball."),
        Clip("back_set", .42, [(0, SET), (.3, pose(SET_RELEASE, torso=(-19, 0, 0), left=(-3, 4.8, 44), right=(-3, -4.8, 44))), (.55, pose(SET_RELEASE, torso=(-12, 0, 0))), (1, READY)], contact=0),
        Clip("jump_set", .46, [(0, SET), (.35, pose(SET_RELEASE, lf=(-3, 4, -19), rf=(-3, -4, -19))), (.65, SET_RELEASE), (1, LAND)], contact=.2),
        Clip("approach", .55, [(0, READY), (.35, pose(BACKSWING, rf=(7, -5, -22.5), lf=(-6, 5, -20))), (.7, BACKSWING), (1, TAKEOFF)],
             note="Right-left closing steps: BOTH arms sweep behind hips before driving upward."),
        Clip("takeoff", .26, [(0, BACKSWING), (.7, TAKEOFF), (1, BOW)]),
        Clip("attack_load", .27, [(0, TAKEOFF), (1, BOW)], note="Guide arm tracks the ball; hitting elbow draws back independently."),
        Clip("spike", .5, [(0, STRIKE), (.2, FOLLOW), (.55, FOLLOW), (.8, LAND), (1, READY)], contact=0,
             note="Trunk rotation, elbow extension, wrist snap; hitting arm follows across the body."),
        Clip("roll", .36, [(0, pose(STRIKE, right=(12, -3, 45), fingers=.28)), (.35, pose(FOLLOW, right=(18, -2, 33), torso=(4, 0, 5))), (1, READY)], contact=0),
        Clip("cut", .5, [(0, pose(STRIKE, torso=(7, -8, 19), right=(15, 6, 45))), (.3, pose(FOLLOW, right=(16, 11, 22))), (.7, LAND), (1, READY)], contact=0),
        Clip("poke", .34, [(0, pose(STRIKE, fingers=.95)), (.35, pose(STRIKE, right=(18, -2, 41), fingers=.95)), (1, READY)], contact=0,
             note="Closed knuckles for a beach pokey; no open-finger tip."),
        Clip("float_load", .40, [(0, READY), (.3, pose(FLOAT, left=(15, 5, 31))), (1, FLOAT)]),
        Clip("float_serve", .45, [(0, pose(STRIKE, torso=(2, 0, 0), lf=(4, 5, -22.5), rf=(-4, -5, -22.5))), (.23, pose(FOLLOW, torso=(9, 0, 9))), (1, READY)], contact=0),
        Clip("jump_serve", .75, [(0, READY), (.2, FLOAT), (.43, BACKSWING), (.6, TAKEOFF), (.8, BOW), (1, STRIKE)], contact=1),
        Clip("block_load", .28, [(0, READY), (.6, pose(LAND, left=(4, 8, 29), right=(4, -8, 29))), (1, BLOCK)]),
        Clip("block_pike", .62, [(0, LAND), (.23, BLOCK), (.47, PIKE), (.65, PIKE), (.82, BLOCK), (1, LAND)], contact=.47,
             note="Hips close into a pike; feet forward, shoulders and spread palms penetrate over the tape."),
        Clip("block_l", .62, [(0, LAND), (.23, BLOCK), (.47, pose(PIKE, torso=(16, -10, 0), left=(15, 13, 44), right=(15, -3, 44))), (.75, BLOCK), (1, LAND)], contact=.47),
        Clip("block_r", .62, [(0, LAND), (.23, BLOCK), (.47, pose(PIKE, torso=(16, 10, 0), left=(15, 3, 44), right=(15, -13, 44))), (.75, BLOCK), (1, LAND)], contact=.47),
        Clip("peel", .55, [(0, pose(READY, left=(3, 8, 29), right=(3, -8, 29))), (.45, ready(torso=(12, 0, 30), lf=(-8, 6, -22.5), rf=(6, -6, -21))), (1, PASS)], note="Drop off the net into a defensive platform."),
        Clip("dive", .48, [(0, PASS), (.28, pose(PRONE, hip=(-1, 0, -8), torso=(50, 0, 0))), (.65, PRONE), (1, PRONE)]),
        Clip("pancake", .48, [(0, PASS), (.45, PRONE), (.7, pose(PRONE, left=(32, 6, -21), right=(27, -8, -16), hands=(90, 0, 0), fingers=0)), (1, PRONE)], contact=.7),
        Clip("getup", .67, [(0, PRONE), (.32, pose(PRONE, torso=(46, 0, 0), left=(12, 8, -15), right=(12, -8, -15))), (.68, LAND), (1, READY)]),
        Clip("land", .3, [(0, TAKEOFF), (.45, LAND), (1, READY)]),
    ]
    start = 0
    for clip in result:
        clip.start = start
        start += clip.count
    return result


CLIPS = clips()
FRAME_COUNT = sum(c.count for c in CLIPS)


def hand(mesh, wrist, forearm, side, state, view=False):
    # Palm longitudinal axis; opposing rotations form a bowl for setting.
    pitch, roll, yaw = state["hands"]
    angles = (pitch, side*roll, side*yaw)
    axes = tuple(rotate(a, angles) for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1)))
    palm = transform((1.25, 0, 0), axes, wrist)
    mesh.ellipsoid("hands", "skin", palm, (1.8, 1.45, .62), axes, sides=10, rings=6)
    curl = state["fingers"]
    for finger in range(4):
        length = (2.35, 2.8, 2.55, 2.05)[finger]
        lateral = (finger-1.5)*.74
        spread = .15 + (.28 if curl < .3 else 0)
        start = transform((2.5, lateral, .1), axes, wrist)
        middle = transform((2.5+length*.52, lateral*(1+spread), -.25*curl), axes, wrist)
        end = transform((2.5+length*(1-.48*curl), lateral*(1+spread), -.95*curl), axes, wrist)
        mesh.bone("fingers", "skin", start, middle, .37, sides=6)
        mesh.bone("fingers", "skin", middle, end, .32, sides=6)
    thumb_start = transform((.5, -side*1.25, 0), axes, wrist)
    thumb_middle = transform((1.55, -side*2.0, -.16), axes, wrist)
    thumb_end = transform((2.5, -side*(1.4 if curl > .7 else 2.15), -.30), axes, wrist)
    mesh.bone("fingers", "skin", thumb_start, thumb_middle, .46, sides=6)
    mesh.bone("fingers", "skin", thumb_middle, thumb_end, .36, sides=6)


def athlete(state, view=False):
    mesh = Mesh()
    torso = state["torso"]
    # Tall athlete proportions: hips about a metre above the sand, with
    # 48 cm thighs / 46 cm lower legs. Prone poses keep their low hip origin.
    hip = add(state["hip"], (0, 0, 8*(1-smooth((torso[0]-40)/25))))
    axes = tuple(rotate(a, torso) for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1)))
    world = lambda p: transform(p, axes, hip)
    wrists = []
    for side, key in ((1, "left"), (-1, "right")):
        shoulder = world((0, side*7.0, 20.5))
        elbow, wrist = ik(shoulder, state[key], (10.6, 10.2), state["lp" if side == 1 else "rp"])
        if view:
            # A dedicated camera-space rig keeps the forearms readable. X is
            # forward; neutral wrists below the reticle, overhead strokes rise.
            eye_height = mix(28, 5, smooth((torso[0]-35)/35))
            shift = (14, 0, -eye_height)
            shoulder, elbow, wrist = (add(p, shift) for p in (shoulder, elbow, wrist))
            # The world shoulders sit beside the eye. In camera space their
            # round ends would fill the reticle. Bring upper arms in from
            # behind/below the camera while retaining the stroke's wrists.
            shoulder = (-8, side*14, -16)
        else:
            mesh.ellipsoid("shoulders", "skin", shoulder, (2.4, 2.5, 2.5), axes, sides=10, rings=6)
        mesh.limb("arms", shoulder, elbow, wrist, (2.1, 2.3, 1.55, 1.85, 1.65, 1.0))
        hand(mesh, wrist, sub(wrist, elbow), side, state, view)
        wrists.append(wrist)
    if view:
        return mesh, wrists
    mesh.loft("jersey", "kit", [(-2, 3.3, 4.6), (2, 3.4, 5.0), (7, 3.1, 5.0),
        (12, 3.6, 6.2), (17, 4.0, 7.1), (21, 3.1, 6.4), (22, 1.9, 2.2)], axes, hip, sides=20)
    mesh.loft("waist", "shorts", [(-3.5, 3.6, 5.2), (0, 3.5, 5.1), (1, 3.4, 5)], axes, hip)
    for side in (-1, 1):
        mesh.bone("straps", "kit", world((0, side*2.2, 21.0)), world((0, side*6.8, 20.5)), 1.6)
    for side, key in ((1, "lf"), (-1, "rf")):
        root = add(hip, (0, side*3.5, -2))
        knee, ankle = ik(root, state[key], (15.4, 14.6), (1, 0, 0))
        legaxis = basis(sub(knee, root))
        mesh.limb("legs", root, knee, ankle, (2.7, 3.0, 1.85, 2.1, 2.2, 1.15))
        mesh.loft("short_legs", "shorts", [(0, 3.0, 3.1), (4, 3.25, 3.15), (9, 2.9, 2.9)], legaxis, root, sides=12)
        footaxes = tuple(rotate(a, (state["feet"][0 if side == 1 else 1], 0, -side*8))
                         for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1)))
        mesh.ellipsoid("feet", "skin", add(ankle, (1.2, 0, -.2)), (3.5, 1.55, 1.15), footaxes, sides=12, rings=6)
        # Toes are broad enough to survive the MD3 grid.
        for toe in range(5):
            centre = transform((3.6, (toe-2)*.50, -.35), footaxes, ankle)
            mesh.ellipsoid("toes", "skin", centre, (.68 if toe == 0 else .5, .30, .42), footaxes, sides=6, rings=4)
    mesh.bone("neck", "skin", world((0, 0, 21.5)), world((0, 0, 25.5)), 1.85)
    head_origin = world((0, 0, 26))
    headangles = tuple(a+b for a, b in zip(torso, state["head"]))
    headaxes = tuple(rotate(a, headangles) for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1)))
    hp = lambda p: transform(p, headaxes, head_origin)
    mesh.ellipsoid("head", "skin", head_origin, (3.5, 3.1, 4.7), headaxes, sides=16, rings=10)
    mesh.ellipsoid("jaw", "skin", hp((.7, 0, -2.5)), (2.7, 2.55, 2.0), headaxes, sides=12, rings=6)
    mesh.ellipsoid("nose", "skin", hp((3.35, 0, -.2)), (1.05, .65, 1.35), headaxes, sides=10, rings=6)
    mesh.ellipsoid("mouth", "lip", hp((3.32, 0, -2.35)), (.22, 1.05, .22), headaxes, sides=8, rings=4)
    for side in (-1, 1):
        mesh.ellipsoid("ears", "skin", hp((-.1, side*3.0, -.4)), (.75, .5, 1.1), headaxes, sides=8, rings=6)
    mesh.ellipsoid("hair", "hair", hp((-.25, 0, 2.3)), (3.6, 3.15, 2.65), headaxes, sides=16, rings=8)
    # Close fitting navy sun cap and curved forward brim, original unbranded kit.
    mesh.ellipsoid("cap", "navy", hp((-.25, 0, 3.2)), (3.72, 3.26, 2.0), headaxes, sides=16, rings=6)
    mesh.ellipsoid("brim", "navy", hp((3.3, 0, 3.25)), (3.5, 3.3, .21), headaxes, sides=16, rings=4)
    glasses(mesh, hp, headaxes)
    # Norwegian flag and large NOR/number lettering in mesh-native graphics.
    # The broad front panel follows the rotating torso rather than floating.
    flag(mesh, world, axes)
    lettering(mesh, "NOR", (4.12, -2.8, 14.6), .65, world, axes)
    lettering(mesh, "1", (3.92, -.6, 8.3), 1.1, world, axes)
    return mesh, wrists


def glasses(mesh, hp, axes):
    positions, normals, coords, faces = [], [], [], []
    # Full shield: one cylindrical lens with a low, sculpted nose section.
    for row in range(5):
        v = row/4
        for col in range(17):
            u = col/16
            angle = (u-.5)*2.5
            nose = math.exp(-((u-.5)/.14)**2)
            z = 2.0-v*(3.0+.65*nose)
            local = (4.15*math.cos(angle)+.2, 3.6*math.sin(angle), z)
            positions.append(hp(local))
            normals.append(unit(transform((math.cos(angle), math.sin(angle), .10), axes, (0, 0, 0))))
            coords.append(uv("lens", u, v))
    for row in range(4):
        for col in range(16):
            a, b = row*17+col, (row+1)*17+col
            faces.extend(((a, b, a+1), (a+1, b, b+1)))
    mesh.append("shield", "lens", positions, normals, coords, faces)
    for side in (-1, 1):
        mesh.bone("temples", "white", hp((1.65, side*3.43, 1.5)), hp((-2.2, side*3.12, .8)), .27, sides=6)


def glyph(mesh, origin, pattern, size, material, world, axes):
    for row, line in enumerate(pattern):
        for col, bit in enumerate(line):
            if bit == "1":
                x, y, z = origin
                mesh.decal(material, (x, y+col*size, z-row*size), size*.49, size*.49, world, axes)


def lettering(mesh, text, origin, size, world, axes):
    font = {"N": ("1001", "1101", "1011", "1001", "1001"),
            "O": ("0110", "1001", "1001", "1001", "0110"),
            "R": ("1110", "1001", "1110", "1010", "1001"),
            "1": ("010", "110", "010", "010", "111")}
    for i, character in enumerate(text):
        point = add(origin, (0, i*5*size, 0))
        glyph(mesh, point, font[character], size, "white", world, axes)


def flag(mesh, world, axes):
    for row in range(6):
        for col in range(9):
            material = "red"
            if row in (2, 3) or col in (2, 3):
                material = "white"
            if row == 3 or col == 3:
                material = "navy"
            mesh.decal(material, (4.0, -2.6+col*.55, 20-row*.5), .28, .26, world, axes)


def skin(away=False):
    for y in range(ATLAS):
        for x in range(ATLAS):
            material = next(k for k, (x0, y0, x1, y1) in REGIONS.items() if x0 <= x < x1 and y0 <= y < y1)
            grain = ((x*31+y*17+(x^y)*3) % 13-6)*.3
            if material == "skin":
                shade = 4*math.sin(x*.045)*math.sin(y*.033)
                color = (211+shade, 161+shade, 121+shade)
            elif material == "kit":
                weave = (1 if (x+y) % 4 else -1)
                color = (194+weave, 47+weave, 45+weave) if away else (30+weave, 76+weave, 130+weave)
                # Red shoulders / navy hem complement the Norway colors.
                if y < 36:
                    color = (22, 35, 59) if away else (186, 42, 47)
                elif y > 220:
                    color = (19, 34, 60)
            elif material == "shorts":
                color = (20, 33, 58)
                if y > 360 and (x < 55 or x > 205):
                    color = (191, 42, 46)
                grain += math.sin(x*.17)*1.4
            elif material == "hair":
                strand = math.sin(x*.8+y*.12)*7
                color = (151+strand, 111+strand, 65+strand)
            elif material == "lens":
                u, v = (x-384)/128, (y-256)/128
                glint = math.exp(-((v-(.30+.12*math.sin(u*5)))/.055)**2)
                color = (15+50*glint+15*v, 92+105*glint+35*(1-v), 139+93*glint+37*(1-v))
            else:
                color = {"white": (232, 237, 235), "red": (192, 38, 46),
                         "navy": (19, 30, 47), "lip": (139, 85, 66)}[material]
            yield (*[max(0, min(255, round(c+grain))) for c in color], 255)


class Vectors:
    """Compact source samples; the harness accepts any indexed sequence.

    Keeping millions of Python vector objects alive would make long animation
    exports unnecessarily memory hungry before the harness partitions them.
    """
    def __init__(self, vectors):
        self.data = array("f", (c for v in vectors for c in v))

    def __len__(self):
        return len(self.data)//3

    def __getitem__(self, index):
        if not 0 <= index < len(self):
            raise IndexError(index)
        i = index*3
        return (self.data[i], self.data[i+1], self.data[i+2])


def scene(view=False):
    result = dict(schema="md3harness.scene.v1", name="bv_hands.md3" if view else "bv_athlete.md3",
                  winding="ccw", frames=[], surfaces=[], tags=[])
    parts = None
    for clip in CLIPS:
        for frame in range(clip.count):
            t = frame/(clip.count if clip.loop else clip.count-1)
            mesh, wrists = athlete(clip.sample(t), view)
            if parts is None:
                parts = list(mesh.parts)
                result["surfaces"] = [dict(name=p.name, shader="progs/bv_athlete", uv=p.uv,
                    triangles=p.triangles, poses=[]) for p in mesh.parts.values()]
            if list(mesh.parts) != parts:
                raise ValueError("animation changed surface order")
            for name, surface in zip(parts, result["surfaces"]):
                part = mesh.parts[name]
                if part.triangles != surface["triangles"] or part.uv != surface["uv"]:
                    raise ValueError(f"animation changed topology: {clip.name}/{name}")
                surface["poses"].append(dict(positions=Vectors(part.positions), normals=Vectors(part.normals)))
            result["frames"].append(f"{clip.name[:10]}{frame:03d}")
            result["tags"].append([dict(name=f"tag_{name}", origin=wrist,
                axes=[[1, 0, 0], [0, 1, 0], [0, 0, 1]]) for name, wrist in zip(("left", "right"), wrists)])
    return result


def animation_manifest():
    return dict(schema="beachvolley.animations.v1", fps=FPS, frames=FRAME_COUNT,
        axes="X forward, Y athlete left, Z up; soles -24; entity motion owns translation",
        reference="Anders Mol / Christian Sørum: Norway kit, athletic silhouette, full mirrored sun shield",
        clips=[dict(name=c.name, start=c.start, count=c.count, seconds=c.seconds, loop=c.loop,
                    contact=c.contact, note=c.note) for c in CLIPS])


def qc_constants():
    lines = ["// SPDX-License-Identifier: GPL-2.0-or-later", "// Generated by player_assets.py; do not hand-edit frame ranges.",
             f"float BV_ANIM_FPS = {FPS};", f"float BV_ANIM_FRAMES = {FRAME_COUNT};"]
    for c in CLIPS:
        prefix = "BV_ANIM_"+c.name.upper()
        lines += [f"float {prefix} = {c.start};", f"float {prefix}_COUNT = {c.count};"]
    lines += ["// Extra first-person wrist-away variant; body uses CUT.",
              f"float BV_VIEW_ANIM_CUT_AWAY = {FRAME_COUNT};"]
    return "\n".join(lines)+"\n"


def generate_players(game, reports=None):
    game = Path(game)
    cli = harness()
    from md3harness.materials import write_tga
    progs = game / "progs"
    write_tga(progs / "bv_athlete.tga", ATLAS, ATLAS, skin())
    write_tga(progs / "bv_athlete_away.tga", ATLAS, ATLAS, skin(True))
    # Structural contracts apply to every pose, including the smallest fingers.
    contract = dict(frames=FRAME_COUNT, dimensions=[17.08, 20.84, 62.41],
        dimension_tolerance=.10, triangle_budget=12500,
        atlas_regions=[dict(surface_prefix=name, rect=REGIONS[material], mip_level=3)
            for name, material in (("shield", "lens"), ("fingers", "skin"), ("cap", "navy"), ("short_legs", "shorts"))])
    body = scene()
    print("Exporting and checking body poses...", flush=True)
    report = cli.export_scene(body, progs / "bv_athlete.md3", game, contract, strict=True)
    for surface in body["surfaces"]:
        surface["shader"] = "progs/bv_athlete_away"
    body["name"] = "bv_athlete_away.md3"
    print("Exporting and checking away kit...", flush=True)
    away = cli.export_scene(body, progs / "bv_athlete_away.md3", game, contract, strict=True)
    del body
    print("Building and checking first-person arms...", flush=True)
    hands = generate_hands(game)
    cli.save_json(progs / "bv_athlete.animations.json", animation_manifest())
    if reports:
        for name, data in (("athlete", report), ("athlete-away", away), ("hands", hands)):
            cli.save_json(Path(reports) / f"{name}.report.json", data)
        cli.save_json(Path(reports) / "athlete.contract.json", contract)
    print(f"Athletes: {len(CLIPS)} clips, {FRAME_COUNT} poses at {FPS} Hz; "
          f"{sum(p['triangles'] for p in report['surfaces'])} triangles; strict MD3 checks passed", flush=True)
    return report


def generate_hands(game, reports=None):
    from hand_assets import generate_hands as generate_anatomical_hands
    return generate_anatomical_hands(game, reports)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("dist/beachvolley"), help="Game root (assets go under progs/)")
    parser.add_argument("--reports", type=Path, default=Path("build/player-quality"))
    parser.add_argument("--write-qc", action="store_true", help="Refresh the checked-in animation constants")
    args = parser.parse_args()
    if args.write_qc:
        (HERE / "src/animation_frames.qc").write_text(qc_constants())
    generate_players(args.output, args.reports)


if __name__ == "__main__":
    main()
